import gleam/int
import gleam/result
import o11a/classes
import plinth/browser/document
import plinth/browser/shadow
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

pub fn discussion_input(line_number line_number, column_number column_number) {
  document.query_selector(
    ".dl"
    <> int.to_string(line_number)
    <> ".dc"
    <> int.to_string(column_number)
    <> " input",
  )
}

pub fn discussion_expanded_input(
  line_number line_number,
  column_number column_number,
) {
  document.query_selector(
    ".dl"
    <> int.to_string(line_number)
    <> ".dc"
    <> int.to_string(column_number)
    <> " textarea",
  )
}

pub fn audit_discussion() {
  document.query_selector("#discussion-component")
  |> result.try(shadow.shadow_root)
  |> result.try(shadow.query_selector(_, "#discussion-data"))
}
