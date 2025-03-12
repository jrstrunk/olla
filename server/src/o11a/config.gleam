import filepath
import gleam/erlang
import gleam/list
import gleam/string
import simplifile

pub type Config {
  Config(port: Int)
}

pub fn get_prod_config() {
  Config(port: 8413)
}

pub fn get_dev_config() {
  Config(port: 8400)
}

// Gets the full path to the priv, plus the provided local path
pub fn get_priv_path(for local_path) {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  [priv, local_path]
  |> list.fold("/", filepath.join)
}

// Gets the full path to the persist directory, plus the provided local path
pub fn get_persist_path(for local_path) {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  [priv, "persist", local_path]
  |> list.fold("/", filepath.join)
}

// Gets the full path to for the given page path (local path)
pub fn get_full_page_path(for page_path) {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  [priv, "audits", page_path]
  |> list.fold("/", filepath.join)
}

/// Gets the full path to a page skeleton
pub fn get_full_page_skeleton_path(for page_path) {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  [priv, "audits", page_path <> ".skeleton.html"]
  |> list.fold("/", filepath.join)
}

/// Gets the full path to the audit root directory
pub fn get_audit_path(for audit_name) {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  [priv, "audits", audit_name]
  |> list.fold("/", filepath.join)
}

/// Gets the audit name from a page path (local path)
pub fn get_audit_name_from_page_path(for page_path) {
  case string.split(page_path, on: "/") {
    [audit_name, ..] -> audit_name
    [] -> ""
  }
}

/// Gets all audit page paths (local paths)
pub fn get_all_audit_page_paths() {
  let assert Ok(priv) = erlang.priv_directory("o11a")
  let assert Ok(files) =
    [priv, "audits"]
    |> list.fold("/", filepath.join)
    |> simplifile.get_files

  list.map(files, fn(file_path) {
    case string.split(file_path, on: "priv/audits/") {
      [_, file_path] -> file_path
      [unknown, ..] -> unknown
      [] -> ""
    }
  })
  |> list.filter(fn(file_path) {
    case string.to_graphemes(file_path) |> list.reverse {
      // Allow .sol files
      ["l", "o", "s", ".", ..] -> True
      // Allow .rs files
      ["s", "r", ".", ..] -> True
      // Allow .md files
      ["d", "m", ".", ..] -> True
      // everything else
      _ -> False
    }
  })
  |> list.group(get_audit_name_from_page_path)
}

/// Gets the path to the audit's notes database
pub fn get_notes_persist_path(for audit_name) {
  [get_audit_path(for: audit_name), "notes.db"]
  |> list.fold("/", filepath.join)
}

/// Gets the path to the audit's notes database
pub fn get_votes_persist_path(for audit_name) {
  [get_audit_path(for: audit_name), "votes.db"]
  |> list.fold("/", filepath.join)
}
