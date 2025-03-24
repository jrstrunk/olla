import filepath
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/string
import lib/concurrent_duplicate_dict
import lib/snagx
import lib/sqlightx
import simplifile
import snag
import sqlight

pub type ConnectionActorState(key, submission, val) {
  ConnectionActorState(
    conn: sqlight.Connection,
    insert_query: String,
    record_count: Int,
    build_val: fn(submission, Int) -> val,
    key_encoder: fn(key) -> String,
    val_encoder: fn(val) -> List(Value),
  )
}

pub type ConnectionActorMsg(key, submission, val) {
  PersistData(key, submission, reply: process.Subject(Result(val, snag.Snag)))
  PersistTopic(String, reply: process.Subject(Result(Nil, snag.Snag)))
}

pub fn handle_persist_data(
  msg,
  state: ConnectionActorState(key, submission, val),
) {
  let state = case msg {
    PersistData(key, submission, reply) -> {
      let encoded_key = state.key_encoder(key)

      let new_record_count = state.record_count + 1

      let val = state.build_val(submission, new_record_count)

      let encoded_vals = state.val_encoder(val)

      let res =
        sqlight.query(
          state.insert_query,
          on: state.conn,
          with: [
            sqlight.text(encoded_key),
            ..list.map(encoded_vals, translate_persist_type)
          ],
          expecting: decode.success(Nil),
        )
        |> snag.map_error(string.inspect)
        |> snag.context("Unable to insert data")
        |> result.replace(val)

      process.send(reply, res)

      case res {
        Ok(..) -> ConnectionActorState(..state, record_count: new_record_count)
        Error(..) -> state
      }
    }
    PersistTopic(topic, reply) -> {
      sqlight.exec(
        { "INSERT OR IGNORE INTO topics (topic) VALUES ('" <> topic <> "')" },
        on: state.conn,
      )
      |> snag.map_error(string.inspect)
      |> snag.context("Unable to add topic to topics table")
      |> result.replace(Nil)
      |> process.send(reply, _)

      state
    }
  }

  actor.continue(state)
}

pub opaque type PersistentConcurrentDuplicateDict(key, submission, val) {
  PersistentConcurrentDuplicateDict(
    connection_actor: process.Subject(ConnectionActorMsg(key, submission, val)),
    data: concurrent_duplicate_dict.ConcurrentDuplicateDict(key, val),
    topics: concurrent_duplicate_dict.ConcurrentDuplicateDict(String, Nil),
    subscribers: concurrent_duplicate_dict.ConcurrentDuplicateDict(
      Nil,
      fn() -> Nil,
    ),
  )
}

/// Field schema should be the SQLite column schema for the fields of the
/// values in the dictionary. It cannot have a primary key, as that is handled
/// internally.
/// For example, "key TEXT NOT NULL, name TEXT NOT NULL, age INTEGER NOT NULL, birthday INTEGER".
/// The value decoder should be a decoder that expects indexed fields in the same
/// order as the schema.
pub fn build(
  path path: String,
  key_encoder key_encoder: fn(key) -> String,
  key_decoder key_decoder: fn(String) -> key,
  build_val build_val: fn(submission, Int) -> val,
  example example: val,
  val_encoder val_encoder: fn(val) -> List(Value),
  val_decoder val_decoder: decode.Decoder(val),
) {
  let encoded_example = val_encoder(example)
  let field_schema = build_schema(encoded_example)
  let column_names = build_column_names(encoded_example)
  let column_binds =
    encoded_example
    |> list.length
    |> list.repeat("?", _)
    |> string.join(", ")

  let assert Ok(Nil) = case path == ":memory:" {
    True -> Ok(Nil)
    False ->
      filepath.directory_name(path)
      |> simplifile.create_directory_all
  }

  use conn <- result.try(
    sqlight.open(path)
    |> sqlightx.describe_connection_error(path),
  )

  let table_schema =
    "CREATE TABLE IF NOT EXISTS persist (pcdd_key TEXT NOT NULL, "
    <> field_schema
    <> ")"

  use Nil <- result.try(
    sqlight.exec(table_schema, on: conn)
    |> snag.map_error(string.inspect)
    |> snag.context("Unable to create table schema"),
  )

  let topics_schema =
    "CREATE TABLE IF NOT EXISTS topics (topic TEXT NOT NULL UNIQUE)"

  use Nil <- result.try(
    sqlight.exec(topics_schema, on: conn)
    |> snag.map_error(string.inspect)
    |> snag.context("Unable to create topics schema"),
  )

  // To keep to keep interface abstraction, we have to gather all keys
  // first, then query for each key's data. This avoids the user having to
  // write a decoder that is aware of how this lib works, but also has a one
  // time performance cost.

  use keys <- result.try(
    sqlight.query(
      "SELECT DISTINCT pcdd_key FROM persist",
      with: [],
      on: conn,
      expecting: decode.field(0, decode.string, decode.success),
    )
    |> snag.map_error(string.inspect)
    |> snag.context("Unable to query for unique keys"),
  )

  let select_data_query =
    "SELECT " <> column_names <> " FROM persist WHERE pcdd_key = ?"

  use data_nested <- result.try(
    list.map(keys, fn(key) {
      use key_data <- result.map(
        sqlight.query(
          select_data_query,
          with: [sqlight.text(key)],
          on: conn,
          expecting: val_decoder,
        )
        |> snag.map_error(string.inspect)
        |> snag.context("Unable to query for data per key"),
      )

      #(key_decoder(key), key_data)
    })
    |> snagx.collect_errors,
  )

  let data_flattened =
    list.map(data_nested, fn(record) {
      list.map(record.1, fn(val) { #(record.0, val) })
    })
    |> list.flatten

  let data = concurrent_duplicate_dict.from_list(data_flattened)

  let record_count = list.length(data_flattened)

  let insert_query =
    "INSERT INTO persist (pcdd_key, "
    <> column_names
    <> ") VALUES (?, "
    <> column_binds
    <> ")"

  use topics <- result.try(
    sqlight.query(
      "SELECT DISTINCT topic FROM topics",
      with: [],
      on: conn,
      expecting: decode.field(0, decode.string, decode.success),
    )
    |> snag.map_error(string.inspect)
    |> snag.context("Unable to query for topics"),
  )

  use connection_actor <- result.try(
    ConnectionActorState(
      conn:,
      insert_query:,
      key_encoder:,
      record_count:,
      build_val:,
      val_encoder:,
    )
    |> actor.start(handle_persist_data)
    |> snag.map_error(string.inspect),
  )

  PersistentConcurrentDuplicateDict(
    connection_actor:,
    data:,
    topics: list.map(topics, fn(topic) { #(topic, Nil) })
      |> concurrent_duplicate_dict.from_list,
    subscribers: concurrent_duplicate_dict.new(),
  )
  |> Ok
}

pub fn get(pcd: PersistentConcurrentDuplicateDict(key, submission, val), key) {
  concurrent_duplicate_dict.get(pcd.data, key)
}

pub fn insert(
  pcdd: PersistentConcurrentDuplicateDict(key, submission, val),
  key: key,
  submission: submission,
) {
  // First persist the data in the disk database
  use val <- result.map(
    process.try_call(
      pcdd.connection_actor,
      PersistData(key, submission, _),
      100_000,
    )
    |> snag.map_error(string.inspect)
    |> result.flatten,
  )

  // If that succeeds, then add it to the in-memory store
  concurrent_duplicate_dict.insert(pcdd.data, key, val)

  // After that succeeds, update any subscribers
  concurrent_duplicate_dict.get(pcdd.subscribers, Nil)
  |> list.each(fn(effect) { effect() })
}

pub fn subscribe(
  pcdd: PersistentConcurrentDuplicateDict(key, submission, val),
  subscriber,
) {
  concurrent_duplicate_dict.insert(pcdd.subscribers, Nil, subscriber)
}

pub fn keys(pcd: PersistentConcurrentDuplicateDict(key, submission, val)) {
  concurrent_duplicate_dict.keys(pcd.data)
}

pub fn to_list(pcd: PersistentConcurrentDuplicateDict(key, submission, val)) {
  concurrent_duplicate_dict.to_list(pcd.data)
}

pub fn topics(pcd: PersistentConcurrentDuplicateDict(key, submission, val)) {
  concurrent_duplicate_dict.keys(pcd.topics)
}

pub fn add_topic(
  pcd: PersistentConcurrentDuplicateDict(key, submission, val),
  topic,
) {
  case concurrent_duplicate_dict.get(pcd.topics, topic) {
    [] -> {
      use Nil <- result.map(
        process.try_call(pcd.connection_actor, PersistTopic(topic, _), 10_000)
        |> snag.map_error(string.inspect)
        |> result.flatten,
      )

      concurrent_duplicate_dict.insert(pcd.topics, topic, Nil)
    }
    _ -> Ok(Nil)
  }
}

/// Creates an empty dictionary that will fail to store any data, but can 
/// satisfy type requirements and will always return no data.
pub fn empty() {
  PersistentConcurrentDuplicateDict(
    connection_actor: process.new_subject(),
    data: concurrent_duplicate_dict.new(),
    topics: concurrent_duplicate_dict.new(),
    subscribers: concurrent_duplicate_dict.new(),
  )
}

pub opaque type Value {
  Integer(Int)
  Real(Float)
  Text(String)
  NullableInteger(option.Option(Int))
  NullableReal(option.Option(Float))
  NullableText(option.Option(String))
}

pub fn int(int: Int) {
  Integer(int)
}

pub fn float(float: Float) {
  Real(float)
}

pub fn text(text: String) {
  Text(text)
}

pub fn int_nullable(int: option.Option(Int)) {
  NullableInteger(int)
}

pub fn float_nullable(float: option.Option(Float)) {
  NullableReal(float)
}

pub fn text_nullable(text: option.Option(String)) {
  NullableText(text)
}

fn build_schema(encoded_example: List(Value)) {
  list.index_map(encoded_example, fn(persist_type, index) {
    case persist_type {
      Integer(..) -> "val" <> int.to_string(index) <> " INTEGER NOT NULL"
      Real(..) -> "val" <> int.to_string(index) <> " REAL NOT NULL"
      Text(..) -> "val" <> int.to_string(index) <> " TEXT NOT NULL"
      NullableInteger(..) -> "val" <> int.to_string(index) <> " INTEGER"
      NullableReal(..) -> "val" <> int.to_string(index) <> " REAL"
      NullableText(..) -> "val" <> int.to_string(index) <> " TEXT"
    }
  })
  |> string.join(", ")
}

fn build_column_names(encoded_example: List(Value)) {
  list.index_map(encoded_example, fn(_, index) { "val" <> int.to_string(index) })
  |> string.join(", ")
}

fn translate_persist_type(persist_type: Value) {
  case persist_type {
    Integer(int) -> sqlight.int(int)
    Real(real) -> sqlight.float(real)
    Text(text) -> sqlight.text(text)
    NullableInteger(int) -> sqlight.nullable(sqlight.int, int)
    NullableReal(real) -> sqlight.nullable(sqlight.float, real)
    NullableText(text) -> sqlight.nullable(sqlight.text, text)
  }
}

pub fn test_round_trip(
  example: a,
  encoder: fn(a) -> List(Value),
  decoder: decode.Decoder(a),
) {
  let assert Ok(conn) = sqlight.open(":memory:")

  let encoded_example = encoder(example)

  let assert Ok(Nil) =
    sqlight.exec(
      "CREATE TABLE persist (" <> build_schema(encoded_example) <> ")",
      on: conn,
    )

  let assert Ok(_) =
    sqlight.query(
      "INSERT INTO persist VALUES ("
        <> list.length(encoded_example)
      |> list.repeat("?", _)
      |> string.join(", ")
        <> ")",
      with: encoded_example |> list.map(translate_persist_type),
      on: conn,
      expecting: decode.success(Nil),
    )

  let assert Ok([out]) =
    sqlight.query(
      "SELECT * FROM persist",
      with: [],
      on: conn,
      expecting: decoder,
    )

  let assert Ok(Nil) = sqlight.close(conn)

  out
}
