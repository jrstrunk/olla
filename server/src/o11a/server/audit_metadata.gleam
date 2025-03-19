import filepath
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import o11a/audit_metadata
import o11a/config
import o11a/server/preprocessor_sol
import simplifile

pub fn gather_metadata(for audit_name) {
  let in_scope_files = get_files_in_scope(for: audit_name)

  use ast_data <- result.map(preprocessor_sol.read_asts(for: audit_name))

  let asts = list.map(ast_data, fn(ast) { ast.1 })

  let _declarations =
    dict.new()
    |> list.fold(asts, _, fn(declarations, ast) {
      preprocessor_sol.enumerate_declarations(declarations, ast)
    })
    |> list.fold(asts, _, fn(declarations, ast) {
      preprocessor_sol.count_references(declarations, ast)
    })

  audit_metadata.AuditMetaData(
    audit_name:,
    audit_formatted_name: audit_name,
    in_scope_files:,
    source_files_sol: dict.new(),
  )
}

fn get_files_in_scope(for audit_name) {
  let in_scope_sol_files =
    config.get_audit_path(for: audit_name)
    |> filepath.join("scope.txt")
    |> simplifile.read
    |> result.unwrap("")
    |> string.split("\n")
    |> list.map(fn(path) {
      case path {
        "./" <> local_path -> audit_name <> "/" <> local_path
        "/" <> local_path -> audit_name <> "/" <> local_path
        local_path -> audit_name <> "/" <> local_path
      }
    })

  let doc_files =
    config.get_all_audit_page_paths()
    |> dict.get(audit_name)
    |> result.unwrap([])
    |> list.filter(fn(path) {
      filepath.extension(path) == Ok("md")
      && !string.starts_with(path, filepath.join(audit_name, "lib"))
      && !string.starts_with(path, filepath.join(audit_name, "dependencies"))
    })

  list.append(in_scope_sol_files, doc_files)
}
