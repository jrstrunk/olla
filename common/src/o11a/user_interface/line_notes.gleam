import given
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
          Error(..) ->
            Error([dynamic.DecodeError("line-notes", string.inspect(dy), [])])
        }
      }),
      #("line-id", fn(dy) {
        case decode.run(dy, decode.string) {
          Ok(line_id) -> Ok(ServerSetLineId(line_id))
          Error(..) ->
            Error([dynamic.DecodeError("line-id", string.inspect(dy), [])])
        }
      }),
      #("line-number", fn(dy) {
        case decode.run(dy, decode.string) {
          Ok(line_number) ->
            case int.parse(line_number) {
              Ok(line_number) -> Ok(ServerSetLineNumber(line_number))
              Error(Nil) ->
                Error([dynamic.DecodeError("line-number", line_number, [])])
            }
          Error(..) ->
            Error([dynamic.DecodeError("line-number", string.inspect(dy), [])])
        }
      }),
    ]),
  )
}

fn init(_) -> #(Model, effect.Effect(Msg)) {
  #(
    Model(
      user_name: "guest",
      line_number: 0,
      notes: dict.new(),
      keep_notes_open: False,
      current_note_draft: "",
      line_id: "",
      active_thread: option.None,
      show_expanded_message_box: False,
      current_expanded_message_draft: None,
      expanded_messages: set.new(),
    ),
    effect.none(),
  )
}

pub type Model {
  Model(
    user_name: String,
    line_number: Int,
    line_id: String,
    keep_notes_open: Bool,
    notes: dict.Dict(String, List(note.Note)),
    current_note_draft: String,
    active_thread: Option(ActiveThread),
    show_expanded_message_box: Bool,
    current_expanded_message_draft: Option(String),
    expanded_messages: set.Set(String),
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
  ServerSetLineNumber(Int)
  ServerUpdatedNotes(List(#(String, List(note.Note))))
  UserWroteNote(String)
  UserSubmittedNote(parent_id: String)
  UserSwitchedToThread(new_thread_id: String, parent_note: note.Note)
  UserClosedThread
  UserToggledExpandedMessageBox(Bool)
  UserWroteExpandedMessage(String)
  UserToggledExpandedMessage(for_note_id: String)
  UserToggledKeepNotesOpen
  UserToggledCloseNotes
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    ServerSetLineId(line_id) -> #(Model(..model, line_id:), effect.none())
    ServerSetLineNumber(line_number) -> #(
      Model(..model, line_number:),
      effect.none(),
    )
    ServerUpdatedNotes(notes) -> #(
      Model(..model, notes: dict.from_list(notes)),
      effect.none(),
    )
    UserWroteNote(draft) -> #(
      Model(..model, current_note_draft: draft),
      effect.none(),
    )
    UserSubmittedNote(parent_id:) -> {
      use <- given.that(model.current_note_draft == "", return: fn() {
        #(model, effect.none())
      })

      let now = instant.now() |> instant.as_utc_datetime

      // Microseconds aren't available in the browser so just get milli :(
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
          user_name: "user" <> int.random(100) |> int.to_string,
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
    UserToggledExpandedMessage(for_note_id) ->
      case set.contains(model.expanded_messages, for_note_id) {
        True -> #(
          Model(
            ..model,
            expanded_messages: set.delete(model.expanded_messages, for_note_id),
          ),
          effect.none(),
        )
        False -> #(
          Model(
            ..model,
            expanded_messages: set.insert(model.expanded_messages, for_note_id),
          ),
          effect.none(),
        )
      }
    // Currently these do not do anything, but they could be used to
    // implement better note viewing
    UserToggledKeepNotesOpen -> #(
      Model(..model, keep_notes_open: True),
      effect.none(),
    )
    UserToggledCloseNotes -> #(
      Model(..model, keep_notes_open: False),
      effect.none(),
    )
  }
}

const component_style = "
/* Duplicated from the main styles.css bleh */
.code-extras {
  -webkit-touch-callout: none;
  -webkit-user-select: none;
  -khtml-user-select: none;
  -moz-user-select: none;
  -ms-user-select: none;
  user-select: none;
  font-style: italic;
  color: var(--comment-color);
}

:host {
  display: inline-block;
}

.line-notes-component-container {
  position: relative;
}

.new-thread-preview {
  opacity: 0;
}

.new-thread-preview:hover,
.line-notes-component-container:focus .new-thread-preview {
  opacity: 1;
}

.line-notes-list {
  position: absolute;
  bottom: 1.4rem;
  left: 0rem;
  width: 30rem;
  text-wrap: wrap;
  background-color: var(--overlay-background-color);;
  border-radius: 6px;
  border: var(--input-border-color) solid black;
  visibility: hidden;
  font-style: normal;
  user-select: text;
}

.line-notes-list-column {
  display: flex;
  flex-direction: column-reverse;
  padding: 0.5rem;
  max-height: 30rem;
  overflow: auto;
}

.loc:hover + .line-notes-list,
.line-notes-list:hover,
.line-notes-list:focus-within,
.line-notes-component-container:focus .line-notes-list,
.line-notes-component-container:hover .line-notes-list {
  visibility: visible;
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

.line-notes-item-header-actions {
  display: flex;
  gap: 0.5rem;
}

button {
  background-color: var(--overlay-background-color);
  color: var(--text-color);
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

button:hover {
  background-color: var(--input-background-color);
}

button svg {
  height: 1.25rem;
  width: 1.25rem;
}

.thread-switch-button, .expand-message-button {
  padding-top: 0.2rem;
}

.expanded-note-message {
  margin-top: 1rem;
}

.line-notes-input-container {
  display: flex;
  gap: 0.35rem;
  align-items: center;
  justify-content: space-between;
}

.new-comment-button {
  padding-top: 0.25rem;
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
  border-radius: 6px;
  border: 1px solid var(--input-border-color);
  height: 10rem;
  margin-top: 0.5rem;
  z-index: 3;
}

.expanded-message-box textarea {
  flex-grow: 1;
  background-color: var(--input-background-color);
  color: var(--text-color);
  border: 1px solid var(--input-border-color);
  border-radius: 4px;
  padding: 0.3rem;
  font-size: 0.95rem;
  resize: none;
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
      html.span([attribute.class("code-extras fade-in")], [
        html.text(case string.length(note.message) > 40 {
          True -> note.message |> string.slice(0, length: 37) <> "..."
          False -> note.message |> string.slice(0, length: 40)
        }),
      ])
    })
    |> result.unwrap(
      html.span([attribute.class("code-extras new-thread-preview")], [
        html.text("Start new thread"),
      ]),
    )

  html.div(
    [
      attribute.class("line-notes-component-container"),
      attribute.attribute("tabindex", "0"),
      event.on_click(UserToggledKeepNotesOpen),
    ],
    [
      html.style([], component_style),
      inline_comment_preview,
      html.div(
        [
          attribute.class("line-notes-list"),
          event.on_click(UserToggledKeepNotesOpen),
        ],
        [
          html.div([attribute.class("line-notes-list-column")], [
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
                effectx.on_ctrl_enter(UserSubmittedNote(
                  parent_id: current_thread_id,
                )),
                attribute.value(model.current_note_draft),
              ]),
            ]),
            element.fragment(
              list.map(current_notes, fn(note) {
                html.div([attribute.class("line-notes-item")], [
                  html.div([attribute.class("line-notes-item-header")], [
                    html.div([attribute.class("line-notes-item-header-meta")], [
                      html.p([], [html.text(note.user_name)]),
                      significance_badge_view(model, note),
                    ]),
                    html.div(
                      [attribute.class("line-notes-item-header-actions")],
                      [
                        case note.expanded_message {
                          Some(_) ->
                            html.button(
                              [
                                attribute.class("expand-message-button"),
                                event.on_click(UserToggledExpandedMessage(
                                  note.note_id,
                                )),
                              ],
                              [lucide.list_collapse([])],
                            )
                          None -> element.fragment([])
                        },
                        html.button(
                          [
                            attribute.class("thread-switch-button"),
                            event.on_click(UserSwitchedToThread(
                              note.note_id,
                              note,
                            )),
                          ],
                          [lucide.messages_square([])],
                        ),
                      ],
                    ),
                  ]),
                  html.p([], [html.text(note.message)]),
                  case set.contains(model.expanded_messages, note.note_id) {
                    True ->
                      html.div([attribute.class("expanded-note-message")], [
                        html.p([], [
                          html.text(note.expanded_message |> option.unwrap("")),
                        ]),
                      ])
                    False -> element.fragment([])
                  },
                  html.hr([]),
                ])
              }),
            ),
            case model.active_thread {
              Some(active_thread) ->
                html.div([], [
                  html.button([event.on_click(UserClosedThread)], [
                    html.text("Close Thread"),
                  ]),
                  html.br([]),
                  html.text("Current Thread: "),
                  html.text(active_thread.parent_note.message),
                  case active_thread.parent_note.expanded_message {
                    Some(expanded_message) ->
                      html.div([attribute.class("expanded-note-message")], [
                        html.p([], [html.text(expanded_message)]),
                      ])
                    None -> element.fragment([])
                  },
                  html.hr([]),
                ])
              None -> element.fragment([])
            },
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
        ],
      ),
    ],
  )
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
        "!! " <> rest -> #(note.FindingConfirmation, rest)
        _ -> #(note.Comment, message)
      }
  }
}
