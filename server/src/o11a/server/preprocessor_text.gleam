//// Every newline represents a line node and every double newline represents a
//// paragraph node. Paragraph nodes are simply made up of line nodes, this is
//// the simple AST for text files.

import filepath
import gleam/int
import gleam/list
import gleam/string
import o11a/preprocessor

pub fn preprocess_source(source source: String, page_path page_path: String) {
  use line, index <- list.index_map(consume_source(source:, page_path:))

  let line_number = index + 1
  let line_number_text = int.to_string(line_number)
  let line_tag = "L" <> line_number_text
  let line_id = page_path <> "#" <> line_tag

  let significance = case line {
    preprocessor.PreProcessedDeclaration(
      node_declaration: preprocessor.NodeDeclaration(
        title:,
        topic_id:,
        ..,
      ),
      ..,
    ) -> preprocessor.SingleDeclarationLine(topic_id:, topic_title: title)
    _ -> preprocessor.NonEmptyLine
  }

  preprocessor.PreProcessedLine(
    significance:,
    line_number:,
    line_number_text:,
    line_tag:,
    line_id:,
    leading_spaces: 0,
    elements: [line],
    columns: 1,
  )
}

fn consume_source(source source: String, page_path page_path: String) {
  string.split(source, on: "\n")
  |> list.fold([], fn(acc, line) {
    case line |> string.trim {
      "" -> [preprocessor.PreProcessedNode(element: line), ..acc]
      _ -> {
        let line_number_text = { acc |> list.length } + 1 |> int.to_string
        [
          preprocessor.PreProcessedDeclaration(
            node_id: acc |> list.length,
            node_declaration: preprocessor.NodeDeclaration(
              title: filepath.base_name(page_path) <> "#L" <> line_number_text,
              topic_id: page_path <> "#L" <> line_number_text,
              kind: preprocessor.UnknownDeclaration,
              references: [],
            ),
            tokens: line,
          ),
          ..acc
        ]
      }
    }
  })
  |> list.reverse
}
