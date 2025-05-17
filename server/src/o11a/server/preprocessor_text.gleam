//// Every newline represents a line node and every double newline represents a
//// paragraph node. Paragraph nodes are simply made up of line nodes, this is
//// the simple AST for text files.

import filepath
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import lib/snagx
import o11a/config
import o11a/declaration
import o11a/preprocessor
import simplifile
import snag

pub fn preprocess_source(source source: String, page_path page_path: String) {
  use line, index <- list.index_map(consume_source(source:, page_path:))

  let line_number = index + 1
  let line_number_text = int.to_string(line_number)
  let line_tag = "L" <> line_number_text
  let line_id = page_path <> "#" <> line_tag

  let significance = case line {
    preprocessor.PreProcessedDeclaration(node_declaration:, ..) ->
      preprocessor.SingleDeclarationLine(
        signature: node_declaration.signature,
        topic_id: node_declaration.topic_id,
      )
    _ -> preprocessor.EmptyLine
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
      "" -> [
        preprocessor.PreProcessedGapNode(element: line, leading_spaces: 0),
        ..acc
      ]
      _ -> {
        let line_number_text = { acc |> list.length } + 1 |> int.to_string
        [
          preprocessor.PreProcessedDeclaration(
            node_id: acc |> list.length,
            node_declaration: line_node_declaration(page_path, line_number_text),
            tokens: line,
          ),
          ..acc
        ]
      }
    }
  })
  |> list.reverse
}

pub fn enumerate_declarations(declarations, in ast: AST) {
  list.fold(ast.nodes, declarations, fn(declarations, node) {
    case node {
      LineNode(id:, line_number:) ->
        dict.insert(
          declarations,
          id,
          line_node_declaration(ast.absolute_path, line_number |> int.to_string),
        )
    }
  })
}

fn line_node_declaration(page_path, line_number_text) {
  declaration.Declaration(
    name: "L" <> line_number_text,
    scope: declaration.Scope(
      file: filepath.base_name(page_path),
      contract: option.None,
      member: option.None,
    ),
    signature: filepath.base_name(page_path) <> "#L" <> line_number_text,
    topic_id: page_path <> "#L" <> line_number_text,
    kind: declaration.UnknownDeclaration,
    references: [],
  )
}

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

  list.map(text_files, fn(text_file) {
    let lines = string.split(text_file.1, on: "\n")

    let nodes =
      list.index_map(lines, fn(_line, index) {
        LineNode(id: index + 1, line_number: index + 1)
      })

    AST(id: 0, absolute_path: text_file.0, nodes:)
  })
}

pub type AST {
  AST(id: Int, absolute_path: String, nodes: List(Node))
}

pub type Node {
  LineNode(id: Int, line_number: Int)
}
