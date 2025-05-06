import gleam/int
import gleam/result
import lustre/attribute
import plinth/browser/element
import snag

pub fn encode_line_count_data(line_count) {
  attribute.data("lc", line_count)
}

pub fn read_line_count_data(data) {
  element.dataset_get(data, "lc")
  |> result.try(int.parse)
  |> result.replace_error(snag.new("Failed to read line count data"))
}

pub fn encode_column_count_data(column_count) {
  attribute.data("cc", int.to_string(column_count))
}

pub fn read_column_count_data(data) {
  element.dataset_get(data, "cc")
  |> result.try(int.parse)
  |> result.replace_error(snag.new("Failed to read column count data"))
}
