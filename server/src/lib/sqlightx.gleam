import gleam/dynamic/decode
import gleam/result
import gleam/string
import snag
import sqlight

pub fn describe_connection_error(
  error: Result(sqlight.Connection, sqlight.Error),
  path,
) {
  case error {
    Error(msg) ->
      snag.error(string.inspect(msg))
      |> snag.context("Unable to open connection to " <> path)
    Ok(conn) -> Ok(conn)
  }
}

pub fn insert(query, on conn, with data) {
  sqlight.query(query, conn, decode.int, with: data)
  |> result.map(fn(_) { Nil })
}
