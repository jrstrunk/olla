import given
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/string
import lib/eventx
import lib/lucide
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event
import o11a/computed_note
import o11a/declaration
import o11a/note

pub type Model {
  Model(
    is_reference: Bool,
    show_reference_discussion: Bool,
    user_name: String,
    line_number: Int,
    column_number: Int,
    topic_id: String,
    topic_title: String,
    current_note_draft: String,
    current_thread_id: String,
    active_thread: option.Option(ActiveThread),
    show_expanded_message_box: Bool,
    current_expanded_message_draft: option.Option(String),
    expanded_messages: set.Set(String),
    editing_note: option.Option(computed_note.ComputedNote),
    declarations: List(declaration.Declaration),
  )
}

pub type ActiveThread {
  ActiveThread(
    current_thread_id: String,
    parent_note: computed_note.ComputedNote,
    prior_thread_id: String,
    prior_thread: option.Option(ActiveThread),
  )
}

pub fn init(
  line_number line_number,
  column_number column_number,
  topic_id topic_id,
  topic_title topic_title,
  is_reference is_reference,
  declarations declarations,
) {
  Model(
    is_reference:,
    show_reference_discussion: False,
    user_name: "guest",
    line_number:,
    column_number:,
    topic_id:,
    topic_title:,
    current_note_draft: "",
    current_thread_id: topic_id,
    active_thread: option.None,
    show_expanded_message_box: False,
    current_expanded_message_draft: option.None,
    expanded_messages: set.new(),
    editing_note: option.None,
    declarations:,
  )
}

pub type Msg {
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
  UserFocusedInput
  UserFocusedExpandedInput
  UserUnfocusedInput
  UserMaximizeThread
  UserEditedNote(Result(computed_note.ComputedNote, Nil))
  UserCancelledEdit
  UserToggledReferenceDiscussion
}

pub type Effect {
  SubmitNote(note: note.NoteSubmission, topic_id: String)
  FocusDiscussionInput(line_number: Int, column_number: Int)
  FocusExpandedDiscussionInput(line_number: Int, column_number: Int)
  UnfocusDiscussionInput(line_number: Int, column_number: Int)
  MaximizeDiscussion(line_number: Int, column_number: Int)
  None
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    UserWroteNote(draft) -> {
      #(Model(..model, current_note_draft: draft), None)
    }
    UserSubmittedNote -> {
      echo "Submitting note! "
      <> model.current_note_draft
      <> " "
      <> model.topic_id

      let current_note_draft = model.current_note_draft |> string.trim

      let #(significance, message) =
        note.classify_message(
          current_note_draft,
          is_thread_open: option.is_some(model.active_thread),
        )

      use <- given.that(message == "", return: fn() { #(model, None) })

      let #(modifier, parent_id) = case model.editing_note {
        option.Some(note) -> #(note.Edit, note.note_id)
        option.None -> #(note.None, model.current_thread_id)
      }

      let expanded_message = case
        model.current_expanded_message_draft |> option.map(string.trim)
      {
        option.Some("") -> option.None
        msg -> msg
      }

      let referenced_topic_ids =
        declaration.get_references(message, with: model.declarations)
        |> list.append(case expanded_message {
          option.Some(expanded_message) ->
            declaration.get_references(
              expanded_message,
              with: model.declarations,
            )
          option.None -> []
        })
        |> list.unique

      let prior_referenced_topic_ids =
        option.map(model.editing_note, fn(note) { note.referenced_topic_ids })

      let note =
        note.NoteSubmission(
          parent_id:,
          significance:,
          user_id: "user" <> int.random(100) |> int.to_string,
          message:,
          expanded_message:,
          modifier:,
          referenced_topic_ids:,
          prior_referenced_topic_ids:,
        )

      #(
        Model(
          ..model,
          current_note_draft: "",
          current_expanded_message_draft: option.None,
          show_expanded_message_box: False,
          editing_note: option.None,
        ),
        SubmitNote(note:, topic_id: model.topic_id),
      )
    }
    UserSwitchedToThread(new_thread_id:, parent_note:) -> #(
      Model(
        ..model,
        current_thread_id: new_thread_id,
        active_thread: option.Some(ActiveThread(
          current_thread_id: new_thread_id,
          parent_note:,
          prior_thread_id: model.current_thread_id,
          prior_thread: model.active_thread,
        )),
      ),
      None,
    )
    UserClosedThread -> {
      let new_active_thread =
        model.active_thread
        |> option.map(fn(thread) { thread.prior_thread })
        |> option.flatten

      let new_current_thread_id =
        option.map(new_active_thread, fn(thread) { thread.current_thread_id })
        |> option.unwrap(model.topic_id)

      #(
        Model(
          ..model,
          current_thread_id: new_current_thread_id,
          active_thread: new_active_thread,
        ),
        None,
      )
    }
    UserToggledExpandedMessageBox(show_expanded_message_box) -> #(
      Model(..model, show_expanded_message_box:),
      None,
    )
    UserWroteExpandedMessage(expanded_message) -> #(
      Model(
        ..model,
        current_expanded_message_draft: option.Some(expanded_message),
      ),
      None,
    )
    UserToggledExpandedMessage(for_note_id) ->
      case set.contains(model.expanded_messages, for_note_id) {
        True -> #(
          Model(
            ..model,
            expanded_messages: set.delete(model.expanded_messages, for_note_id),
          ),
          None,
        )
        False -> #(
          Model(
            ..model,
            expanded_messages: set.insert(model.expanded_messages, for_note_id),
          ),
          None,
        )
      }
    UserFocusedInput -> #(
      model,
      FocusDiscussionInput(
        line_number: model.line_number,
        column_number: model.column_number,
      ),
    )
    // When the expanaded message box is focused, set the show_expanded_message_box
    // to true. This makes sure the model state is in sync with any external
    // calls to focus the expanded message box.
    UserFocusedExpandedInput -> #(
      Model(..model, show_expanded_message_box: True),
      FocusExpandedDiscussionInput(
        line_number: model.line_number,
        column_number: model.column_number,
      ),
    )
    UserUnfocusedInput -> #(
      model,
      UnfocusDiscussionInput(
        line_number: model.line_number,
        column_number: model.column_number,
      ),
    )
    UserMaximizeThread -> #(
      model,
      MaximizeDiscussion(
        line_number: model.line_number,
        column_number: model.column_number,
      ),
    )
    UserEditedNote(note) ->
      case note {
        Ok(note) -> #(
          Model(
            ..model,
            current_note_draft: get_message_classification_prefix(
                note.significance,
              )
              <> note.message,
            current_expanded_message_draft: note.expanded_message,
            editing_note: option.Some(note),
            show_expanded_message_box: case note.expanded_message {
              option.Some(..) -> True
              option.None -> False
            },
          ),
          None,
        )
        Error(Nil) -> #(model, None)
      }
    UserCancelledEdit -> #(
      Model(
        ..model,
        current_note_draft: "",
        current_expanded_message_draft: option.None,
        editing_note: option.None,
        show_expanded_message_box: False,
      ),
      None,
    )
    UserToggledReferenceDiscussion -> #(
      Model(
        ..model,
        show_reference_discussion: !model.show_reference_discussion,
      ),
      None,
    )
  }
}

pub fn overlay_view(
  model: Model,
  notes: dict.Dict(String, List(computed_note.ComputedNote)),
  references,
) {
  let current_thread_notes =
    dict.get(notes, model.current_thread_id)
    |> result.unwrap([])

  let references =
    dict.get(references, model.topic_id)
    |> result.unwrap([])

  html.div(
    [
      attribute.class(
        "absolute z-[3] w-[30rem] not-italic text-wrap select-text text left-[-.3rem]",
      ),
      // The line discussion component is too close to the edge of the
      // screen, so we want to show it below the line
      case model.line_number < 30 {
        True -> attribute.class("top-[1.75rem]")
        False -> attribute.class("bottom-[1.75rem]")
      },
    ],
    [
      case model.is_reference && !model.show_reference_discussion {
        True ->
          html.div([attribute.class("overlay p-[.5rem]")], [
            reference_header_view(model, current_thread_notes),
          ])
        False ->
          element.fragment([
            html.div([attribute.class("overlay p-[.5rem]")], [
              thread_header_view(model, references),
              case
                option.is_some(model.active_thread)
                || list.length(current_thread_notes) > 0
              {
                True -> comments_view(model, current_thread_notes)
                False -> element.fragment([])
              },
              new_message_input_view(model, current_thread_notes),
            ]),
            expanded_message_view(model),
          ])
      },
    ],
  )
}

pub fn panel_view(model: Model, notes, references) {
  let current_thread_notes =
    dict.get(notes, model.current_thread_id)
    |> result.unwrap([])

  html.div([attribute.style("padding", ".5rem")], [
    case model.is_reference {
      True -> reference_header_view(model, current_thread_notes)
      False -> element.fragment([])
    },
    thread_header_view(model, references),
    case
      option.is_some(model.active_thread)
      || list.length(current_thread_notes) > 0
    {
      True -> comments_view(model, current_thread_notes)
      False -> element.fragment([])
    },
    new_message_input_view(model, current_thread_notes),
    case model.show_expanded_message_box {
      True -> expand_message_input_view(model)
      False -> element.fragment([])
    },
  ])
}

fn reference_header_view(model: Model, current_thread_notes) {
  element.fragment([
    html.div(
      [
        attribute.class(
          "flex items-start justify-between width-full mb-[.5rem]",
        ),
      ],
      [
        html.span([attribute.class("pt-[.1rem]")], [
          html.a([attribute.href("/" <> model.topic_id)], [
            element.unsafe_raw_html(
              "topic-title",
              "span",
              [],
              model.topic_title,
            ),
          ]),
        ]),
        html.button(
          [
            event.on_click(UserToggledReferenceDiscussion),
            attribute.class("icon-button p-[.3rem]"),
          ],
          [lucide.messages_square([])],
        ),
      ],
    ),
    html.div(
      [attribute.class("flex flex-col overflow-auto max-h-[30rem] gap-[.5rem]")],
      list.filter_map(
        current_thread_notes,
        fn(note: computed_note.ComputedNote) {
          case note.significance == computed_note.Informational {
            True ->
              Ok(
                html.p([], [
                  html.text(
                    note.message
                    <> case option.is_some(note.expanded_message) {
                      True -> "^"
                      False -> ""
                    },
                  ),
                ]),
              )
            False -> Error(Nil)
          }
        },
      ),
    ),
  ])
}

fn thread_header_view(model: Model, references) {
  case model.active_thread {
    option.Some(active_thread) ->
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
          option.Some(expanded_message) ->
            html.div([attribute.class("mt-[.5rem]")], [
              html.p([], [html.text(expanded_message)]),
            ])
          option.None -> element.fragment([])
        },
        html.hr([attribute.class("mt-[.5rem]")]),
      ])
    option.None ->
      html.div([], [
        html.div(
          [
            attribute.class(
              "flex items-start justify-between width-full mb-[.5rem]",
            ),
          ],
          [
            html.span([attribute.class("pt-[.1rem]")], [
              case model.is_reference {
                True ->
                  html.a([attribute.href("/" <> model.topic_id)], [
                    element.unsafe_raw_html(
                      "topic-title",
                      "span",
                      [],
                      model.topic_title,
                    ),
                  ])
                False ->
                  element.unsafe_raw_html(
                    "topic-title",
                    "span",
                    [],
                    model.topic_title,
                  )
              },
            ]),
            html.div([], [
              case model.is_reference {
                True ->
                  html.button(
                    [
                      event.on_click(UserToggledReferenceDiscussion),
                      attribute.class("icon-button p-[.3rem] mr-[.5rem]"),
                    ],
                    [lucide.x([])],
                  )
                False -> element.fragment([])
              },
              html.button(
                [
                  event.on_click(UserMaximizeThread),
                  attribute.class("icon-button p-[.3rem] "),
                ],
                [lucide.maximize_2([])],
              ),
            ]),
          ],
        ),
        references_view(references),
      ])
  }
}

fn references_view(references) {
  case list.length(references) > 0 {
    True ->
      html.div([attribute.class("mb-[.75rem]")], [
        reference_group_view(references, declaration.UsingReference),
        reference_group_view(references, declaration.InheritanceReference),
        reference_group_view(references, declaration.CallReference),
        reference_group_view(references, declaration.AccessReference),
        reference_group_view(references, declaration.MutationReference),
        reference_group_view(references, declaration.TypeReference),
      ])
    False -> element.fragment([])
  }
}

fn reference_group_view(references: List(declaration.Reference), group_kind) {
  case list.filter(references, fn(reference) { reference.kind == group_kind }) {
    [] -> element.fragment([])
    references ->
      element.fragment([
        html.p([], [
          html.text(declaration.node_reference_kind_to_annotation(group_kind)),
        ]),
        ..list.map(references, fn(reference) {
          html.p([attribute.class("pl-[.25rem]")], [
            html.a([attribute.href(declaration.reference_to_link(reference))], [
              html.text(declaration.contract_scope_to_string(reference.scope)),
            ]),
          ])
        })
      ])
  }
}

fn comments_view(
  model: Model,
  current_thread_notes: List(computed_note.ComputedNote),
) {
  html.div(
    [
      attribute.class(
        "flex flex-col-reverse overflow-auto max-h-[30rem] gap-[.5rem] mb-[.5rem]",
      ),
    ],
    list.map(current_thread_notes, fn(note) {
      html.div([attribute.class("line-discussion-item")], [
        // Comment header
        html.div([attribute.class("flex justify-between mb-[.2rem]")], [
          html.div([attribute.class("flex gap-[.5rem] items-start")], [
            html.p([], [html.text(note.user_name)]),
            significance_badge_view(note.significance),
          ]),
          html.div([attribute.class("flex gap-[.5rem]")], [
            case note.referee_topic_id {
              option.Some(..) ->
                html.p([attribute.class("italic")], [html.text("Reference")])
              _ ->
                html.button(
                  [
                    attribute.id("edit-message-button"),
                    attribute.class("icon-button p-[.3rem]"),
                    event.on_click(UserEditedNote(Ok(note))),
                  ],
                  [lucide.pencil([])],
                )
            },
            case note.expanded_message {
              option.Some(_) ->
                html.button(
                  [
                    attribute.id("expand-message-button"),
                    attribute.class("icon-button p-[.3rem]"),
                    event.on_click(UserToggledExpandedMessage(note.note_id)),
                  ],
                  [lucide.list_collapse([])],
                )
              option.None -> element.fragment([])
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
    }),
  )
}

fn significance_badge_view(sig: computed_note.ComputedNoteSignificance) {
  let badge_style =
    "input-border rounded-md text-[0.65rem] pb-[0.15rem] pt-1 px-[0.5rem]"

  case computed_note.significance_to_string(sig) {
    option.Some(significance) ->
      html.span([attribute.class(badge_style)], [html.text(significance)])
    option.None -> element.fragment([])
  }
}

fn new_message_input_view(model: Model, current_thread_notes) {
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
      option.Some(..) ->
        html.button(
          [
            attribute.id("cancel-message-edit-button"),
            attribute.class("icon-button p-[.3rem]"),
            event.on_click(UserCancelledEdit),
          ],
          [lucide.x([])],
        )
      option.None -> element.fragment([])
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
      on_input_keydown(
        UserSubmittedNote,
        UserEditedNote(list.first(current_thread_notes)),
      ),
      attribute.value(model.current_note_draft),
    ]),
  ])
}

fn expanded_message_view(model: Model) {
  let expanded_message_style =
    "absolute overlay p-[.5rem] flex w-[100%] h-60 mt-2"

  html.div(
    [
      attribute.id("expanded-message"),
      case model.show_expanded_message_box {
        True -> attribute.class(expanded_message_style <> " show-exp")
        False -> attribute.class(expanded_message_style)
      },
    ],
    [expand_message_input_view(model)],
  )
}

fn expand_message_input_view(model: Model) {
  html.textarea(
    [
      attribute.id("expanded-message-box"),
      attribute.class("grow text-[.95rem] resize-none p-[.3rem]"),
      attribute.placeholder("Write an expanded message body"),
      event.on_input(UserWroteExpandedMessage),
      event.on_focus(UserFocusedExpandedInput),
      event.on_blur(UserUnfocusedInput),
      eventx.on_ctrl_enter(UserSubmittedNote),
    ],
    model.current_expanded_message_draft |> option.unwrap(""),
  )
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
    computed_note.Informational -> "i: "
    computed_note.InformationalConfirmation -> "correct: "
    computed_note.InformationalRejection -> "incorrect: "
    computed_note.RejectedFinding -> "finding: "
    computed_note.RejectedInformational -> "i: "
    computed_note.ToDoCompletion -> "done: "
    computed_note.UnansweredDeveloperQuestion -> "dev: "
    computed_note.UnansweredQuestion -> "q: "
    computed_note.UnconfirmedFinding -> "finding: "
  }
}

fn on_input_keydown(enter_msg, up_msg) {
  event.on("keydown", {
    use ctrl_key <- decode.field("ctrlKey", decode.bool)
    use key <- decode.field("key", decode.string)
    case ctrl_key, key {
      True, "Enter" -> decode.success(enter_msg)
      _, "ArrowUp" -> decode.success(up_msg)
      _, _ -> decode.failure(enter_msg, "input_keydown")
    }
  })
}
