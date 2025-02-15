import config
import gleam/dict
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import server/discussion
import text

pub const name = "o11a-discussions"

pub fn app() -> lustre.App(#(String, config.Config), Model, Msg) {
  lustre.component(init, update, view, dict.new())
}

pub type Msg {
  Msg
}

pub type Model {
  Model(discussions: discussion.PageDiscussions)
}

pub fn init(data: #(String, config.Config)) -> #(Model, effect.Effect(Msg)) {
  let #(page_id, config) = data
  let model =
    Model(
      discussions: dict.new(),
      // discussions: actor.call(
    //   config.discussion_gateway,
    //   discussion.GetDiscussions(page_id, reply: _),
    //   1_000_000,
    // ),
    )

  #(model, effect.none())
}

pub fn update(model: Model, _msg: Msg) -> #(Model, effect.Effect(Msg)) {
  #(model, effect.none())
}

fn view(_model: Model) -> element.Element(Msg) {
  html.div(
    [attribute.class("code-snippet")],
    get_code_lines(text.file_body, False),
  )
}

pub fn skeleton() {
  html.div(
    [attribute.class("code-snippet")],
    get_code_lines(text.file_body, True),
  )
}

fn get_code_lines(solidity_source text: String, skeleton skeleton: Bool) {
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
