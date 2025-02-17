import gleam/dict
import gleam/int
import gleam/list
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import server/discussion
import text

pub const name = "o11a-discussions"

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(init, update, view, dict.new())
}

pub type Msg {
  Msg
}

pub type Model {
  Model(page_notes: discussion.PageNotes)
}

pub fn init(init_model) -> #(Model, effect.Effect(Msg)) {
  #(init_model, effect.none())
}

pub fn update(model: Model, _msg: Msg) -> #(Model, effect.Effect(Msg)) {
  #(model, effect.none())
}

fn view(model: Model) -> element.Element(Msg) {
  html.div([], [
    html.h1([], [html.text(model.page_notes.page_path)]),
    html.div([attribute.class("code-snippet")], loc_hmtl(text.file_body, False)),
  ])
}

pub fn skeleton() {
  html.div([attribute.class("code-snippet")], loc_hmtl(text.file_body, True))
}

fn loc_hmtl(solidity_source text: String, skeleton skeleton: Bool) {
  text
  |> string.split(on: "\n")
  |> list.index_map(fn(original_line, index) {
    case original_line {
      "" -> html.p([attribute.class("loc")], [html.text(" ")])
      _ -> {
        let line = original_line

        case skeleton {
          True ->
            html.p(
              [
                attribute.class("loc"),
                attribute.id("loc" <> int.to_string(index)),
              ],
              [html.text(line)],
            )
          False ->
            html.div([attribute.class("hover-container")], [
              html.p(
                [
                  attribute.class("loc"),
                  attribute.id("loc" <> int.to_string(index)),
                ],
                [
                  html.text(line),
                  html.span([attribute.class("line-hover-discussion")], [
                    html.text("!"),
                  ]),
                ],
              ),
            ])
        }
      }
    }
  })
}
// This could be used to generate a skeleton for the page. Not sure if generating
// the skeleton on the fly or reading a pre-rendered version from disk is faster.
// pub fn skeleton(page_id page_id) {
//   case simplifile.read(from: "priv/static/" <> page_id <> "_skeleton.html") {
//     Ok(prerendered_html) -> html.div([attribute.attribute("dangerous-unescaped-html", prerendered_html)], [])
//     Error(_) -> html.div([], [])
//   }
// }

// pub fn generate_skeleton(from source: String, with page_id: String) {
//   html.div([attribute.class("code-snippet")], loc_hmtl(source, skeleton: True))
//   |> element.to_string
//   |> simplifile.write(to: "priv/static/" <> page_id <> "_skeleton.html")
// }
