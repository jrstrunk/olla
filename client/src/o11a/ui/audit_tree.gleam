import filepath
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html

pub type Model {
  Model(
    audit_name: String,
    current_file_path: String,
    in_scope_files: List(String),
    grouped_files: dict.Dict(String, #(List(String), List(String))),
  )
}

pub fn view(
  file_contents,
  wrap_contents,
  side_panel,
  grouped_files,
  audit_name,
  current_file_path,
) {
  html.div([attribute.id("tree-grid")], [
    html.div([attribute.id("file-tree")], [
      html.h3([attribute.id("audit-tree-header")], [
        html.text(audit_name <> " files"),
      ]),
      audit_file_tree_view(grouped_files, audit_name, current_file_path),
    ]),
    html.div([attribute.id("tree-resizer")], []),
    html.div(
      [
        attribute.id("file-contents"),
        attribute.class(case wrap_contents {
          True -> "wrap"
          False -> "nowrap"
        }),
      ],
      [file_contents],
    ),
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

fn audit_file_tree_view(grouped_files, audit_name, current_file_path) {
  let #(subdirs, direct_files) =
    dict.get(grouped_files, audit_name) |> result.unwrap(#([], []))

  html.div([attribute.id("audit-files")], [
    html.div(
      [attribute.id(audit_name <> "-files")],
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
    html.div(
      [attribute.id(audit_name <> "-dirs")],
      list.map(subdirs, sub_file_tree_view(_, current_file_path, grouped_files)),
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

pub fn dashboard_path(for audit_name) {
  audit_name <> "/dashboard"
}

pub fn group_files_by_parent(
  in_scope_files in_scope_files,
  current_file_path current_file_path,
  audit_name audit_name,
) {
  // Make sure the file tree always contains the current file path and the
  // dashboard path
  let dashboard_path = dashboard_path(for: audit_name)

  let in_scope_files = case current_file_path == dashboard_path {
    True -> [current_file_path, ..in_scope_files]
    False ->
      case list.contains(in_scope_files, current_file_path) {
        True -> [dashboard_path, ..in_scope_files]
        False -> [current_file_path, dashboard_path, ..in_scope_files]
      }
  }
  let in_scope_files = case list.contains(in_scope_files, dashboard_path) {
    True -> in_scope_files
    False -> [dashboard_path, ..in_scope_files]
  }

  // Get all unique parents including intermediate ones
  let parents =
    in_scope_files
    |> list.flat_map(get_all_parents)
    |> list.unique

  // For each parent, find its immediate subdirs and files
  parents
  |> list.map(fn(parent) {
    let parent_prefix = parent <> "/"

    // Get all items that start with this parent's prefix
    let items =
      in_scope_files
      |> list.filter(fn(path) { string.starts_with(path, parent_prefix) })

    // Get next level of directories and direct files
    let #(dirs, direct_files) =
      items
      |> list.partition(fn(path) {
        let relative = string.replace(path, parent_prefix, "")
        string.contains(relative, "/")
      })

    // For dirs, extract just the next directory level but keep full path
    let subdirs =
      dirs
      |> list.map(fn(dir) {
        let relative = string.replace(dir, parent_prefix, "")
        let first_dir =
          string.split(relative, "/")
          |> list.first
          |> result.unwrap("")
        parent_prefix <> first_dir
      })
      |> list.unique

    #(parent, #(subdirs, direct_files))
  })
  |> dict.from_list
}
