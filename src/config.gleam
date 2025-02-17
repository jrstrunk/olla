import filepath
import gleam/erlang
import gleam/list
import gleam/string
import simplifile

pub type Config {
  Config(port: Int)
}

pub fn get_priv_path(for local_path) {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  [priv, local_path]
  |> list.fold("/", filepath.join)
}

pub fn get_persist_path(for local_path) {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  [priv, "persist", local_path]
  |> list.fold("/", filepath.join)
}

pub fn get_full_page_path(for page_path) {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  [priv, "static", "audits", page_path]
  |> list.fold("/", filepath.join)
}

pub fn get_full_page_skeleton_path(for page_path) {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  [priv, "static", "audits", page_path <> "_skeleton.html"]
  |> list.fold("/", filepath.join)
}

pub fn get_full_page_db_path(for page_path) {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  [priv, "static", "audits", page_path <> ".db"]
  |> list.fold("/", filepath.join)
}

pub fn get_all_audit_file_paths() {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  let assert Ok(files) =
    [priv, "static", "audits"]
    |> list.fold("/", filepath.join)
    |> simplifile.get_files

  list.map(files, fn(file_path) {
    case string.split(file_path, on: "static/audits/") {
      [_, file_path] -> file_path
      [unknown, ..] -> unknown
      [] -> ""
    }
  })
  |> list.filter(fn(file_path) {
    let gr = string.to_graphemes(file_path) |> list.reverse
    case list.take(gr, 5), list.take(gr, 3) {
      // ".html" files
      ["l", "m", "t", "h", "."], _ -> False
      // ".db" files
      _, ["b", "d", "."] -> False
      // everything else
      _, _ -> True
    }
  })
}
