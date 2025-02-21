import gleam/dict
import gleam/dynamic
import gleam/list
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import o11a/note

pub const component_name = "line-notes"

pub fn component() {
  lustre.component(
    init,
    update,
    view,
    dict.from_list([
      #("line-notes", fn(dy) {
        case note.decode_notes(dy) {
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
  Model(notes: List(note.Note))
}

pub type Msg {
  ServerUpdatedNotes(List(note.Note))
}

fn update(_model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    ServerUpdatedNotes(notes) -> #(Model(notes:), effect.none())
  }
}

fn view(model: Model) -> element.Element(Msg) {
  html.div(
    [attribute.class("line-notes-list")],
    list.map(model.notes, fn(note) {
      html.p([attribute.class("line-notes-list-item")], [
        html.text(note.message),
      ])
    }),
  )
}
