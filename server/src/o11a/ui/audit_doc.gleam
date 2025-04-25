import gleam/string
import lustre/attribute
import lustre/element/html

const md_doc_id = "md_doc"

fn render_md_script(md_content) {
  "import { marked } from \"https://cdn.jsdelivr.net/npm/marked/lib/marked.esm.js\";
document.getElementById('"
  <> md_doc_id
  <> "').innerHTML = marked.parse(`"
  <> string.replace(md_content, "`", "\\`")
  <> "`);"
}

pub fn view(md_doc_contents) {
  html.div(
    [attribute.id("readme-container"), attribute.style("margin-left", "2rem")],
    [
      html.script(
        [attribute.type_("module")],
        render_md_script(md_doc_contents),
      ),
      html.div([attribute.id(md_doc_id)], []),
    ],
  )
}
