import o11a/server/preprocessor_text
import simplifile

pub fn readme_test() {
  let assert Ok(src) = simplifile.read("priv/audits/nudgexyz/README.md")

  preprocessor_text.preprocess_source(src, "nudgexyz/README.md")
}
