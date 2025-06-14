import filepath
import gleam/int
import gleam/list
import gleam/result
import lib/djotx
import lib/snagx
import o11a/config
import simplifile
import snag

pub fn read_asts(for audit_name) {
  // Get all the text files in the audit directory and sub directories
  use text_files <- result.map(
    config.get_audit_page_paths(audit_name:)
    |> list.filter(fn(page_path) {
      case filepath.extension(page_path) {
        Ok("md") -> True
        Ok("dj") -> True
        _ -> False
      }
    })
    |> list.map(fn(page_path) {
      use source <- result.map(
        config.get_full_page_path(for: page_path)
        |> simplifile.read
        |> snag.map_error(simplifile.describe_error),
      )
      #(page_path, source)
    })
    |> snagx.collect_errors,
  )

  list.index_map(text_files, fn(text_file, index) {
    let #(page_path, source) = text_file
    djotx.parse(source, "ST" <> int.to_string(index + 1), page_path)
  })
}
