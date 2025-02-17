import gleam/io
import o11a/config

pub fn config_test() {
  config.get_all_audit_file_paths()
  |> io.debug
}
