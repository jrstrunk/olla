//// Every newline represents a line node.

import filepath
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/string
import lib/snagx
import o11a/config
import o11a/declaration
import o11a/preprocessor
import simplifile
import snag

pub fn preprocess_source(
  nodes nodes: List(Node),
  declarations declarations,
  page_path page_path: String,
) {
  use line, index <- list.index_map(consume_source(nodes:, declarations:))

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
    kind: preprocessor.TextLine,
  )
}

fn consume_source(nodes nodes: List(Node), declarations declarations) {
  list.fold(nodes, [], fn(acc, node) {
    case node {
      NewLineNode(..) -> [
        preprocessor.PreProcessedGapNode(element: "", leading_spaces: 0),
        ..acc
      ]
      LineNode(id:, line:, ..) -> {
        [
          preprocessor.PreProcessedDeclaration(
            node_id: acc |> list.length,
            node_declaration: dict.get(declarations, id)
              |> result.unwrap(declaration.unknown_declaration),
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
      NewLineNode(..) -> declarations
      LineNode(id:, line_number:, ..) -> {
        let line_number_text = line_number |> int.to_string
        let page_path = ast.absolute_path

        let #(id_acc, declarations) = declarations
        #(
          id_acc + 1,
          dict.insert(declarations, id, #(
            page_path <> "#L" <> line_number_text,
            declaration.Declaration(
              name: "L" <> line_number_text,
              scope: declaration.Scope(
                file: filepath.base_name(page_path),
                contract: option.None,
                member: option.None,
              ),
              signature: filepath.base_name(page_path)
                <> "#L"
                <> line_number_text,
              topic_id: id_acc,
              kind: declaration.LineDeclaration,
              references: [],
            ),
          )),
        )
      }
    }
  })
}

pub fn linearize_nodes(in ast: AST) {
  list.sort(ast.nodes, by: fn(a, b) {
    int.compare(a.line_number, b.line_number)
  })
}

pub fn read_asts(for audit_name) -> Result(List(AST), snag.Snag) {
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

  list.scan(text_files, #(0, []), fn(acc, text_file) {
    let #(id_acc, asts) = acc

    let lines = string.split(text_file.1, on: "\n")

    let nodes =
      list.index_map(lines, fn(line, index) {
        let id = id_acc + index + 1
        let line_number = index + 1
        case line {
          "" -> NewLineNode(id:, line_number:)
          _ -> LineNode(id:, line_number:, line:)
        }
      })

    #(id_acc + list.length(lines), [
      AST(id: 0, absolute_path: text_file.0, nodes:),
      ..asts
    ])
  })
  |> list.map(pair.second)
  |> list.flatten
}

pub type AST {
  AST(id: Int, absolute_path: String, nodes: List(Node))
}

pub type Node {
  LineNode(id: Int, line_number: Int, line: String)
  NewLineNode(id: Int, line_number: Int)
}
