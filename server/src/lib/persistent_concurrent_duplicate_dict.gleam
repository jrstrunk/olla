import filepath
import gleam/dynamic/decode
import gleam/list
import gleam/regexp
import gleam/result
import gleam/string
import lib/concurrent_duplicate_dict
import lib/snagx
import lib/sqlightx
import o11a/config
import simplifile
import snag
import sqlight

pub opaque type PersistentConcurrentDuplicateDict(key, val) {
  PersistentConcurrentDuplicateDict(
    conn: sqlight.Connection,
    insert_query: String,
    key_encoder: fn(key) -> String,
    val_encoder: fn(val) -> List(sqlight.Value),
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
  name name: String,
  key_encoder key_encoder: fn(key) -> String,
  key_decoder key_decoder: fn(String) -> key,
  field_schema field_schema: String,
  val_encoder val_encoder: fn(val) -> List(sqlight.Value),
  val_decoder val_decoder: decode.Decoder(val),
) {
  let path = config.get_persist_path(for: name <> ".db")

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

  use column_names <- result.try(get_column_names_from_field_schema(
    field_schema,
  ))

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

  let user_defined_column_count =
    column_names
    |> string.split(",")
    |> list.length

  let insert_query =
    "INSERT INTO persist (pcdd_key, "
    <> column_names
    <> ") VALUES (?, "
    <> list.repeat("?", user_defined_column_count) |> string.join(", ")
    <> ")"

  PersistentConcurrentDuplicateDict(
    conn:,
    insert_query:,
    key_encoder:,
    val_encoder:,
    data:,
  )
}

fn get_column_names_from_field_schema(field_schema) {
  use column_name_regex <- result.map(
    regexp.compile(
      "\\s+((?:TEXT|INTEGER|REAL|BLOB|NULL|PRIMARY KEY|NOT NULL)[^,]*)",
      regexp.Options(case_insensitive: True, multi_line: True),
    )
    |> snag.map_error(string.inspect),
  )

  regexp.replace(column_name_regex, field_schema, "")
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
      with: [sqlight.text(encoded_key), ..encoded_vals],
      expecting: decode.success(Nil),
    )
    |> snag.map_error(string.inspect),
  )

  concurrent_duplicate_dict.insert(pcdd.data, key, val)
}
