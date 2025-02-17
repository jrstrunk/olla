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
