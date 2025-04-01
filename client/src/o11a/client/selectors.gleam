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

pub fn discussion_entry(line_number line_number, column_number column_number) {
  document.query_selector(
    ".dl" <> int.to_string(line_number) <> ".dc" <> int.to_string(column_number),
  )
}
