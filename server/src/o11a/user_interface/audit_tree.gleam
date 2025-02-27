import filepath
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/config

const style = "
#tree-grid {
  display: grid;
  grid-template-columns: 16rem 4px 1fr;
  height: 100%;
}

#file-tree {
  overflow: auto;
  font-size: 0.9rem;
}

#audit-tree-header {
  text-wrap: nowrap;
}

#tree-resizer {
  border-right: 1px solid var(--overlay-background-color);
  cursor: col-resize;
}

#tree-resizer:hover {
  background-color: var(--overlay-background-color);
}

#file-contents {
  /* grid-area: file-contents; */
  overflow: auto;
}

.tree-item {
  margin-top: 0.25rem;
  margin-bottom: 0.25rem;
}

.tree-link {
  text-decoration: none;
  display: block;
  color: var(--text-color);
}

.tree-link:hover {
  text-decoration: underline;
}

.nested-tree-items {
  padding-left: 0.75rem;
  border-left: 1px solid var(--input-background-color);
}
"

const resize_script = "
document.addEventListener('DOMContentLoaded', function() {

const resizer = document.querySelector('#tree-resizer');
const leftSide = resizer.previousElementSibling;
const container = resizer.parentElement;

let isResizing = false;

resizer.addEventListener('mousedown', (e) => {
  isResizing = true;
  document.addEventListener('mousemove', resize);
  document.addEventListener('mouseup', stopResize);
});

function resize(e) {
  if (!isResizing) return;
  const containerRect = container.getBoundingClientRect();
  const newWidth = e.clientX - containerRect.left;
  container.style.gridTemplateColumns = `${newWidth}px 4px 1fr`;
}

function stopResize() {
  isResizing = false;
  document.removeEventListener('mousemove', resize);
  document.removeEventListener('mouseup', stopResize);
}

});
"

pub fn view(contents, for audit_name) {
  element.fragment([
    html.style([], style),
    html.script([], resize_script),
    html.div([attribute.id("tree-grid")], [
      html.div([attribute.id("file-tree")], [
        html.h3([attribute.id("audit-tree-header")], [
          html.text(audit_name <> " files"),
        ]),
        audit_file_tree_view(audit_name),
      ]),
      html.div([attribute.id("tree-resizer")], []),
      html.div([attribute.id("file-contents")], [contents]),
    ]),
  ])
}

fn audit_file_tree_view(audit_name) {
  let all_audit_files =
    config.get_files_in_scope(for: audit_name)
    |> group_files_by_parent

  let #(subdirs, direct_files) =
    dict.get(all_audit_files, audit_name) |> result.unwrap(#([], []))

  html.div([attribute.class("audit-files")], [
    html.div([attribute.id(audit_name <> "-files")], [
      html.a(
        [
          attribute.class("tree-item tree-link"),
          attribute.href("/" <> audit_name <> "/dashboard"),
          attribute.rel("prefetch"),
        ],
        [html.text("dashboard")],
      ),
      ..list.map(direct_files, fn(file) {
        html.a(
          [
            attribute.class("tree-item tree-link"),
            attribute.href("/" <> file),
            attribute.rel("prefetch"),
          ],
          [html.text(file |> filepath.base_name)],
        )
      })
    ]),
    html.div(
      [attribute.id(audit_name <> "-dirs")],
      list.map(subdirs, sub_file_tree_view(_, all_audit_files)),
    ),
  ])
}

fn sub_file_tree_view(
  dir_name,
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
      list.map(subdirs, sub_file_tree_view(_, all_audit_files)),
    ),
    html.div(
      [attribute.id(dir_name <> "-files"), attribute.class("nested-tree-items")],
      list.map(direct_files, fn(file) {
        html.a(
          [
            attribute.class("tree-item tree-link"),
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
