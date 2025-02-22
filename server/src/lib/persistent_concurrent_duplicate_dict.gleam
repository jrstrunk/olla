import filepath
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import lib/concurrent_duplicate_dict
import lib/snagx
import lib/sqlightx
import simplifile
import snag
import sqlight

pub opaque type PersistentConcurrentDuplicateDict(key, val) {
  PersistentConcurrentDuplicateDict(
    conn: sqlight.Connection,
    insert_query: String,
    key_encoder: fn(key) -> String,
    val_encoder: fn(val) -> List(Value),
    data: concurrent_duplicate_dict.ConcurrentDuplicateDict(key, val),
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

  let assert Ok(Nil) =
    filepath.directory_name(path)
    |> simplifile.create_directory_all

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

  // Sadly to keep to keep interface abstraction, we have to gather all keys
  // first, then query for each key's data. This avoids the user having to
  // write a decoder that is aware of how this lib works.

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

  use data_list <- result.map(
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

  let data = concurrent_duplicate_dict.from_nested_list(data_list)

  let insert_query =
    "INSERT INTO persist (pcdd_key, "
    <> column_names
    <> ") VALUES (?, "
    <> column_binds
    <> ")"

  PersistentConcurrentDuplicateDict(
    conn:,
    insert_query:,
    key_encoder:,
    val_encoder:,
    data:,
  )
}

pub fn get(pcd: PersistentConcurrentDuplicateDict(key, val), key) {
  concurrent_duplicate_dict.get(pcd.data, key)
}

pub fn insert(pcdd: PersistentConcurrentDuplicateDict(key, val), key, val) {
  let encoded_key = pcdd.key_encoder(key)
  let encoded_vals = pcdd.val_encoder(val)

  use _ <- result.map(
    sqlight.query(
      pcdd.insert_query,
      on: pcdd.conn,
      with: [
        sqlight.text(encoded_key),
        ..list.map(encoded_vals, translate_persist_type)
      ],
      expecting: decode.success(Nil),
    )
    |> snag.map_error(string.inspect),
  )

  concurrent_duplicate_dict.insert(pcdd.data, key, val)
}

/// Creates an empty dictionary that will fail to store any data, but can 
/// satisfy type requirements and will always return no data.
pub fn empty() {
  let assert Ok(conn) = sqlight.open(":memory:")
  PersistentConcurrentDuplicateDict(
    conn:,
    insert_query: "",
    key_encoder: string.inspect,
    val_encoder: fn(_) { [] },
    data: concurrent_duplicate_dict.new(),
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
