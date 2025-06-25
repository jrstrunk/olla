import filepath
import gleam/int
import gleam/list
import gleam/result
import lib/snagx
import o11a/config
import o11a/preprocessor_text
import simplifile
import snag

pub fn read_asts(for audit_name, source_topics source_topics) {
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
    preprocessor_text.parse(
      source:,
      document_id: "T" <> int.to_string(index + 1),
      document_parent: page_path,
      max_topic_id: 0,
      topics: source_topics,
    )
  })
}
