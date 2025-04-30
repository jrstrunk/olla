import filepath
import gleam/dict
import gleam/function
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/string_tree
import lib/snagx
import o11a/config
import o11a/preprocessor
import o11a/server/preprocessor_sol
import o11a/server/preprocessor_text
import persistent_concurrent_dict as pcd
import simplifile
import snag

pub opaque type AuditSourceFiles {
  AuditSourceFiles(
    pcd: pcd.PersistentConcurrentDict(String, string_tree.StringTree),
  )
}

pub fn build() {
  use pcd <- result.map(
    pcd.build(
      config.get_persist_path(for: "audit_preprocessed_source_files"),
      key_encoder: function.identity,
      key_decoder: function.identity,
      val_encoder: fn(val) {
        val |> string_tree.to_string |> string.replace("'", "''")
      },
      val_decoder: fn(val) {
        val |> string.replace("''", "'") |> string_tree.from_string
      },
    ),
  )

  AuditSourceFiles(pcd:)
}

pub fn get_source_file(audit_source_files: AuditSourceFiles, for page_path) {
  case pcd.get(audit_source_files.pcd, page_path) {
    Ok(source_file) -> Ok(source_file)

    Error(Nil) -> {
      case
        preprocess_audit_source(for: config.get_audit_name_from_page_path(
          page_path,
        ))
      {
        Ok(preprocessed_source) -> {
          preprocessed_source
          |> list.filter_map(fn(data) {
            case data {
              option.Some(data) -> Ok(data)
              option.None -> Error(Nil)
            }
          })
          |> list.map(fn(data) {
            let #(page_path, preprocessed_json) = data

            pcd.insert(audit_source_files.pcd, page_path, preprocessed_json)
          })

          pcd.get(audit_source_files.pcd, page_path)
        }

        Error(error) -> {
          io.println(
            error
            |> snag.layer(
              "Failed to preprocess audit source files for " <> page_path,
            )
            |> snag.line_print,
          )
          Error(Nil)
        }
      }
    }
  }
}

fn preprocess_audit_source(for audit_name) {
  use asts <- result.try(
    preprocessor_sol.read_asts(audit_name)
    |> snag.context("Unable to read asts for " <> audit_name),
  )

  let page_paths = config.get_all_audit_page_paths()

  let file_to_ast = dict.from_list(asts)

  let declarations =
    dict.new()
    |> list.fold(asts, _, fn(declarations, ast) {
      preprocessor_sol.enumerate_declarations(declarations, ast.1)
    })
    |> list.fold(asts, _, fn(declarations, ast) {
      preprocessor_sol.count_references(declarations, ast.1)
    })

  dict.get(page_paths, audit_name)
  |> result.unwrap([])
  |> list.map(fn(page_path) {
    case
      filepath.extension(page_path) == Ok("md")
      || filepath.extension(page_path) == Ok("txt"),
      config.get_full_page_path(for: page_path) |> simplifile.read,
      dict.get(file_to_ast, page_path)
    {
      // Source file with an AST
      _, Ok(source), Ok(nodes) -> {
        let nodes = preprocessor_sol.linearize_nodes(nodes)

        let preprocessed_source_json =
          preprocessor_sol.preprocess_source(
            source:,
            nodes:,
            declarations:,
            page_path:,
            audit_name:,
          )
          |> json.array(preprocessor.encode_pre_processed_line)
          |> json.to_string_tree

        Ok(option.Some(#(page_path, preprocessed_source_json)))
      }

      // Text file 
      True, Ok(text), Error(Nil) -> {
        let preprocessed_source_json =
          preprocessor_text.preprocess_source(source: text, page_path:)
          |> json.array(preprocessor.encode_pre_processed_line)
          |> json.to_string_tree

        Ok(option.Some(#(page_path, preprocessed_source_json)))
      }

      // Source file without an AST (unused project dependencies)
      False, Ok(_source), Error(Nil) -> {
        Ok(option.None)
      }

      // If we get a non-text file, just ignore it. Eventually we could 
      // handle image files
      _, Error(simplifile.NotUtf8), _ -> Ok(option.None)

      _, Error(msg), _ ->
        snag.error(msg |> simplifile.describe_error)
        |> snag.context("Failed to preprocess page source for " <> page_path)
    }
  })
  |> snagx.collect_errors
}
