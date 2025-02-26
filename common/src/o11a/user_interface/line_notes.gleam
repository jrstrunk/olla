import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lib/effectx
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import o11a/note
import tempo/datetime
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
        case note.decode_structured_notes(dy) {
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
  #(
    Model(
      user_id: 0,
      notes: dict.new(),
      current_note_draft: "",
      line_id: "",
      active_thread: option.None,
    ),
    effect.none(),
  )
}

pub type Model {
  Model(
    user_id: Int,
    line_id: String,
    notes: dict.Dict(String, List(note.Note)),
    current_note_draft: String,
    active_thread: Option(ActiveThread),
  )
}

fn get_current_thread_id(model: Model) {
  case model.active_thread {
    Some(thread) -> thread.current_thread_id
    None -> model.line_id
  }
}

pub type ActiveThread {
  ActiveThread(
    current_thread_id: String,
    parent_note: note.Note,
    prior_thread_id: String,
    prior_thread: Option(ActiveThread),
  )
}

pub type Msg {
  ServerSetLineId(String)
  ServerUpdatedNotes(List(#(String, List(note.Note))))
  UserWroteNote(String)
  UserSubmittedNote(parent_id: String)
  UserSwitchedToThread(new_thread_id: String, parent_note: note.Note)
  UserClosedThread
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    ServerSetLineId(line_id) -> #(Model(..model, line_id:), effect.none())
    ServerUpdatedNotes(notes) -> #(
      Model(..model, notes: dict.from_list(notes)),
      effect.none(),
    )
    UserWroteNote(draft) -> #(
      Model(..model, current_note_draft: draft),
      effect.none(),
    )
    UserSubmittedNote(parent_id:) -> {
      let now = instant.now() |> instant.as_utc_datetime

      let note_id =
        int.to_string(model.user_id)
        <> "-"
        <> now |> datetime.to_unix_micro |> int.to_string

      let note =
        note.Note(
          note_id:,
          parent_id:,
          significance: note.Regular,
          user_id: model.user_id,
          message: model.current_note_draft,
          expanded_message: None,
          time: now,
          edited: False,
        )

      let note = case model.active_thread, model.current_note_draft {
        None, "todo " <> rest ->
          note.Note(..note, significance: note.ToDo, message: rest)
        Some(..), "done " <> rest ->
          note.Note(..note, significance: note.ToDoDone, message: rest)
        None, "? " <> rest ->
          note.Note(..note, significance: note.Question, message: rest)
        Some(..), ", " <> rest ->
          note.Note(..note, significance: note.Answer, message: rest)
        None, "! " <> rest ->
          note.Note(..note, significance: note.FindingLead, message: rest)
        Some(..), ". " <> rest ->
          note.Note(..note, significance: note.FindingRejection, message: rest)
        Some(..), "!! " <> rest ->
          note.Note(
            ..note,
            significance: note.FindingComfirmation,
            message: rest,
          )
        _, _ -> note
      }

      #(
        Model(..model, current_note_draft: ""),
        event.emit(user_submitted_note_event, note.encode_note(note)),
      )
    }
    UserSwitchedToThread(new_thread_id:, parent_note:) -> #(
      Model(
        ..model,
        active_thread: Some(ActiveThread(
          current_thread_id: new_thread_id,
          parent_note:,
          prior_thread_id: get_current_thread_id(model),
          prior_thread: model.active_thread,
        )),
      ),
      effect.none(),
    )
    UserClosedThread -> #(
      Model(
        ..model,
        active_thread: model.active_thread
          |> option.map(fn(thread) { thread.prior_thread })
          |> option.flatten,
      ),
      effect.none(),
    )
  }
}

const component_style = "
:host {
  display: inline-block;
}

.new-thread-preview {
  opacity: 0;
}

.new-thread-preview:hover {
  opacity: 0.3;
}

.line-notes-list {
  position: absolute;
  z-index: 99;
  bottom: 1.4rem;
  left: 0rem;
  width: 30rem;
  text-wrap: wrap;
  background-color: white;
  border-radius: 6px;
  border: 1px solid black;
  visibility: hidden;
  opacity: 0;
}

.loc:hover + .line-notes-list,
.line-notes-list:hover,
.line-notes-list:focus-within {
  visibility: visible;
  opacity: 1;
}
"

fn view(model: Model) -> element.Element(Msg) {
  let current_thread_id = get_current_thread_id(model)
  let current_notes =
    dict.get(model.notes, current_thread_id) |> result.unwrap([])

  let inline_comment_preview =
    list.last(current_notes)
    |> result.map(fn(note) {
      html.span([attribute.class("loc faded code-extras")], [
        html.text(note.message |> string.slice(0, length: 30)),
      ])
    })
    |> result.unwrap(
      html.span([attribute.class("loc code-extras new-thread-preview")], [
        html.text("Start new thread"),
      ]),
    )

  html.div([attribute.class("line-notes-component-container")], [
    html.style([], component_style),
    inline_comment_preview,
    html.div([attribute.class("line-notes-list")], [
      case model.active_thread {
        Some(active_thread) ->
          element.fragment([
            html.button([event.on_click(UserClosedThread)], [
              html.text("Close Thread"),
            ]),
            html.br([]),
            html.text("Current Thread: "),
            html.text(active_thread.parent_note.message),
            html.hr([]),
          ])
        None -> element.fragment([])
      },
      element.fragment(
        list.map(current_notes, fn(note) {
          element.fragment([
            html.p([attribute.class("line-notes-list-item")], [
              html.text(note.message),
            ]),
            html.button(
              [event.on_click(UserSwitchedToThread(note.note_id, note))],
              [html.text("Switch to Thread")],
            ),
            html.hr([]),
          ])
        }),
      ),
      html.span([], [html.text("Add a new comment: ")]),
      html.input([
        event.on_input(UserWroteNote),
        effectx.on_ctrl_enter(UserSubmittedNote(parent_id: current_thread_id)),
        attribute.value(model.current_note_draft),
      ]),
    ]),
  ])
}
