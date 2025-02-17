import gleam/dict
import gleam/int
import gleam/list
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import o11a/config
import server/discussion
import simplifile
import snag
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

pub fn generate_skeleton(from source: String) {
  html.div([attribute.class("code-snippet")], loc_hmtl(source, True))
  |> element.to_string
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

pub fn get_skeleton(for page_path) {
  let skeleton_path = config.get_full_page_skeleton_path(for: page_path)
  case simplifile.read(skeleton_path) {
    Ok(skeleton) -> Ok(skeleton)

    Error(simplifile.Enoent) ->
      case config.get_full_page_path(for: page_path) |> simplifile.read {
        Ok(page_source) -> {
          let skeleton = generate_skeleton(from: page_source)

          let assert Ok(Nil) = simplifile.write(skeleton, to: skeleton_path)

          Ok(skeleton)
        }

        Error(msg) -> string.inspect(msg) |> snag.error
      }

    Error(msg) -> string.inspect(msg) |> snag.error
  }
}
