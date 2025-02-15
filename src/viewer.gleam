import config
import gleam/dict
import gleam/int
import gleam/list
import gleam/string
import lustre
import lustre/attribute.{class}
import lustre/effect
import lustre/element
import lustre/element/html
import text

pub const name = "olla-vewier"

pub fn app() -> lustre.App(config.Config, Model, Msg) {
  lustre.component(init, update, view, dict.new())
}

pub type Msg {
  Msg
}

pub type Model {
  Model
}

pub fn init(_config) -> #(Model, effect.Effect(Msg)) {
  let model = Model
  #(model, effect.none())
}

pub fn update(model: Model, _msg: Msg) -> #(Model, effect.Effect(Msg)) {
  #(model, effect.none())
}

fn view(_model: Model) -> element.Element(Msg) {
  html.div([], [
    html.h1([], [html.text("Hello from the viewer!")]),
    html.div([class("code-snippet")], get_lines()),
  ])
}

fn get_lines() {
  text.file_body
  |> string.split(on: "\n")
  |> list.index_map(fn(line, index) {
    case line {
      "" -> html.br([])
      _ ->
        html.div(
          [
            attribute.class("hover-container"),
            attribute.id("loc" <> int.to_string(index)),
          ],
          [
            html.p([attribute.class("allow-indent"), attribute.class("loc")], [
              html.text(line),
              html.span([attribute.class("line-hover-discussion")], [
                html.text("D!"),
              ]),
            ]),
          ],
        )
    }
  })
}
