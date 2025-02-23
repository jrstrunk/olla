import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import o11a/note
import tempo/instant

pub const component_name = "line-notes"

pub const user_submitted_note_event = "user-submitted-line-note"

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
      #("line-id", fn(dy) {
        case decode.run(dy, decode.string) {
          Ok(line_id) -> Ok(ServerSetLineId(line_id))
          Error(_) ->
            Error([dynamic.DecodeError("line-id", string.inspect(dy), [])])
        }
      }),
    ]),
  )
}

fn init(_) -> #(Model, effect.Effect(Msg)) {
  #(Model(notes: [], current_note_draft: "", line_id: ""), effect.none())
}

pub type Model {
  Model(line_id: String, notes: List(note.Note), current_note_draft: String)
}

pub type Msg {
  ServerSetLineId(String)
  ServerUpdatedNotes(List(note.Note))
  UserWroteNote(String)
  UserSubmittedNote(parent_id: String, note_type: note.NoteType)
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    ServerSetLineId(line_id) -> #(Model(..model, line_id:), effect.none())
    ServerUpdatedNotes(notes) -> #(Model(..model, notes:), effect.none())
    UserWroteNote(draft) -> #(
      Model(..model, current_note_draft: draft),
      effect.none(),
    )
    UserSubmittedNote(parent_id:, note_type:) -> {
      let note =
        note.Note(
          parent_id:,
          note_type:,
          significance: note.Regular,
          user_id: 0,
          message: "",
          expanded_message: None,
          time: instant.now() |> instant.as_utc_datetime,
          thread_id: None,
          last_edit_time: None,
        )

      let note = case model.current_note_draft {
        "todo " <> rest ->
          note.Note(
            ..note,
            significance: note.ToDo,
            message: rest,
            thread_id: option.Some(note.get_note_id(note)),
          )
        "done " <> rest ->
          note.Note(..note, significance: note.ToDoDone, message: rest)
        "? " <> rest ->
          note.Note(
            ..note,
            significance: note.Question,
            message: rest,
            thread_id: option.Some(note.get_note_id(note)),
          )
        ", " <> rest ->
          note.Note(..note, significance: note.Answer, message: rest)
        "! " <> rest ->
          note.Note(
            ..note,
            significance: note.FindingLead,
            message: rest,
            thread_id: option.Some(note.get_note_id(note)),
          )
        ". " <> rest ->
          note.Note(..note, significance: note.FindingRejection, message: rest)
        "!! " <> rest ->
          note.Note(
            ..note,
            significance: note.FindingComfirmation,
            message: rest,
          )
        _ -> note
      }

      #(
        Model(..model, current_note_draft: ""),
        event.emit(user_submitted_note_event, note.encode_note(note)),
      )
    }
  }
}

fn view(model: Model) -> element.Element(Msg) {
  html.div([attribute.class("line-notes-list")], [
    element.fragment(
      list.map(model.notes, fn(note) {
        element.fragment([
          html.p([attribute.class("line-notes-list-item")], [
            html.text(note.message),
          ]),
          html.hr([]),
        ])
      }),
    ),
    html.span([], [html.text("Add a new comment: ")]),
    html.input([
      event.on_input(UserWroteNote),
      on_ctrl_enter(UserSubmittedNote(
        parent_id: model.line_id,
        note_type: note.LineCommentNote,
      )),
      attribute.value(model.current_note_draft),
    ]),
  ])
}

pub fn on_ctrl_enter(msg: msg) {
  use event <- event.on("keydown")

  let decoder = {
    use ctrl_key <- decode.field("ctrlKey", decode.bool)
    use key <- decode.field("key", decode.string)

    decode.success(#(ctrl_key, key))
  }

  let empty_error = [dynamic.DecodeError("", "", [])]

  use #(ctrl_key, key) <- result.try(
    decode.run(event, decoder)
    |> result.replace_error(empty_error),
  )

  case ctrl_key, key {
    True, "Enter" -> Ok(msg)
    _, _ -> Error(empty_error)
  }
}
