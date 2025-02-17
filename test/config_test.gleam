import config
import gleam/io

pub fn config_test() {
  config.get_all_audit_file_paths()
  |> io.debug
}
