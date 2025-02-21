import gleam/dict
import gleam/dynamic
import gleam/list
import gleam/string
import lustre
import lustre/effect
import lustre/element
import lustre/element/html
import o11a/server/discussion

pub const component_name = "line-notes"

pub fn component() {
  lustre.component(
    init,
    update,
    view,
    dict.from_list([
      #("line-notes", fn(dy) {
        case discussion.decode_notes(dy) {
          Ok(notes) -> Ok(ServerUpdatedNotes(notes))
          Error(_) ->
            Error([dynamic.DecodeError("line-notes", string.inspect(dy), [])])
        }
      }),
    ]),
  )
}

fn init(_) -> #(Model, effect.Effect(Msg)) {
  #(Model(notes: []), effect.none())
}

pub type Model {
  Model(notes: List(discussion.Note))
}

pub type Msg {
  ServerUpdatedNotes(List(discussion.Note))
}

fn update(_model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    ServerUpdatedNotes(notes) -> #(Model(notes:), effect.none())
  }
}

fn view(model: Model) -> element.Element(Msg) {
  html.div(
    [],
    list.map(model.notes, fn(note) { html.p([], [html.text(note.message)]) }),
  )
}
