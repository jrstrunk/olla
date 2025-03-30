import gleam/int
import gleam/result
import o11a/classes
import plinth/browser/document
import snag

pub fn non_empty_line(line_number) {
  document.query_selector(
    "#L" <> int.to_string(line_number) <> "." <> classes.line_container,
  )
  |> result.replace_error(snag.new("Failed to find non-empty line"))
}
