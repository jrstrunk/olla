import given
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set
import gleam/string
import lib/eventx
import lib/lucide
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import o11a/components
import o11a/computed_note
import o11a/events
import o11a/note
import tempo/datetime
import tempo/instant

pub const name = components.line_discussion

pub fn register() {
  component()
  // |> lustre.register(name)
  // 
  // We could then call lustre register like so to register the component 
  // manually, but when we build this as a component with the lustre dev tools,
  // the produced javascript will automatically do this. If we ever build this
  // component in a different way, we'll need to register it manually.
}

pub fn component() {
  lustre.component(
    init,
    update,
    view,
    dict.from_list([
      #("line-discussion", fn(dy) {
        case computed_note.decode_structured_notes(dy) {
          Ok(notes) -> Ok(ServerUpdatedNotes(notes))
          Error(..) ->
            Error([
              dynamic.DecodeError("line-discussion", string.inspect(dy), []),
            ])
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
      line_tag: "",
      line_number_text: "",
      notes: dict.new(),
      current_note_draft: "",
      line_id: "",
      current_thread_id: "",
      current_thread_notes: [],
      active_thread: option.None,
      show_expanded_message_box: False,
      current_expanded_message_draft: None,
      expanded_messages: set.new(),
      editing_note: None,
    ),
    effect.none(),
  )
}

pub type Model {
  Model(
    user_name: String,
    line_number: Int,
    line_id: String,
    line_tag: String,
    line_number_text: String,
    notes: dict.Dict(String, List(computed_note.ComputedNote)),
    current_note_draft: String,
    current_thread_id: String,
    current_thread_notes: List(computed_note.ComputedNote),
    active_thread: Option(ActiveThread),
    show_expanded_message_box: Bool,
    current_expanded_message_draft: Option(String),
    expanded_messages: set.Set(String),
    editing_note: Option(computed_note.ComputedNote),
  )
}

pub type ActiveThread {
  ActiveThread(
    current_thread_id: String,
    parent_note: computed_note.ComputedNote,
    prior_thread_id: String,
    prior_thread: Option(ActiveThread),
  )
}

pub type Msg {
  ServerSetLineId(String)
  ServerSetLineNumber(Int)
  ServerUpdatedNotes(List(#(String, List(computed_note.ComputedNote))))
  UserWroteNote(String)
  UserSubmittedNote
  UserSwitchedToThread(
    new_thread_id: String,
    parent_note: computed_note.ComputedNote,
  )
  UserClosedThread
  UserToggledExpandedMessageBox(Bool)
  UserWroteExpandedMessage(String)
  UserToggledExpandedMessage(for_note_id: String)
  UserEnteredDiscussionPreview
  UserFocusedInput
  UserFocusedExpandedInput
  UserUnfocusedInput
  UserMaximizeThread
  UserEditedNote(computed_note.ComputedNote)
  UserCancelledEdit
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    ServerSetLineId(line_id) -> #(
      Model(
        ..model,
        line_id:,
        current_thread_id: line_id,
        current_thread_notes: dict.get(model.notes, line_id)
          |> result.unwrap([]),
      ),
      effect.none(),
    )
    ServerSetLineNumber(line_number) -> {
      let line_number_text = int.to_string(line_number)
      #(
        Model(
          ..model,
          line_number:,
          line_number_text:,
          line_tag: "L" <> line_number_text,
        ),
        effect.none(),
      )
    }
    ServerUpdatedNotes(notes) -> {
      let updated_notes = dict.from_list(notes)

      #(
        Model(
          ..model,
          notes: updated_notes,
          current_thread_notes: dict.get(updated_notes, model.current_thread_id)
            |> result.unwrap([]),
        ),
        effect.none(),
      )
    }
    UserWroteNote(draft) -> #(
      Model(..model, current_note_draft: draft),
      effect.none(),
    )
    UserSubmittedNote -> {
      use <- given.that(model.current_note_draft == "", return: fn() {
        #(model, effect.none())
      })

      let now = instant.now()
      let now_dt = now |> instant.as_utc_datetime

      let #(note_id, parent_id) = case model.editing_note {
        Some(note) -> #("edit", note.note_id)
        None -> #(
          model.user_name
            <> now
          |> instant.to_unique_int
          |> int.to_string
            <> now_dt
          |> datetime.to_unix_milli
          |> int.to_string,
          model.current_thread_id,
        )
      }

      let #(significance, message) =
        classify_message(
          model.current_note_draft,
          is_thread_open: option.is_some(model.active_thread),
        )

      let expanded_message = case
        model.current_expanded_message_draft |> option.map(string.trim)
      {
        Some("") -> None
        msg -> msg
      }

      let note =
        note.Note(
          note_id:,
          parent_id:,
          significance:,
          user_name: "user" <> int.random(100) |> int.to_string,
          message:,
          expanded_message:,
          time: now_dt,
          deleted: False,
        )

      echo "Submitting note"
      echo note

      #(
        Model(
          ..model,
          current_note_draft: "",
          current_expanded_message_draft: None,
          show_expanded_message_box: False,
          editing_note: None,
        ),
        event.emit(events.user_submitted_note, note.encode_note(note)),
      )
    }
    UserSwitchedToThread(new_thread_id:, parent_note:) -> #(
      Model(
        ..model,
        current_thread_id: new_thread_id,
        current_thread_notes: dict.get(model.notes, new_thread_id)
          |> result.unwrap([]),
        active_thread: Some(ActiveThread(
          current_thread_id: new_thread_id,
          parent_note:,
          prior_thread_id: model.current_thread_id,
          prior_thread: model.active_thread,
        )),
      ),
      effect.none(),
    )
    UserClosedThread -> {
      let new_active_thread =
        model.active_thread
        |> option.map(fn(thread) { thread.prior_thread })
        |> option.flatten

      let new_current_thread_id =
        option.map(new_active_thread, fn(thread) { thread.current_thread_id })
        |> option.unwrap(model.line_id)

      #(
        Model(
          ..model,
          current_thread_id: new_current_thread_id,
          current_thread_notes: dict.get(model.notes, new_current_thread_id)
            |> result.unwrap([]),
          active_thread: new_active_thread,
        ),
        effect.none(),
      )
    }
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
    UserEnteredDiscussionPreview -> #(
      model,
      event.emit(
        events.user_clicked_discussion_preview,
        json.object([
          #("line_number", json.int(model.line_number)),
          // 1 for line discussion
          #("discussion_lane", json.int(1)),
        ]),
      ),
    )
    UserFocusedInput -> #(
      model,
      event.emit(
        events.user_focused_input,
        json.object([
          #("line_number", json.int(model.line_number)),
          // 1 for line discussion
          #("discussion_lane", json.int(1)),
        ]),
      ),
    )
    // When the expanaded message box is focused, set the show_expanded_message_box
    // to true. This makes sure the model state is in sync with any external
    // calls to focus the expanded message box.
    UserFocusedExpandedInput -> #(
      Model(..model, show_expanded_message_box: True),
      event.emit(
        events.user_focused_input,
        json.object([
          #("line_number", json.int(model.line_number)),
          // 1 for line discussion
          #("discussion_lane", json.int(1)),
        ]),
      ),
    )
    UserUnfocusedInput -> #(
      model,
      event.emit(
        events.user_unfocused_input,
        json.object([
          #("line_number", json.int(model.line_number)),
          // 1 for line discussion
          #("discussion_lane", json.int(1)),
        ]),
      ),
    )
    UserMaximizeThread -> #(
      model,
      event.emit(
        events.user_maximized_thread,
        json.object([
          #("line_number", json.int(model.line_number)),
          // 1 for line discussion
          #("discussion_lane", json.int(1)),
        ]),
      ),
    )
    UserEditedNote(note) -> #(
      Model(
        ..model,
        current_note_draft: get_message_classification_prefix(note.significance)
          <> note.message,
        current_expanded_message_draft: note.expanded_message,
        editing_note: Some(note),
      ),
      effect.none(),
    )
    UserCancelledEdit -> #(
      Model(
        ..model,
        current_note_draft: "",
        current_expanded_message_draft: None,
        editing_note: None,
      ),
      effect.none(),
    )
  }
}

const component_style = "
:host {
  display: inline-block;
}

/* Delay the overlay transitions by 1ms so they are done last, and any 
  actions on them can be done first (like focusing the input) */

#expanded-message {
  visibility: hidden;
  opacity: 0;
  transition-property: opacity, visibility;
  transition-delay: 1ms, 1ms;
}

#expanded-message.show-exp,
#expanded-message:focus-within {
  visibility: visible;
  opacity: 1;
}

button.icon-button {
  background-color: var(--overlay-background-color);
  color: var(--text-color);
  border-radius: 4px;
  border: none;
  cursor: pointer;
}

button.icon-button:hover {
  background-color: var(--input-background-color);
}

button.icon-button svg {
  height: 1.25rem;
  width: 1.25rem;
}

input, textarea {
  background-color: var(--input-background-color);
  color: var(--text-color);
  border-radius: 6px;
}

input, textarea {
  border: 1px solid var(--input-border-color);
}

hr {
  border: 1px solid var(--comment-color);
}

.overlay {
  background-color: var(--overlay-background-color);
  border: 1px solid var(--input-border-color);
  border-radius: 6px;
}

.absolute {
  position: absolute;
}
"

fn view(model: Model) -> element.Element(Msg) {
  io.println("Rendering line discussion " <> model.line_tag)

  html.div([attribute.id("line-discussion-overlay")], [
    html.style([], component_style),
    html.div([attribute.class("overlay p-[.5rem]")], [
      case
        option.is_some(model.active_thread)
        || list.length(model.current_thread_notes) > 0
      {
        True ->
          html.div(
            [
              attribute.id("comment-list"),
              attribute.class(
                "flex flex-col-reverse overflow-auto max-h-[30rem] gap-[.5rem] mb-[.5rem]",
              ),
            ],
            [element.fragment(comments_view(model)), thread_header_view(model)],
          )
        False -> element.fragment([])
      },
      new_message_input_view(model),
    ]),
    expanded_message_view(model),
  ])
}

fn thread_header_view(model: Model) {
  case model.active_thread {
    Some(active_thread) ->
      html.div([], [
        html.div([attribute.class("flex justify-end width-full")], [
          html.button(
            [
              event.on_click(UserClosedThread),
              attribute.class(
                "icon-button flex gap-[.5rem] pl-[.5rem] pr-[.3rem] pt-[.3rem] pb-[.1rem] mb-[.25rem]",
              ),
            ],
            [html.text("Close Thread"), lucide.x([])],
          ),
        ]),
        html.text("Current Thread: "),
        html.text(active_thread.parent_note.message),
        case active_thread.parent_note.expanded_message {
          Some(expanded_message) ->
            html.div([attribute.class("mt-[.5rem]")], [
              html.p([], [html.text(expanded_message)]),
            ])
          None -> element.fragment([])
        },
        html.hr([attribute.class("mt-[.5rem]")]),
      ])
    None ->
      html.div(
        [attribute.class("flex items-center justify-between width-full")],
        [
          html.span([attribute.class("pt-[.1rem]")], [html.text(model.line_tag)]),
          html.button(
            [
              event.on_click(UserMaximizeThread),
              attribute.class("icon-button p-[.3rem] "),
            ],
            [lucide.maximize_2([])],
          ),
        ],
      )
  }
}

fn comments_view(model: Model) {
  list.map(model.current_thread_notes, fn(note) {
    html.div([attribute.class("line-discussion-item")], [
      // Comment header
      html.div([attribute.class("flex justify-between mb-[.2rem]")], [
        html.div([attribute.class("flex gap-[.5rem] items-start")], [
          html.p([], [html.text(note.user_name)]),
          significance_badge_view(note.significance),
        ]),
        html.div([attribute.class("flex gap-[.5rem]")], [
          html.button(
            [
              attribute.id("edit-message-button"),
              attribute.class("icon-button p-[.3rem]"),
              event.on_click(UserEditedNote(note)),
            ],
            [lucide.pencil([])],
          ),
          case note.expanded_message {
            Some(_) ->
              html.button(
                [
                  attribute.id("expand-message-button"),
                  attribute.class("icon-button p-[.3rem]"),
                  event.on_click(UserToggledExpandedMessage(note.note_id)),
                ],
                [lucide.list_collapse([])],
              )
            None -> element.fragment([])
          },
          case computed_note.is_significance_threadable(note.significance) {
            True ->
              html.button(
                [
                  attribute.id("switch-thread-button"),
                  attribute.class("icon-button p-[.3rem]"),
                  event.on_click(UserSwitchedToThread(note.note_id, note)),
                ],
                [lucide.messages_square([])],
              )
            False -> element.fragment([])
          },
        ]),
      ]),
      // Comment main text
      html.p([], [html.text(note.message)]),
      // Comment expanded text
      case set.contains(model.expanded_messages, note.note_id) {
        True ->
          html.div([attribute.class("mt-[.5rem]")], [
            html.p([], [html.text(note.expanded_message |> option.unwrap(""))]),
          ])
        False -> element.fragment([])
      },
      // Comment divider
      html.hr([attribute.class("mt-[.5rem]")]),
    ])
  })
}

fn significance_badge_view(sig: computed_note.ComputedNoteSignificance) {
  let badge_style =
    "input-border rounded-md text-[0.65rem] pb-[0.15rem] pt-1 px-[0.5rem]"

  case computed_note.significance_to_string(sig) {
    Some(significance) ->
      html.span([attribute.class(badge_style)], [html.text(significance)])
    None -> element.fragment([])
  }
}

fn new_message_input_view(model: Model) {
  html.div([attribute.class("flex justify-between items-center gap-[.35rem]")], [
    html.button(
      [
        attribute.id("toggle-expanded-message-button"),
        attribute.class("icon-button p-[.3rem]"),
        event.on_click(UserToggledExpandedMessageBox(
          !model.show_expanded_message_box,
        )),
      ],
      [lucide.pencil_ruler([])],
    ),
    case model.editing_note {
      Some(..) ->
        html.button(
          [
            attribute.id("cancel-message-edit-button"),
            attribute.class("icon-button p-[.3rem]"),
            event.on_click(UserCancelledEdit),
          ],
          [lucide.x([])],
        )
      None -> element.fragment([])
    },
    html.input([
      attribute.id("new-comment-input"),
      attribute.class(
        "inline-block w-full grow text-[0.9rem] pl-2 pb-[.2rem] p-[0.3rem] border-[none] border-t border-solid;",
      ),
      attribute.placeholder("Add a new comment"),
      event.on_input(UserWroteNote),
      event.on_focus(UserFocusedInput),
      event.on_blur(UserUnfocusedInput),
      eventx.on_ctrl_enter(UserSubmittedNote),
      attribute.value(model.current_note_draft),
    ]),
  ])
}

fn expanded_message_view(model: Model) {
  let expanded_message_style =
    "absolute overlay p-[.5rem] flex w-[100%] h-60 mt-2"

  let textarea_style = "grow text-[.95rem] resize-none p-[.3rem]"

  html.div(
    [
      attribute.id("expanded-message"),
      case model.show_expanded_message_box {
        True -> attribute.class(expanded_message_style <> " show-exp")
        False -> attribute.class(expanded_message_style)
      },
    ],
    [
      html.textarea(
        [
          attribute.id("expanded-message-box"),
          attribute.class(textarea_style),
          attribute.placeholder("Write an expanded message body"),
          event.on_input(UserWroteExpandedMessage),
          event.on_focus(UserFocusedExpandedInput),
          event.on_blur(UserUnfocusedInput),
          eventx.on_ctrl_enter(UserSubmittedNote),
        ],
        model.current_expanded_message_draft |> option.unwrap(""),
      ),
    ],
  )
}

fn classify_message(message, is_thread_open is_thread_open) {
  case is_thread_open {
    // Users can only start actionalble threads in the main thread
    False ->
      case message {
        "todo: " <> rest -> #(note.ToDo, rest)
        "q: " <> rest -> #(note.Question, rest)
        "question: " <> rest -> #(note.Question, rest)
        "finding: " <> rest -> #(note.FindingLead, rest)
        "dev: " <> rest -> #(note.DevelperQuestion, rest)
        "info: " <> rest -> #(note.Informational, rest)
        _ -> #(note.Comment, message)
      }
    // Users can only resolve actionalble threads in an open thread
    True ->
      case message {
        "done" -> #(note.ToDoCompletion, "done")
        "done: " <> rest -> #(note.ToDoCompletion, rest)
        "a: " <> rest -> #(note.Answer, rest)
        "answer: " <> rest -> #(note.Answer, rest)
        "reject: " <> rest -> #(note.FindingRejection, rest)
        "confirm: " <> rest -> #(note.FindingConfirmation, rest)
        "incorrect: " <> rest -> #(note.InformationalRejection, rest)
        "correct: " <> rest -> #(note.InformationalConfirmation, rest)
        _ -> #(note.Comment, message)
      }
  }
}

fn get_message_classification_prefix(
  significance: computed_note.ComputedNoteSignificance,
) {
  case significance {
    computed_note.Answer -> "a: "
    computed_note.AnsweredDeveloperQuestion -> "dev: "
    computed_note.AnsweredQuestion -> "q: "
    computed_note.Comment -> ""
    computed_note.CompleteToDo -> "todo: "
    computed_note.ConfirmedFinding -> "finding: "
    computed_note.FindingConfirmation -> "confirm: "
    computed_note.FindingRejection -> "reject: "
    computed_note.IncompleteToDo -> "todo: "
    computed_note.Informational -> "info: "
    computed_note.InformationalConfirmation -> "correct: "
    computed_note.InformationalRejection -> "incorrect: "
    computed_note.RejectedFinding -> "finding: "
    computed_note.RejectedInformational -> "info: "
    computed_note.ToDoCompletion -> "done: "
    computed_note.UnansweredDeveloperQuestion -> "dev: "
    computed_note.UnansweredQuestion -> "q: "
    computed_note.UnconfirmedFinding -> "finding: "
  }
}
