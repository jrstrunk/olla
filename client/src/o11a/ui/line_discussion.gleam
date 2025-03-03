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
import lib/eventx
import lib/lucide
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import o11a/components
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
        case note.decode_structured_notes(dy) {
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
      notes: dict.new(),
      keep_notes_open: False,
      current_note_draft: "",
      line_id: "",
      current_thread_id: "",
      current_thread_notes: [],
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
    current_thread_id: String,
    current_thread_notes: List(note.Note),
    active_thread: Option(ActiveThread),
    show_expanded_message_box: Bool,
    current_expanded_message_draft: Option(String),
    expanded_messages: set.Set(String),
  )
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
  UserSubmittedNote
  UserSwitchedToThread(new_thread_id: String, parent_note: note.Note)
  UserClosedThread
  UserToggledExpandedMessageBox(Bool)
  UserWroteExpandedMessage(String)
  UserToggledExpandedMessage(for_note_id: String)
  UserToggledKeepNotesOpen
  UserToggledCloseNotes
  UserFocusedDiscussion
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
    ServerSetLineNumber(line_number) -> #(
      Model(..model, line_number:),
      effect.none(),
    )
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
          parent_id: model.current_thread_id,
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
    UserFocusedDiscussion -> {
      #(
        model,
        effectx.focus_line_discussion_input(
          "L" <> int.to_string(model.line_number),
        ),
      )
    }
  }
}

const component_style = "
:host {
  display: inline-block;
}

.new-thread-preview {
  opacity: 0;
}

#line-discussion-overlay {
  visibility: hidden;
  opacity: 0;
}

/* When the new thread preview is hovered, delay the opacity transition to
  avoid triggering it as the mouse swipes by. */

.new-thread-preview:hover {
  opacity: 1;
  transition-property: opacity;
  transition-delay: 25ms;
}

.new-thread-preview:hover + #line-discussion-overlay,
.comment-preview:hover + #line-discussion-overlay {
  visibility: visible;
  opacity: 1;
  transition-property: opacity, visible;
  transition-delay: 25ms, 25ms;
}

/* When the new thread preview is focused, immediately show the overlay to
  provide snappy feedback. */

.new-thread-preview:focus,
.new-thread-preview:has(+ #line-discussion-overlay:hover),
.new-thread-preview:has(+ #line-discussion-overlay:focus-within) {
  opacity: 1;
}

.new-thread-preview:focus + #line-discussion-overlay,
.comment-preview:focus + #line-discussion-overlay,
#line-discussion-overlay:hover,
#line-discussion-overlay:focus-within {
  visibility: visible;
  opacity: 1;
}

button.icon-button {
  background-color: var(--overlay-background-color);
  color: var(--text-color);
  border-radius: 4px;
  border: none;
  cursor: pointer;
  padding: 0.3rem;
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
  border: 1px solid var(--comment-color)
  margin-top: 0.5rem;
}

.overlay {
  position: absolute;
  background-color: var(--overlay-background-color);
  border: 1px solid var(--input-border-color);
  border-radius: 6px;
}
"

fn view(model: Model) -> element.Element(Msg) {
  html.div(
    [
      attribute.id("line-discussion-container"),
      attribute.class("relative font-code"),
    ],
    [
      html.style([], component_style),
      inline_comment_preview_view(model),
      discussion_overlay_view(model),
    ],
  )
}

fn discussion_overlay_view(model: Model) {
  let comment_list_style =
    "flex flex-col-reverse p-[.5rem] overflow-auto max-h-[30rem] gap-[.5rem]"

  html.div(
    [
      attribute.id("line-discussion-overlay"),
      attribute.class(
        "overlay w-[30rem] invisible not-italic text-wrap select-text left-[-.3rem] bottom-[1.4rem]",
      ),
      event.on_click(UserToggledKeepNotesOpen),
    ],
    [
      html.div(
        [attribute.id("comment-list"), attribute.class(comment_list_style)],
        [
          new_message_input_view(model),
          element.fragment(comments_view(model)),
          thread_header_view(model),
        ],
      ),
      case model.show_expanded_message_box {
        True -> expanded_message_view(model)
        False -> element.fragment([])
      },
    ],
  )
}

fn thread_header_view(model: Model) {
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
            html.div([attribute.class("mt-[.5rem]")], [
              html.p([], [html.text(expanded_message)]),
            ])
          None -> element.fragment([])
        },
        html.hr([]),
      ])
    None -> element.fragment([])
  }
}

fn comments_view(model: Model) {
  list.map(model.current_thread_notes, fn(note) {
    html.div([attribute.class("line-discussion-item")], [
      // Comment header
      html.div([attribute.class("flex justify-between mb-[.2rem]")], [
        html.div([attribute.class("flex gap-[.5rem] items-start")], [
          html.p([], [html.text(note.user_name)]),
          significance_badge_view(model, note),
        ]),
        html.div([attribute.class("flex gap-[.5rem]")], [
          case note.expanded_message {
            Some(_) ->
              html.button(
                [
                  attribute.id("expand-message-button"),
                  attribute.class("icon-button"),
                  event.on_click(UserToggledExpandedMessage(note.note_id)),
                ],
                [lucide.list_collapse([])],
              )
            None -> element.fragment([])
          },
          html.button(
            [
              attribute.id("switch-thread-button"),
              attribute.class("icon-button"),
              event.on_click(UserSwitchedToThread(note.note_id, note)),
            ],
            [lucide.messages_square([])],
          ),
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
      html.hr([]),
    ])
  })
}

fn new_message_input_view(model: Model) {
  html.div([attribute.class("flex justify-between items-center gap-[.35rem]")], [
    html.button(
      [
        attribute.id("toggle-expanded-message-button"),
        attribute.class("icon-button"),
        event.on_click(UserToggledExpandedMessageBox(
          !model.show_expanded_message_box,
        )),
      ],
      [lucide.pencil_ruler([])],
    ),
    html.input([
      attribute.id("new-comment-input"),
      attribute.class(
        "inline-block w-full grow text-[0.9rem] pl-2 pb-[.2rem] p-[0.3rem] border-[none] border-t border-solid;",
      ),
      attribute.placeholder("Add a new comment"),
      event.on_input(UserWroteNote),
      eventx.on_ctrl_enter(UserSubmittedNote),
      attribute.value(model.current_note_draft),
    ]),
  ])
}

fn inline_comment_preview_view(model: Model) {
  dict.get(model.notes, model.line_id)
  |> result.try(list.first)
  |> result.map(fn(note) {
    html.span(
      [
        attribute.class("select-none italic comment font-code fade-in"),
        attribute.class("comment-preview"),
        attribute.attribute("tabindex", "0"),
        event.on_click(UserToggledKeepNotesOpen),
        eventx.on_e(UserFocusedDiscussion),
        attribute.style([
          #("animation-delay", int.to_string(model.line_number * 4) <> "ms"),
        ]),
      ],
      [
        html.text(case string.length(note.message) > 40 {
          True -> note.message |> string.slice(0, length: 37) <> "..."
          False -> note.message |> string.slice(0, length: 40)
        }),
      ],
    )
  })
  |> result.unwrap(
    html.span(
      [
        attribute.class("select-none italic comment"),
        attribute.class("new-thread-preview"),
        attribute.attribute("tabindex", "0"),
        event.on_click(UserToggledKeepNotesOpen),
        eventx.on_e(UserFocusedDiscussion),
      ],
      [html.text("Start new thread")],
    ),
  )
}

fn significance_badge_view(model: Model, note: note.Note) {
  let badge_style = "input-border rounded text-[0.65rem] pb-[0.15rem] p-1"

  case
    note.significance_to_string(
      note.significance,
      dict.get(model.notes, note.note_id) |> result.unwrap([]),
    )
  {
    Some(significance) ->
      html.span([attribute.class(badge_style)], [html.text(significance)])
    None -> element.fragment([])
  }
}

fn expanded_message_view(model: Model) {
  let expanded_message_style = "overlay p-[.5rem] flex w-[140%] h-40 z-[3] mt-2"

  let textarea_style = "grow text-[.95rem] resize-none p-[.3rem]"

  html.div([attribute.class(expanded_message_style)], [
    html.textarea(
      [
        attribute.id("expanded-message-box"),
        attribute.class(textarea_style),
        attribute.placeholder("Write an expanded message body"),
        event.on_input(UserWroteExpandedMessage),
        eventx.on_ctrl_enter(UserSubmittedNote),
        attribute.value(
          model.current_expanded_message_draft |> option.unwrap(""),
        ),
      ],
      "Write an expanded message body ig",
    ),
  ])
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
