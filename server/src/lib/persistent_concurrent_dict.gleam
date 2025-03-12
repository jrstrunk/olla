import concurrent_dict
import filepath
import gleam/dynamic/decode
import gleam/result
import gleam/string
import o11a/config
import simplifile
import snag
import sqlight

pub opaque type PersistentConcurrentDict(key, val) {
  PersistentConcurrentDict(
    conn: sqlight.Connection,
    key_encoder: fn(key) -> String,
    val_encoder: fn(val) -> String,
    data: concurrent_dict.ConcurrentDict(key, val),
  )
}

pub fn build(
  name name: String,
  key_encoder key_encoder: fn(key) -> String,
  key_decoder key_decoder: fn(String) -> key,
  val_encoder val_encoder: fn(val) -> String,
  val_decoder val_decoder: fn(String) -> val,
) {
  let path = config.get_persist_path(for: name <> ".db")

  let assert Ok(Nil) =
    filepath.directory_name(path)
    |> simplifile.create_directory_all

  use conn <- result.try(
    sqlight.open(path)
    |> snag.map_error(string.inspect),
  )

  use Nil <- result.try(
    sqlight.exec(table_schema, on: conn)
    |> snag.map_error(string.inspect),
  )

  use data_list <- result.map(
    sqlight.query(select_query, with: [], on: conn, expecting: {
      use key <- decode.field(0, decode.string)
      use value <- decode.field(1, decode.string)
      decode.success(#(key_decoder(key), val_decoder(value)))
    })
    |> snag.map_error(string.inspect),
  )

  let data = concurrent_dict.from_list(data_list)

  PersistentConcurrentDict(conn:, key_encoder:, val_encoder:, data:)
}

pub fn get(pcd: PersistentConcurrentDict(key, val), key) {
  concurrent_dict.get(pcd.data, key)
}

pub fn insert(pcd: PersistentConcurrentDict(key, val), key, val) {
  let encoded_key = pcd.key_encoder(key)
  let encoded_val = pcd.val_encoder(val)
  let query = insert_query(encoded_key, encoded_val)

  use Nil <- result.map(
    sqlight.exec(query, on: pcd.conn) |> snag.map_error(string.inspect),
  )

  concurrent_dict.insert(pcd.data, key, val)
}

const table_schema = "
CREATE TABLE IF NOT EXISTS persist (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)"

fn insert_query(key, value) {
  "INSERT OR REPLACE INTO persist (key, value) VALUES ('"
  <> key
  <> "', '"
  <> value
  <> "')"
}

const select_query = "SELECT key, value FROM persist"
