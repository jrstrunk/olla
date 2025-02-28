import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set
import gleam/string
import lib/effectx
import lib/lucide
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
      user_name: "user01",
      notes: dict.new(),
      current_note_draft: "",
      line_id: "",
      active_thread: option.None,
      show_expanded_message_box: False,
      current_expanded_message_draft: None,
    ),
    effect.none(),
  )
}

pub type Model {
  Model(
    user_name: String,
    line_id: String,
    notes: dict.Dict(String, List(note.Note)),
    current_note_draft: String,
    active_thread: Option(ActiveThread),
    show_expanded_message_box: Bool,
    current_expanded_message_draft: Option(String),
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
  UserToggledExpandedMessageBox(Bool)
  UserWroteExpandedMessage(String)
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

      // Microseconds aren't available in the browser :(
      let note_id =
        model.user_name <> now |> datetime.to_unix_milli |> int.to_string

      let #(significance, message) =
        classify_message(
          model.current_note_draft,
          is_thread_open: option.is_some(model.active_thread),
        )

      let note =
        note.Note(
          note_id:,
          parent_id:,
          significance:,
          user_name: model.user_name,
          message:,
          expanded_message: model.current_expanded_message_draft,
          time: now,
          edited: False,
        )

      #(
        Model(
          ..model,
          current_note_draft: "",
          current_expanded_message_draft: None,
          show_expanded_message_box: False,
        ),
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
    UserToggledExpandedMessageBox(show_expanded_message_box) -> #(
      Model(..model, show_expanded_message_box:),
      effect.none(),
    )
    UserWroteExpandedMessage(expanded_message) -> #(
      Model(..model, current_expanded_message_draft: Some(expanded_message)),
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
  opacity: 0.35;
}

.line-notes-list {
  position: absolute;
  z-index: 99;
  bottom: 1.4rem;
  left: 0rem;
  width: 30rem;
  text-wrap: wrap;
  background-color: var(--overlay-background-color);;
  border-radius: 6px;
  border: var(--input-border-color) solid black;
  visibility: visible;
  opacity: 1;
  font-style: normal;
  user-select: text;
  padding: 0.5rem;
}

.loc:hover + .line-notes-list,
.line-notes-list:hover,
.line-notes-list:focus-within {
  visibility: visible;
  opacity: 1;
}

button, input {
  background-color: var(--input-background-color);
  color: var(--text-color);
  border-color: var(--input-border-color);
}

.line-notes-item-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 0.2rem;
}

.line-notes-item-header-meta {
  display: flex;
  gap: 0.5rem;
  align-items: start;
}

.line-notes-list p {
  margin: 0;
}

.significance-badge {
  border-radius: 4px;
  padding: 0.25rem;
  padding-bottom: 0.15rem;
  font-size: 0.65rem;
  border: 1px solid var(--input-border-color);
}

.thread-switch-button {
  background-color: var(--overlay-background-color);
  color: var(--text-color);
  border: none;
  border-radius: 4px;
  margin-left: 0.5rem;
  padding-top: 0.2rem;
}

.thread-switch-button:hover {
  background-color: var(--input-background-color);
}

.thread-switch-button svg {
  height: 1.25rem;
  width: 1.25rem;
}

.line-notes-input-container {
  display: flex;
  gap: 0.35rem;
  align-items: center;
  justify-content: space-between;
}

.new-comment-button {
  background-color: var(--overlay-background-color);
  color: var(--text-color);
  border: none;
  border-radius: 4px;
  padding-top: 0.25rem;
}

.new-comment-button:hover {
  background-color: var(--input-background-color);
}

.new-comment-button svg {
  height: 1.25rem;
  width: 1.25rem;
}

.new-comment-input {
  display: inline-block;
  width: 100%;
  border: none;
  border-top: 1px solid var(--input-border-color);
  border-radius: 4px;
  flex-grow: 1;
  padding: 0.3rem;
  padding-left: .5rem;
  font-size: 0.95rem;
}

.expanded-message-box {
  position: absolute;
  display: flex;
  width: 140%;
  left: 0;
  padding: .5rem;
  background-color: var(--overlay-background-color);
  border-radius: 4px;
  border: 1px solid var(--input-border-color);
  height: 10rem;
  margin-top: 1rem;
}

.expanded-message-box textarea {
  flex-grow: 1;
  background-color: var(--input-background-color);
  color: var(--text-color);
  border: 1px solid var(--input-border-color);
  border-radius: 4px;
  padding: 0.3rem;
  font-size: 0.95rem;
}
"

fn view(model: Model) -> element.Element(Msg) {
  let current_thread_id = get_current_thread_id(model)
  let current_notes =
    dict.get(model.notes, current_thread_id) |> result.unwrap([])

  let inline_comment_preview =
    dict.get(model.notes, model.line_id)
    |> result.try(list.last)
    |> result.map(fn(note) {
      html.span([attribute.class("loc faded code-extras")], [
        html.text(case string.length(note.message) > 40 {
          True -> note.message |> string.slice(0, length: 37) <> "..."
          False -> note.message |> string.slice(0, length: 40)
        }),
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
          html.div([attribute.class("line-notes-item")], [
            html.div([attribute.class("line-notes-item-header")], [
              html.div([attribute.class("line-notes-item-header-meta")], [
                html.p([], [html.text(note.user_name)]),
                significance_badge_view(model, note),
              ]),
              html.button(
                [
                  attribute.class("thread-switch-button"),
                  event.on_click(UserSwitchedToThread(note.note_id, note)),
                ],
                [lucide.messages_square([])],
              ),
            ]),
            html.p([], [html.text(note.message)]),
            case note.expanded_message {
              Some(expanded_message) ->
                html.p([], [html.text(expanded_message)])
              None -> element.fragment([])
            },
            html.hr([]),
          ])
        }),
      ),
      html.div([attribute.class("line-notes-input-container")], [
        html.button(
          [
            attribute.class("new-comment-button"),
            event.on_click(UserToggledExpandedMessageBox(
              !model.show_expanded_message_box,
            )),
          ],
          [lucide.pencil_ruler([])],
        ),
        html.input([
          attribute.class("new-comment-input"),
          attribute.placeholder("Add a new comment"),
          event.on_input(UserWroteNote),
          effectx.on_ctrl_enter(UserSubmittedNote(parent_id: current_thread_id)),
          attribute.value(model.current_note_draft),
        ]),
      ]),
      case model.show_expanded_message_box {
        True ->
          html.div([attribute.class("expanded-message-box")], [
            html.textarea(
              [
                attribute.class("expanded-comment-input"),
                attribute.placeholder("Write an expanded message body"),
                event.on_input(UserWroteExpandedMessage),
                effectx.on_ctrl_enter(UserSubmittedNote(
                  parent_id: current_thread_id,
                )),
                attribute.value(
                  model.current_expanded_message_draft |> option.unwrap(""),
                ),
              ],
              "Write an expanded message body ig",
            ),
          ])
        False -> element.fragment([])
      },
    ]),
  ])
}

fn significance_badge_view(model: Model, note: note.Note) {
  case
    note.significance_to_string(
      note.significance,
      dict.get(model.notes, note.note_id) |> result.unwrap([]),
    )
  {
    Some(significance) ->
      html.span([attribute.class("significance-badge")], [
        html.text(significance),
      ])
    None -> element.fragment([])
  }
}

fn classify_message(message, is_thread_open is_thread_open) {
  case is_thread_open {
    // Users can only start actionalble threads in the main thread
    False ->
      case message {
        "todo " <> rest -> #(note.ToDo, rest)
        "? " <> rest -> #(note.Question, rest)
        "! " <> rest -> #(note.FindingLead, rest)
        "@dev " <> rest -> #(note.DevelperQuestion, rest)
        _ -> #(note.Comment, message)
      }
    // Users can only resolve actionalble threads in an open thread
    True ->
      case message {
        "done " <> rest -> #(note.ToDoDone, rest)
        ": " <> rest -> #(note.Answer, rest)
        ". " <> rest -> #(note.FindingRejection, rest)
        "!! " <> rest -> #(note.FindingComfirmation, rest)
        _ -> #(note.Comment, message)
      }
  }
}
