import filepath
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/audit_metadata

pub fn view(
  file_contents,
  side_panel,
  for audit_name,
  on current_file_path,
  with metadata,
) {
  html.div([attribute.id("tree-grid")], [
    html.div([attribute.id("file-tree")], [
      html.h3([attribute.id("audit-tree-header")], [
        html.text(audit_name <> " files"),
      ]),
      audit_file_tree_view(audit_name, current_file_path, metadata),
    ]),
    html.div([attribute.id("tree-resizer")], []),
    html.div([attribute.id("file-contents")], [file_contents]),
    case option.is_some(side_panel) {
      True -> html.div([attribute.id("panel-resizer")], [])
      False -> element.fragment([])
    },
    case side_panel {
      Some(side_panel) -> html.div([attribute.id("side-panel")], [side_panel])
      None -> element.fragment([])
    },
  ])
}

fn audit_file_tree_view(
  audit_name,
  current_file_path,
  metadata: audit_metadata.AuditMetaData,
) {
  let all_audit_files =
    metadata.in_scope_files
    |> group_files_by_parent

  let #(subdirs, direct_files) =
    dict.get(all_audit_files, audit_name) |> result.unwrap(#([], []))

  let dashboard_path = audit_name <> "/dashboard"

  html.div([attribute.id("audit-files")], [
    html.div([attribute.id(audit_name <> "-files")], [
      html.a(
        [
          attribute.class(
            "tree-item tree-link"
            <> case current_file_path == dashboard_path {
              True -> " underline"
              False -> ""
            },
          ),
          attribute.href("/" <> dashboard_path),
          attribute.rel("prefetch"),
        ],
        [html.text("dashboard")],
      ),
      ..list.map(direct_files, fn(file) {
        html.a(
          [
            attribute.class(
              "tree-item tree-link"
              <> case file == current_file_path {
                True -> " underline"
                False -> ""
              },
            ),
            attribute.href("/" <> file),
            attribute.rel("prefetch"),
          ],
          [html.text(file |> filepath.base_name)],
        )
      })
    ]),
    html.div(
      [attribute.id(audit_name <> "-dirs")],
      list.map(subdirs, sub_file_tree_view(
        _,
        current_file_path,
        all_audit_files,
      )),
    ),
  ])
}

fn sub_file_tree_view(
  dir_name,
  current_file_path,
  all_audit_files: dict.Dict(String, #(List(String), List(String))),
) {
  let #(subdirs, direct_files) =
    dict.get(all_audit_files, dir_name) |> result.unwrap(#([], []))

  html.div([attribute.id(dir_name)], [
    html.p([attribute.class("tree-item")], [
      html.text(dir_name |> filepath.base_name),
    ]),
    html.div(
      [attribute.id(dir_name <> "-dirs"), attribute.class("nested-tree-items")],
      list.map(subdirs, sub_file_tree_view(
        _,
        current_file_path,
        all_audit_files,
      )),
    ),
    html.div(
      [attribute.id(dir_name <> "-files"), attribute.class("nested-tree-items")],
      list.map(direct_files, fn(file) {
        html.a(
          [
            attribute.class(
              "tree-item tree-link"
              <> case file == current_file_path {
                True -> " underline"
                False -> ""
              },
            ),
            attribute.href("/" <> file),
            attribute.rel("prefetch"),
          ],
          [html.text(file |> filepath.base_name)],
        )
      }),
    ),
  ])
}

/// Thanks Claude ;)
/// Helper to get all parent directories of a path
fn get_all_parents(path) {
  path
  |> string.split("/")
  |> list.take(list.length(string.split(path, "/")) - 1)
  |> list.index_fold([], fn(acc, segment, i) {
    case i {
      0 -> [segment, ..acc]
      _ -> {
        let prev = list.first(acc) |> result.unwrap("")
        [prev <> "/" <> segment, ..acc]
      }
    }
  })
  |> list.reverse
}

pub fn group_files_by_parent(files) {
  // Get all unique parents including intermediate ones
  let parents =
    files
    |> list.flat_map(get_all_parents)
    |> list.unique

  // For each parent, find its immediate subdirs and files
  parents
  |> list.map(fn(parent) {
    let parent_prefix = parent <> "/"
    let items =
      files
      |> list.filter(fn(path) { string.starts_with(path, parent_prefix) })

    // Split into directories and files under this parent
    let #(dirs, direct_files) =
      items
      |> list.filter(fn(path) {
        // Only include immediate children
        let relative = string.replace(path, parent_prefix, "")
        !string.contains(relative, "/")
        || string.split(relative, "/") |> list.length == 2
      })
      |> list.partition(fn(path) {
        let relative = string.replace(path, parent_prefix, "")
        string.contains(relative, "/")
      })

    // For dirs, we just want the immediate subdirectory names
    let subdirs =
      dirs
      |> list.map(fn(dir) {
        string.replace(dir, parent_prefix, "")
        |> string.split("/")
        |> list.first
        |> result.unwrap("")
        |> fn(d) { parent_prefix <> d }
      })
      |> list.unique

    #(parent, #(subdirs, direct_files))
  })
  |> dict.from_list
}
