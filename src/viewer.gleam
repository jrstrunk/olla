import config
import gleam/dict
import lustre
import lustre/effect
import lustre/element
import lustre/element/html

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
  html.div([], [html.h1([], [html.text("Hello from the viewer!")])])
}
