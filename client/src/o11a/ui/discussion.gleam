import given
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/set
import gleam/string
import lib/eventx
import lib/lucide
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event
import o11a/attributes
import o11a/classes
import o11a/computed_note
import o11a/note
import o11a/preprocessor
import o11a/ui/formatter
import plinth/javascript/global

// Discussion Controller -------------------------------------------------------

pub type DiscussionId {
  DiscussionId(view_id: String, line_number: Int, column_number: Int)
}

pub fn nested_view_id(from discussion_id: DiscussionId) {
  discussion_id.view_id
  <> "L"
  <> int.to_string(discussion_id.line_number)
  <> "C"
  <> int.to_string(discussion_id.column_number)
}

pub type DiscussionReference {
  DiscussionReference(
    discussion_id: DiscussionId,
    model: DiscussionOverlayModel,
  )
}

pub type DiscussionContext {
  DiscussionContext(
    active_discussions: dict.Dict(String, DiscussionControllerModel),
    dicsussion_models: dict.Dict(DiscussionId, DiscussionOverlayModel),
  )
}

pub fn get_active_discussion_reference(
  view_id,
  discussion_context: DiscussionContext,
) -> option.Option(DiscussionReference) {
  case
    dict.get(discussion_context.active_discussions, view_id)
    |> result.try(get_active_discussion_id)
  {
    Ok(discussion_id) ->
      dict.get(discussion_context.dicsussion_models, discussion_id)
      |> result.map(DiscussionReference(discussion_id, _))
    _ -> Error(Nil)
  }
  |> option.from_result
}

pub type DiscussionControllerModel {
  DiscussionControllerModel(
    hovered_discussion: option.Option(DiscussionId),
    focused_discussion: option.Option(DiscussionId),
    clicked_discussion: option.Option(DiscussionId),
    stickied_discussion: option.Option(DiscussionId),
  )
}

pub fn set_hovered_discussion(model, discussion_id) {
  case model {
    option.Some(model) ->
      DiscussionControllerModel(
        ..model,
        hovered_discussion: option.Some(discussion_id),
      )
    option.None ->
      DiscussionControllerModel(
        hovered_discussion: option.Some(discussion_id),
        focused_discussion: option.None,
        clicked_discussion: option.None,
        stickied_discussion: option.None,
      )
  }
}

pub fn unset_hovered_discussion(model) {
  case model {
    option.Some(model) ->
      DiscussionControllerModel(..model, hovered_discussion: option.None)
    option.None ->
      DiscussionControllerModel(
        hovered_discussion: option.None,
        focused_discussion: option.None,
        clicked_discussion: option.None,
        stickied_discussion: option.None,
      )
  }
}

pub fn set_focused_discussion(model, discussion_id) {
  case model {
    option.Some(model) ->
      DiscussionControllerModel(
        ..model,
        focused_discussion: option.Some(discussion_id),
        stickied_discussion: option.None,
      )
    option.None ->
      DiscussionControllerModel(
        hovered_discussion: option.None,
        focused_discussion: option.Some(discussion_id),
        clicked_discussion: option.None,
        stickied_discussion: option.None,
      )
  }
}

pub fn unset_focused_discussion(model) {
  case model {
    option.Some(model) ->
      DiscussionControllerModel(
        ..model,
        focused_discussion: option.None,
        stickied_discussion: option.None,
      )
    option.None ->
      DiscussionControllerModel(
        hovered_discussion: option.None,
        focused_discussion: option.None,
        clicked_discussion: option.None,
        stickied_discussion: option.None,
      )
  }
}

pub fn set_clicked_discussion(model, discussion_id) {
  case model {
    option.Some(model) ->
      DiscussionControllerModel(
        ..model,
        clicked_discussion: option.Some(discussion_id),
        stickied_discussion: option.None,
      )
    option.None ->
      DiscussionControllerModel(
        hovered_discussion: option.None,
        focused_discussion: option.None,
        clicked_discussion: option.Some(discussion_id),
        stickied_discussion: option.None,
      )
  }
}

pub fn unset_clicked_discussion(model) {
  case model {
    option.Some(model) ->
      DiscussionControllerModel(
        ..model,
        clicked_discussion: option.None,
        stickied_discussion: option.None,
      )
    option.None ->
      DiscussionControllerModel(
        hovered_discussion: option.None,
        focused_discussion: option.None,
        clicked_discussion: option.None,
        stickied_discussion: option.None,
      )
  }
}

pub fn set_stickied_discussion(model, discussion_id) {
  case model {
    option.Some(model) ->
      DiscussionControllerModel(
        ..model,
        stickied_discussion: option.Some(discussion_id),
      )
    option.None ->
      DiscussionControllerModel(
        hovered_discussion: option.None,
        focused_discussion: option.None,
        clicked_discussion: option.None,
        stickied_discussion: option.Some(discussion_id),
      )
  }
}

pub fn unset_stickied_discussion(model) {
  case model {
    option.Some(model) ->
      DiscussionControllerModel(..model, stickied_discussion: option.None)
    option.None ->
      DiscussionControllerModel(
        hovered_discussion: option.None,
        focused_discussion: option.None,
        clicked_discussion: option.None,
        stickied_discussion: option.None,
      )
  }
}

pub fn get_active_discussion_id(model: DiscussionControllerModel) {
  case
    model.focused_discussion,
    model.clicked_discussion,
    model.stickied_discussion,
    model.hovered_discussion
  {
    option.Some(discussion), _, _, _
    | _, option.Some(discussion), _, _
    | _, _, option.Some(discussion), _
    | _, _, _, option.Some(discussion)
    -> Ok(discussion)
    option.None, option.None, option.None, option.None -> Error(Nil)
  }
}

pub fn close_all_child_discussions(
  active_discussions: dict.Dict(String, DiscussionControllerModel),
  starting_from view_id,
) {
  case dict.get(active_discussions, view_id) {
    Ok(model) -> {
      let active_discussions = case model.focused_discussion {
        option.Some(focused_discussion) ->
          close_all_child_discussions(
            active_discussions,
            starting_from: nested_view_id(focused_discussion),
          )
        option.None -> active_discussions
      }

      let active_discussions = case model.clicked_discussion {
        option.Some(clicked_discussion) ->
          close_all_child_discussions(
            active_discussions,
            starting_from: nested_view_id(clicked_discussion),
          )
        option.None -> active_discussions
      }

      let active_discussions = case model.stickied_discussion {
        option.Some(stickied_discussion) ->
          close_all_child_discussions(
            active_discussions,
            starting_from: nested_view_id(stickied_discussion),
          )
        option.None -> active_discussions
      }

      let active_discussions = case model.hovered_discussion {
        option.Some(hovered_discussion) ->
          close_all_child_discussions(
            active_discussions,
            starting_from: nested_view_id(hovered_discussion),
          )
        option.None -> active_discussions
      }

      dict.delete(active_discussions, view_id)
    }
    Error(Nil) -> active_discussions
  }
}

pub type DiscussionControllerMsg {
  UserSelectedDiscussionEntry(
    kind: DiscussionSelectKind,
    discussion_id: DiscussionId,
    node_id: option.Option(Int),
    topic_id: String,
    is_reference: Bool,
  )
  UserUnselectedDiscussionEntry(
    kind: DiscussionSelectKind,
    discussion_id: DiscussionId,
  )
  UserStartedStickyOpenTimer(timer_id: global.TimerID)
  UserStartedStickyCloseTimer(timer_id: global.TimerID)
  UserHoveredInsideDiscussion(discussion_id: DiscussionId)
  UserUnhoveredInsideDiscussion(discussion_id: DiscussionId)
  ClientSetStickyDiscussion(discussion_id: DiscussionId)
  ClientUnsetStickyDiscussion(discussion_id: DiscussionId)
  UserClickedDiscussionEntry(discussion_id: DiscussionId)
  UserClickedInsideDiscussion(discussion_id: DiscussionId)
  UserClickedOutsideDiscussion(view_id: String)
  UserCtrlClickedNode(uri: String)
  UserUpdatedDiscussion(
    model: DiscussionOverlayModel,
    msg: DiscussionOverlayMsg,
  )
}

pub type DiscussionSelectKind {
  Hover
  Focus
}

pub fn discussion_view(
  attrs,
  discussion discussion,
  declarations declarations,
  discussion_id discussion_id,
  active_discussion active_discussion: option.Option(DiscussionReference),
  discussion_context discussion_context,
) {
  case active_discussion {
    option.Some(active_discussion) ->
      case discussion_id == active_discussion.discussion_id {
        True ->
          html.div(attrs, [
            overlay_view(
              active_discussion.model,
              discussion,
              declarations:,
              discussion_context:,
            ),
          ])
        False -> element.fragment([])
      }
    option.None -> element.fragment([])
  }
}

fn map_discussion_overlay_msg(msg, model: DiscussionOverlayModel) {
  UserUpdatedDiscussion(model, msg)
}

// Discussion Node -------------------------------------------------------------

pub fn topic_signature_view(
  view_id view_id: String,
  signature signature: List(preprocessor.PreProcessedSnippetLine),
  declarations declarations: dict.Dict(String, preprocessor.Declaration),
  discussion discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  suppress_declaration suppress_declaration: Bool,
  line_number_offset line_number_offset: Int,
  active_discussion active_discussion: option.Option(DiscussionReference),
  discussion_context discussion_context,
) -> List(element.Element(DiscussionControllerMsg)) {
  list.map_fold(
    signature,
    line_number_offset,
    fn(line_number_offset, preprocessed_snippet_line) {
      let new_line_number = line_number_offset + 1

      let #(_col_index, new_line) =
        preprocessed_snippet_line.elements
        |> list.map_fold(0, fn(column_number, node) {
          case node {
            preprocessor.PreProcessedDeclaration(topic_id:, tokens:) -> {
              case suppress_declaration {
                True -> {
                  #(column_number, node_view(topic_id:, tokens:, declarations:))
                }
                False -> {
                  let new_column_number = column_number + 1

                  let rendered_node =
                    node_with_discussion_view(
                      topic_id:,
                      tokens:,
                      discussion:,
                      declarations:,
                      discussion_id: DiscussionId(
                        view_id:,
                        line_number: new_line_number,
                        column_number: new_column_number,
                      ),
                      active_discussion:,
                      discussion_context:,
                      node_view_kind: DeclarationView,
                    )

                  #(new_column_number, rendered_node)
                }
              }
            }

            preprocessor.PreProcessedReference(topic_id:, tokens:) -> {
              let new_column_number = column_number + 1

              let rendered_node =
                node_with_discussion_view(
                  topic_id:,
                  tokens:,
                  discussion:,
                  declarations:,
                  discussion_id: DiscussionId(
                    view_id:,
                    line_number: new_line_number,
                    column_number: new_column_number,
                  ),
                  active_discussion:,
                  discussion_context:,
                  node_view_kind: ReferenceView,
                )

              #(new_column_number, rendered_node)
            }

            preprocessor.PreProcessedNode(element:)
            | preprocessor.PreProcessedGapNode(element:, ..) -> #(
              column_number,
              element.fragment([
                element.unsafe_raw_html(
                  "preprocessed-node",
                  "span",
                  [],
                  element,
                ),
              ]),
            )

            preprocessor.FormatterNewline | preprocessor.FormatterBlock(..) -> #(
              column_number,
              element.fragment([]),
            )
          }
        })

      let new_line = case preprocessed_snippet_line.leading_spaces {
        0 -> new_line
        leading_spaces -> [
          html.span([], [html.text(string.repeat("\u{a0}", leading_spaces))]),
          ..new_line
        ]
      }

      let #(_, info_notes) = case preprocessed_snippet_line.significance {
        preprocessor.SingleDeclarationLine(line_topic_id)
          if !suppress_declaration
        ->
          formatter.get_notes(
            discussion,
            preprocessed_snippet_line.leading_spaces,
            line_topic_id,
          )
        preprocessor.NonEmptyLine(line_topic_id) ->
          formatter.get_notes(
            discussion,
            preprocessed_snippet_line.leading_spaces,
            line_topic_id,
          )
        preprocessor.EmptyLine | preprocessor.SingleDeclarationLine(..) -> #(
          [],
          [],
        )
      }

      let new_line =
        element.fragment([
          element.fragment(
            list.map(info_notes, fn(note) {
              let #(_note_index_id, note_message) = note
              html.p([attribute.class("comment italic")], [
                html.text(
                  string.repeat(
                    "\u{a0}",
                    preprocessed_snippet_line.leading_spaces,
                  )
                  <> note_message,
                ),
              ])
            }),
          ),
          html.p([attribute.class("loc flex")], new_line),
        ])

      #(new_line_number, new_line)
    },
  )
  |> pair.second
}

pub fn node_view(
  topic_id topic_id: String,
  tokens tokens: String,
  declarations declarations,
) {
  let node_declaration =
    dict.get(declarations, topic_id)
    |> result.unwrap(preprocessor.unknown_declaration)

  html.span(
    [
      attribute.class(preprocessor.declaration_kind_to_string(
        node_declaration.kind,
      )),
    ],
    [html.text(tokens)],
  )
}

pub type NodeWithDiscussionViewKind {
  ReferenceView
  DeclarationView
  NewDiscussionPreview
  CommentPreview
}

pub fn node_with_discussion_view(
  topic_id topic_id: String,
  tokens tokens: String,
  discussion discussion,
  declarations declarations,
  discussion_id discussion_id,
  active_discussion active_discussion: option.Option(DiscussionReference),
  discussion_context discussion_context,
  node_view_kind node_view_kind: NodeWithDiscussionViewKind,
) {
  let attrs = case node_view_kind {
    ReferenceView -> {
      let node_declaration =
        dict.get(declarations, topic_id)
        |> result.unwrap(preprocessor.unknown_declaration)

      reference_node_attributes(discussion_id:, node_declaration:, topic_id:)
    }

    DeclarationView -> {
      let node_declaration =
        dict.get(declarations, topic_id)
        |> result.unwrap(preprocessor.unknown_declaration)

      declaration_node_attributes(discussion_id:, node_declaration:, topic_id:)
    }

    NewDiscussionPreview ->
      new_discussion_preview_attributes(discussion_id:, topic_id:)

    CommentPreview -> comment_preview_attributes(discussion_id:, topic_id:)
  }

  html.span(
    [
      attribute.class("relative"),
      attributes.encode_grid_location_data(
        line_number: discussion_id.line_number |> int.to_string,
        column_number: discussion_id.column_number |> int.to_string,
      ),
      event.on_mouse_enter(UserHoveredInsideDiscussion(discussion_id:)),
      event.on_mouse_leave(UserUnhoveredInsideDiscussion(discussion_id:)),
    ],
    [
      html.span(attrs, [html.text(tokens)]),
      discussion_view(
        [
          event.on_click(UserClickedInsideDiscussion(discussion_id:))
          |> event.stop_propagation,
        ],
        discussion:,
        declarations:,
        discussion_id:,
        active_discussion:,
        discussion_context:,
      ),
    ],
  )
}

fn declaration_node_attributes(
  discussion_id discussion_id: DiscussionId,
  node_declaration node_declaration: preprocessor.Declaration,
  topic_id topic_id: String,
) {
  [
    attribute.id(preprocessor.declaration_to_qualified_name(node_declaration)),
    attribute.class(preprocessor.declaration_kind_to_string(
      node_declaration.kind,
    )),
    attribute.class(
      "declaration-preview N" <> int.to_string(node_declaration.id),
    ),
    attribute.class(classes.discussion_entry),
    attribute.class(classes.discussion_entry_hover),
    attribute.attribute("tabindex", "0"),
    event.on_focus(UserSelectedDiscussionEntry(
      kind: Focus,
      discussion_id:,
      node_id: option.Some(node_declaration.id),
      topic_id:,
      is_reference: False,
    )),
    event.on_blur(UserUnselectedDiscussionEntry(kind: Focus, discussion_id:)),
    event.on_mouse_enter(UserSelectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
      node_id: option.Some(node_declaration.id),
      topic_id:,
      is_reference: False,
    )),
    event.on_mouse_leave(UserUnselectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
    )),
    event.on_click(UserClickedDiscussionEntry(discussion_id:))
      |> event.stop_propagation,
  ]
}

fn reference_node_attributes(
  discussion_id discussion_id: DiscussionId,
  node_declaration node_declaration: preprocessor.Declaration,
  topic_id topic_id: String,
) {
  [
    attribute.class(preprocessor.declaration_kind_to_string(
      node_declaration.kind,
    )),
    attribute.class("reference-preview N" <> int.to_string(node_declaration.id)),
    attribute.class(classes.discussion_entry),
    attribute.class(classes.discussion_entry_hover),
    attribute.attribute("tabindex", "0"),
    event.on_focus(UserSelectedDiscussionEntry(
      kind: Focus,
      discussion_id:,
      node_id: option.Some(node_declaration.id),
      topic_id:,
      is_reference: True,
    )),
    event.on_blur(UserUnselectedDiscussionEntry(kind: Focus, discussion_id:)),
    event.on_mouse_enter(UserSelectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
      node_id: option.Some(node_declaration.id),
      topic_id:,
      is_reference: True,
    )),
    event.on_mouse_leave(UserUnselectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
    )),
    eventx.on_ctrl_click(
      ctrl_click: UserCtrlClickedNode(uri: preprocessor.declaration_to_link(
        node_declaration,
      )),
      non_ctrl_click: option.Some(UserClickedDiscussionEntry(discussion_id:)),
    )
      |> event.stop_propagation,
  ]
}

fn new_discussion_preview_attributes(
  discussion_id discussion_id: DiscussionId,
  topic_id topic_id: String,
) {
  [
    attribute.class("inline-comment font-code code-extras"),
    attribute.class("new-thread-preview"),
    attribute.class(classes.discussion_entry),
    attribute.class(topic_id),
    attribute.attribute("tabindex", "0"),
    event.on_focus(UserSelectedDiscussionEntry(
      kind: Focus,
      discussion_id:,
      node_id: option.None,
      topic_id:,
      is_reference: False,
    )),
    event.on_blur(UserUnselectedDiscussionEntry(kind: Focus, discussion_id:)),
    event.on_mouse_enter(UserSelectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
      node_id: option.None,
      topic_id:,
      is_reference: False,
    )),
    event.on_mouse_leave(UserUnselectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
    )),
    eventx.on_non_ctrl_click(UserClickedDiscussionEntry(discussion_id:))
      |> event.stop_propagation,
  ]
}

fn comment_preview_attributes(
  discussion_id discussion_id: DiscussionId,
  topic_id topic_id: String,
) {
  [
    attribute.class("inline-comment font-code code-extras font-code fade-in"),
    attribute.class("comment-preview"),
    attribute.class(classes.discussion_entry),
    attribute.class(topic_id),
    attribute.attribute("tabindex", "0"),
    event.on_focus(UserSelectedDiscussionEntry(
      kind: Focus,
      discussion_id:,
      node_id: option.None,
      topic_id:,
      is_reference: False,
    )),
    event.on_blur(UserUnselectedDiscussionEntry(kind: Focus, discussion_id:)),
    event.on_mouse_enter(UserSelectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
      node_id: option.None,
      topic_id:,
      is_reference: False,
    )),
    event.on_mouse_leave(UserUnselectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
    )),
    eventx.on_non_ctrl_click(UserClickedDiscussionEntry(discussion_id:))
      |> event.stop_propagation,
  ]
}

// Discussion Overlay ----------------------------------------------------------

pub type DiscussionOverlayModel {
  DiscussionOverlayModel(
    is_reference: Bool,
    show_reference_discussion: Bool,
    user_name: String,
    topic_id: String,
    view_id: String,
    discussion_id: DiscussionId,
    current_note_draft: String,
    current_thread_id: String,
    active_thread: option.Option(ActiveThread),
    show_expanded_message_box: Bool,
    current_expanded_message_draft: option.Option(String),
    expanded_messages: set.Set(String),
    editing_note: option.Option(computed_note.ComputedNote),
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
  view_id view_id: String,
  discussion_id discussion_id: DiscussionId,
  topic_id topic_id,
  is_reference is_reference,
) {
  DiscussionOverlayModel(
    is_reference:,
    show_reference_discussion: False,
    user_name: "guest",
    topic_id:,
    view_id:,
    discussion_id:,
    current_note_draft: "",
    current_thread_id: topic_id,
    active_thread: option.None,
    show_expanded_message_box: False,
    current_expanded_message_draft: option.None,
    expanded_messages: set.new(),
    editing_note: option.None,
  )
}

pub type DiscussionOverlayMsg {
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
  UserCopiedDeclarationId(String)
}

pub type DiscussionOverlayEffect {
  SubmitNote(note: note.NoteSubmission, topic_id: String)
  FocusDiscussionInput(discussion_id: DiscussionId)
  FocusExpandedDiscussionInput(discussion_id: DiscussionId)
  UnfocusDiscussionInput(discussion_id: DiscussionId)
  MaximizeDiscussion(discussion_id: DiscussionId)
  CopyDeclarationId(declaration_id: String)
  None
}

pub fn update(model: DiscussionOverlayModel, msg: DiscussionOverlayMsg) {
  case msg {
    UserWroteNote(draft) -> {
      #(DiscussionOverlayModel(..model, current_note_draft: draft), None)
    }
    UserSubmittedNote -> {
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

      let referenced_topic_ids = []
      // TODO: parse the references as the message is being typed, not just
      // when the user submits the message
      // preprocessor.get_references(message, with: model.declarations)
      // |> list.append(case expanded_message {
      //   option.Some(expanded_message) ->
      //     preprocessor.get_references(
      //       expanded_message,
      //       with: model.declarations,
      //     )
      //   option.None -> []
      // })
      // |> list.unique

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
        DiscussionOverlayModel(
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
      DiscussionOverlayModel(
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
        DiscussionOverlayModel(
          ..model,
          current_thread_id: new_current_thread_id,
          active_thread: new_active_thread,
        ),
        None,
      )
    }
    UserToggledExpandedMessageBox(show_expanded_message_box) -> #(
      DiscussionOverlayModel(..model, show_expanded_message_box:),
      None,
    )
    UserWroteExpandedMessage(expanded_message) -> #(
      DiscussionOverlayModel(
        ..model,
        current_expanded_message_draft: option.Some(expanded_message),
      ),
      None,
    )
    UserToggledExpandedMessage(for_note_id) ->
      case set.contains(model.expanded_messages, for_note_id) {
        True -> #(
          DiscussionOverlayModel(
            ..model,
            expanded_messages: set.delete(model.expanded_messages, for_note_id),
          ),
          None,
        )
        False -> #(
          DiscussionOverlayModel(
            ..model,
            expanded_messages: set.insert(model.expanded_messages, for_note_id),
          ),
          None,
        )
      }
    UserFocusedInput -> #(model, FocusDiscussionInput(model.discussion_id))
    // When the expanaded message box is focused, set the show_expanded_message_box
    // to true. This makes sure the model state is in sync with any external
    // calls to focus the expanded message box.
    UserFocusedExpandedInput -> #(
      DiscussionOverlayModel(..model, show_expanded_message_box: True),
      FocusExpandedDiscussionInput(model.discussion_id),
    )
    UserUnfocusedInput -> #(model, UnfocusDiscussionInput(model.discussion_id))
    UserMaximizeThread -> #(model, MaximizeDiscussion(model.discussion_id))
    UserEditedNote(note) ->
      case note {
        Ok(note) -> #(
          DiscussionOverlayModel(
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
      DiscussionOverlayModel(
        ..model,
        current_note_draft: "",
        current_expanded_message_draft: option.None,
        editing_note: option.None,
        show_expanded_message_box: False,
      ),
      None,
    )
    UserToggledReferenceDiscussion -> #(
      DiscussionOverlayModel(
        ..model,
        show_reference_discussion: !model.show_reference_discussion,
      ),
      None,
    )
    UserCopiedDeclarationId(declaration_id) -> #(
      model,
      CopyDeclarationId(declaration_id),
    )
  }
}

pub fn overlay_view(
  model: DiscussionOverlayModel,
  notes notes: dict.Dict(String, List(computed_note.ComputedNote)),
  declarations declarations: dict.Dict(String, preprocessor.Declaration),
  discussion_context discussion_context,
) -> element.Element(DiscussionControllerMsg) {
  let active_discussion: option.Option(DiscussionReference) =
    get_active_discussion_reference(model.view_id, discussion_context)

  let current_thread_notes =
    dict.get(notes, model.current_thread_id)
    |> result.unwrap([])

  let references =
    dict.get(declarations, model.topic_id)
    |> result.map(fn(declaration) { declaration.references })
    |> result.unwrap([])

  html.div(
    [
      attribute.class(
        "absolute z-[3] w-[30rem] not-italic text-wrap select-text text left-[-.3rem]",
      ),
      // The line discussion component is too close to the edge of the
      // screen, so we want to show it below the line
      case model.discussion_id.line_number < 30 {
        True -> attribute.class("top-[1.75rem]")
        False -> attribute.class("bottom-[1.75rem]")
      },
    ],
    [
      case model.is_reference && !model.show_reference_discussion {
        True ->
          html.div([attribute.class("overlay p-[.5rem]")], [
            reference_header_view(
              model,
              current_thread_notes:,
              declarations:,
              notes:,
              active_discussion:,
              discussion_context:,
            ),
          ])
        False ->
          element.fragment([
            html.div([attribute.class("overlay p-[.5rem]")], [
              thread_header_view(
                model,
                references:,
                notes:,
                declarations:,
                active_discussion:,
                discussion_context:,
              ),
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

pub fn panel_view(
  model: DiscussionOverlayModel,
  notes,
  references,
  declarations,
  active_discussion active_discussion: option.Option(DiscussionReference),
  discussion_context discussion_context,
) {
  let current_thread_notes =
    dict.get(notes, model.current_thread_id)
    |> result.unwrap([])

  html.div([attribute.style("padding", ".5rem")], [
    case model.is_reference {
      True ->
        reference_header_view(
          model,
          current_thread_notes:,
          declarations:,
          notes:,
          active_discussion:,
          discussion_context:,
        )
      False -> element.fragment([])
    },
    thread_header_view(
      model,
      references:,
      notes:,
      declarations:,
      active_discussion:,
      discussion_context:,
    ),
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

fn reference_header_view(
  model: DiscussionOverlayModel,
  current_thread_notes current_thread_notes,
  declarations declarations: dict.Dict(String, preprocessor.Declaration),
  active_discussion active_discussion: option.Option(DiscussionReference),
  discussion_context discussion_context,
  notes notes,
) -> element.Element(DiscussionControllerMsg) {
  let declaration =
    dict.get(declarations, model.topic_id)
    |> result.unwrap(preprocessor.unknown_declaration)
  element.fragment([
    html.div(
      [
        attribute.class(
          "flex items-start justify-between width-full mb-[.5rem]",
        ),
      ],
      [
        html.span([attribute.class("pt-[.1rem]")], [
          get_topic_title(
            model,
            notes:,
            declarations:,
            active_discussion:,
            discussion_context:,
          ),
        ]),
        html.div([], [
          html.button(
            [
              event.on_click(
                UserCopiedDeclarationId(
                  preprocessor.declaration_to_qualified_name(declaration),
                ),
              ),
              attribute.class("icon-button p-[.3rem]"),
            ],
            [lucide.copy([])],
          )
            |> element.map(map_discussion_overlay_msg(_, model)),
          html.button(
            [
              event.on_click(UserToggledReferenceDiscussion),
              attribute.class("icon-button p-[.3rem]"),
            ],
            [lucide.messages_square([])],
          )
            |> element.map(map_discussion_overlay_msg(_, model)),
        ]),
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

fn thread_header_view(
  model: DiscussionOverlayModel,
  declarations declarations: dict.Dict(String, preprocessor.Declaration),
  references references: List(preprocessor.Reference),
  active_discussion active_discussion: option.Option(DiscussionReference),
  discussion_context discussion_context,
  notes notes,
) -> element.Element(DiscussionControllerMsg) {
  let declaration =
    dict.get(declarations, model.topic_id)
    |> result.unwrap(preprocessor.unknown_declaration)

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
          )
          |> element.map(map_discussion_overlay_msg(_, model)),
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
              get_topic_title(
                model,
                notes:,
                declarations:,
                active_discussion:,
                discussion_context:,
              ),
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
                  |> element.map(map_discussion_overlay_msg(_, model))

                False -> element.fragment([])
              },
              html.button(
                [
                  event.on_click(
                    UserCopiedDeclarationId(
                      preprocessor.declaration_to_qualified_name(declaration),
                    ),
                  ),
                  attribute.class("icon-button p-[.3rem]"),
                ],
                [lucide.copy([])],
              )
                |> element.map(map_discussion_overlay_msg(_, model)),
              html.button(
                [
                  event.on_click(UserMaximizeThread),
                  attribute.class("icon-button p-[.3rem] "),
                ],
                [lucide.maximize_2([])],
              )
                |> element.map(map_discussion_overlay_msg(_, model)),
            ]),
          ],
        ),
        // If the declaration is inside a member, then it is a local variable
        // and will only ever be accessed inside that scope, so no need to
        // show that
        case declaration.scope.member |> option.is_some {
          True -> element.fragment([])
          False -> references_view(references)
        },
      ])
  }
}

fn references_view(references) {
  case list.length(references) > 0 {
    True ->
      html.div([attribute.class("mb-[.75rem]")], [
        reference_group_view(references, preprocessor.UsingReference),
        reference_group_view(references, preprocessor.InheritanceReference),
        reference_group_view(references, preprocessor.CallReference),
        reference_group_view(references, preprocessor.AccessReference),
        reference_group_view(references, preprocessor.MutationReference),
        reference_group_view(references, preprocessor.TypeReference),
      ])
    False -> element.fragment([])
  }
}

fn reference_group_view(references: List(preprocessor.Reference), group_kind) {
  case list.filter(references, fn(reference) { reference.kind == group_kind }) {
    [] -> element.fragment([])
    references ->
      element.fragment([
        html.p([], [
          html.text(preprocessor.node_reference_kind_to_annotation(group_kind)),
        ]),
        ..list.map(references, fn(reference) {
          html.p([attribute.class("pl-[.25rem]")], [
            html.a([attribute.href(preprocessor.reference_to_link(reference))], [
              html.text(preprocessor.contract_scope_to_string(reference.scope)),
            ]),
          ])
        })
      ])
  }
}

fn comments_view(
  model: DiscussionOverlayModel,
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
                |> element.map(map_discussion_overlay_msg(_, model))
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
                |> element.map(map_discussion_overlay_msg(_, model))

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
                |> element.map(map_discussion_overlay_msg(_, model))

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

fn new_message_input_view(
  model: DiscussionOverlayModel,
  current_thread_notes,
) -> element.Element(DiscussionControllerMsg) {
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
    )
      |> element.map(map_discussion_overlay_msg(_, model)),
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
        |> element.map(map_discussion_overlay_msg(_, model))

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
    ])
      |> element.map(map_discussion_overlay_msg(_, model)),
  ])
}

fn expanded_message_view(model: DiscussionOverlayModel) {
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

fn expand_message_input_view(model: DiscussionOverlayModel) {
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
  |> element.map(map_discussion_overlay_msg(_, model))
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

fn get_topic_title(
  model: DiscussionOverlayModel,
  active_discussion active_discussion: option.Option(DiscussionReference),
  discussion_context discussion_context,
  declarations declarations: dict.Dict(String, preprocessor.Declaration),
  notes notes,
) -> element.Element(DiscussionControllerMsg) {
  case dict.get(declarations, model.topic_id) {
    Ok(dec) ->
      element.fragment(topic_signature_view(
        view_id: model.view_id,
        signature: dec.signature,
        declarations:,
        discussion: notes,
        suppress_declaration: True,
        line_number_offset: 0,
        active_discussion:,
        discussion_context:,
      ))
    Error(Nil) -> html.span([], [html.text("unknown")])
  }
}
