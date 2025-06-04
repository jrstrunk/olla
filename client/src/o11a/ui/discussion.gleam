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
  DiscussionId(view_id: List(String), line_number: Int, column_number: Int)
}

pub type DiscussionReference {
  DiscussionReference(
    discussion_id: DiscussionId,
    model: DiscussionOverlayModel,
  )
}

pub type DiscussionControllerMsg {
  UserSelectedDiscussionEntry(
    kind: DiscussionSelectKind,
    discussion_id: DiscussionId,
    node_id: option.Option(Int),
    topic_id: String,
    is_reference: Bool,
  )
  UserUnselectedDiscussionEntry(kind: DiscussionSelectKind)
  UserStartedStickyOpenTimer(timer_id: global.TimerID)
  UserStartedStickyCloseTimer(timer_id: global.TimerID)
  UserHoveredInsideDiscussion(discussion_id: DiscussionId)
  UserUnhoveredInsideDiscussion(discussion_id: DiscussionId)
  ClientSetStickyDiscussion(discussion_id: DiscussionId)
  ClientUnsetStickyDiscussion
  UserClickedDiscussionEntry(discussion_id: DiscussionId)
  UserClickedInsideDiscussion(discussion_id: DiscussionId)
  UserClickedOutsideDiscussion(view_id: List(String))
  UserCtrlClickedNode(uri: String)
  UserUpdatedDiscussion(
    discussion_id: DiscussionId,
    update: #(DiscussionOverlayModel, DiscussionOverlayEffect),
  )
}

pub type DiscussionSelectKind {
  Hover
  Focus
}

// pub fn discussion_controller_update(model: DiscussionControllerModel, msg) {
//   case msg {
//     UserSelectedDiscussionEntry(
//       kind:,
//       view_id:,
//       line_number:,
//       column_number:,
//       node_id:,
//       topic_id:,
//       is_reference:,
//     ) -> {
//       let selected_discussion_id =
//         DiscussionId(view_id:, line_number:, column_number:)

//       let discussion_models = case
//         dict.get(model.discussion_models, selected_discussion_id)
//       {
//         Ok(..) -> model.discussion_models
//         Error(Nil) ->
//           dict.insert(
//             model.discussion_models,
//             selected_discussion_id,
//             init(
//               view_id: view_id <> topic_id,
//               line_number:,
//               column_number:,
//               topic_id:,
//               is_reference:,
//             ),
//           )
//       }

//       #(
//         case kind {
//           Hover -> {
//             let updated_model =
//               DiscussionControllerModel(
//                 ..model,
//                 selected_discussion_id: option.Some(selected_discussion_id),
//                 discussion_models:,
//               )
//             UserActivatedEntry(updated_model, node_id)
//           }
//           Focus -> {
//             let updated_model =
//               DiscussionControllerModel(
//                 ..model,
//                 focused_discussion_id: option.Some(selected_discussion_id),
//                 discussion_models:,
//                 stickied_discussion_id: option.None,
//               )

//             UserFocusedEntry(
//               updated_model,
//               node_id,
//               view_id,
//               line_number,
//               column_number,
//             )
//           }
//         },
//         case kind {
//           Hover ->
//             effect.from(fn(dispatch) {
//               let timer_id =
//                 global.set_timeout(300, fn() {
//                   dispatch(ClientSetStickyDiscussion(
//                     view_id:,
//                     line_number:,
//                     column_number:,
//                   ))
//                 })
//               dispatch(UserStartedStickyOpenTimer(timer_id))
//             })
//           Focus -> effect.none()
//         },
//       )
//     }

//     UserUnselectedDiscussionEntry(kind:) -> {
//       #(
//         case kind {
//           Hover -> {
//             let updated_model =
//               DiscussionControllerModel(
//                 ..model,
//                 selected_discussion_id: option.None,
//               )
//             UserActivatedEntry(updated_model, node_id: option.None)
//           }
//           Focus -> {
//             let updated_model =
//               DiscussionControllerModel(
//                 ..model,
//                 focused_discussion_id: option.None,
//                 clicked_discussion_id: option.None,
//               )
//             UserActivatedEntry(updated_model, node_id: option.None)
//           }
//         },
//         effect.from(fn(_dispatch) {
//           case model.set_sticky_discussion_timer {
//             option.Some(timer_id) -> {
//               global.clear_timeout(timer_id)
//             }
//             option.None -> Nil
//           }
//         }),
//       )
//     }

//     UserStartedStickyOpenTimer(timer_id) -> {
//       #(
//         NoOp(
//           DiscussionControllerModel(
//             ..model,
//             set_sticky_discussion_timer: option.Some(timer_id),
//           ),
//         ),
//         effect.none(),
//       )
//     }

//     ClientSetStickyDiscussion(view_id:, line_number:, column_number:) -> {
//       #(
//         NoOp(
//           DiscussionControllerModel(
//             ..model,
//             stickied_discussion_id: option.Some(DiscussionId(
//               view_id:,
//               line_number:,
//               column_number:,
//             )),
//             set_sticky_discussion_timer: option.None,
//           ),
//         ),
//         effect.none(),
//       )
//     }

//     UserUnhoveredInsideDiscussion(view_id:, line_number:, column_number:) -> {
//       echo "User unhovered discussion entry " <> int.to_string(line_number)
//       #(NoOp(model), case model.stickied_discussion_id {
//         option.Some(discussion_id) ->
//           case
//             line_number == discussion_id.line_number
//             && column_number == discussion_id.column_number
//             && view_id == discussion_id.view_id
//           {
//             True ->
//               effect.from(fn(dispatch) {
//                 let timer_id =
//                   global.set_timeout(200, fn() {
//                     echo "Unsticking discussion"
//                     dispatch(ClientUnsetStickyDiscussion)
//                   })
//                 dispatch(UserStartedStickyCloseTimer(timer_id))
//               })
//             False -> effect.none()
//           }
//         option.None -> effect.none()
//       })
//     }

//     UserHoveredInsideDiscussion(view_id:, line_number:, column_number:) -> {
//       echo "User hovered discussion entry " <> int.to_string(line_number)
//       // Do not clear the timer in the state generically without checking the
//       // hovered line and col number here, as hovering any element will clear 
//       // the timer if so
//       #(NoOp(model), case model.stickied_discussion_id {
//         option.Some(discussion_id) ->
//           case
//             line_number == discussion_id.line_number
//             && column_number == discussion_id.column_number
//             && view_id == discussion_id.view_id
//           {
//             True ->
//               effect.from(fn(_dispatch) {
//                 case model.unset_sticky_discussion_timer {
//                   option.Some(timer_id) -> {
//                     global.clear_timeout(timer_id)
//                   }
//                   option.None -> Nil
//                 }
//               })
//             False -> effect.none()
//           }
//         option.None -> effect.none()
//       })
//     }

//     UserStartedStickyCloseTimer(timer_id) -> {
//       echo "User started sticky close timer"
//       #(
//         NoOp(
//           DiscussionControllerModel(
//             ..model,
//             unset_sticky_discussion_timer: option.Some(timer_id),
//           ),
//         ),
//         effect.none(),
//       )
//     }

//     ClientUnsetStickyDiscussion -> {
//       #(
//         NoOp(
//           DiscussionControllerModel(
//             ..model,
//             stickied_discussion_id: option.None,
//             unset_sticky_discussion_timer: option.None,
//           ),
//         ),
//         effect.none(),
//       )
//     }

//     UserClickedDiscussionEntry(view_id:, line_number:, column_number:) -> {
//       #(
//         NoOp(
//           DiscussionControllerModel(
//             ..model,
//             clicked_discussion_id: option.Some(DiscussionId(
//               view_id:,
//               line_number:,
//               column_number:,
//             )),
//             stickied_discussion_id: option.None,
//           ),
//         ),
//         effect.from(fn(_dispatch) {
//           let res =
//             selectors.discussion_input(view_id:, line_number:, column_number:)
//             |> result.map(browser_element.focus)

//           case res {
//             Ok(Nil) -> Nil
//             Error(Nil) -> io.println_error("Failed to focus discussion input")
//           }
//         }),
//       )
//     }
//     UserClickedInsideDiscussion(view_id:, line_number:, column_number:) -> {
//       echo "User clicked inside discussion"
//       let model = case
//         model.selected_discussion_id
//         != option.Some(DiscussionId(view_id:, line_number:, column_number:))
//       {
//         True ->
//           DiscussionControllerModel(
//             ..model,
//             selected_discussion_id: option.None,
//           )
//         False -> model
//       }

//       let model = case
//         model.focused_discussion_id
//         != option.Some(DiscussionId(view_id:, line_number:, column_number:))
//       {
//         True ->
//           DiscussionControllerModel(
//             ..model,
//             focused_discussion_id: option.None,
//           )
//         False -> model
//       }

//       let model = case
//         model.clicked_discussion_id
//         != option.Some(DiscussionId(view_id:, line_number:, column_number:))
//       {
//         True ->
//           DiscussionControllerModel(
//             ..model,
//             clicked_discussion_id: option.None,
//           )
//         False -> model
//       }

//       #(NoOp(model), effect.none())
//     }

//     UserClickedOutsideDiscussion -> {
//       echo "User clicked outside discussion"
//       #(
//         NoOp(
//           DiscussionControllerModel(
//             ..model,
//             selected_discussion_id: option.None,
//             focused_discussion_id: option.None,
//             clicked_discussion_id: option.None,
//           ),
//         ),
//         effect.none(),
//       )
//     }

//     UserCtrlClickedNode(uri) -> {
//       let #(path, fragment) = case string.split_once(uri, "#") {
//         Ok(#(uri, fragment)) -> #(uri, option.Some(fragment))
//         Error(..) -> #(uri, option.None)
//       }
//       let path = "/" <> path

//       #(NoOp(model), modem.push(path, option.None, fragment))
//     }
//   }
// }

pub fn discussion_view(
  attrs,
  discussion discussion,
  declarations declarations,
  discussion_id discussion_id,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  case selected_discussion {
    option.Some(selected_discussion) ->
      case discussion_id == selected_discussion.discussion_id {
        True ->
          html.div(attrs, [
            overlay_view(selected_discussion.model, discussion, declarations)
            |> element.map(map_discussion_msg(_, selected_discussion)),
          ])
        False -> element.fragment([])
      }
    option.None -> element.fragment([])
  }
}

fn map_discussion_msg(msg, selected_discussion: DiscussionReference) {
  UserUpdatedDiscussion(
    selected_discussion.discussion_id,
    update: update(selected_discussion.model, msg),
  )
}

// Discussion Node -------------------------------------------------------------

fn split_lines(nodes, indent indent) {
  let #(current_line, block_lines) =
    list.fold(nodes, #([], []), fn(acc, node) {
      let #(current_line, block_lines) = acc

      case node {
        preprocessor.FormatterNewline -> #([], [
          case indent {
            True -> [preprocessor.FormatterIndent, ..list.reverse(current_line)]
            False -> list.reverse(current_line)
          },
          ..block_lines
        ])
        preprocessor.FormatterBlock(nodes) -> #(
          [],
          list.append(split_lines(nodes, indent: True), block_lines),
        )

        _ -> #([node, ..current_line], block_lines)
      }
    })

  [
    case indent {
      True -> [preprocessor.FormatterIndent, ..list.reverse(current_line)]
      False -> list.reverse(current_line)
    },
    ..block_lines
  ]
}

fn get_signature_line_topic_id(
  line_nodes: List(preprocessor.PreProcessedNode),
  suppress_declaration,
) {
  let topic_count =
    list.count(line_nodes, fn(node) {
      case node {
        preprocessor.PreProcessedDeclaration(..) -> !suppress_declaration
        preprocessor.PreProcessedReference(..) -> True
        _ -> False
      }
    })

  case topic_count == 1 {
    True -> {
      let assert Ok(topic_id) =
        list.find_map(line_nodes, fn(node) {
          case node {
            preprocessor.PreProcessedDeclaration(topic_id, ..)
            | preprocessor.PreProcessedReference(topic_id, ..) -> Ok(topic_id)
            _ -> Error(Nil)
          }
        })
      option.Some(topic_id)
    }
    False -> option.None
  }
}

pub fn topic_signature_view(
  view_id view_id: List(String),
  signature signature: List(preprocessor.PreProcessedNode),
  declarations declarations: dict.Dict(String, preprocessor.Declaration),
  discussion discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  suppress_declaration suppress_declaration: Bool,
  line_number_offset line_number_offset: Int,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) -> List(element.Element(DiscussionControllerMsg)) {
  split_lines(signature, indent: False)
  |> list.fold(#(line_number_offset, []), fn(acc, rendered_line_nodes) {
    let #(line_number_offset, rendered_lines) = acc
    let new_line_number = line_number_offset + 1

    let indent_num = case rendered_line_nodes {
      [preprocessor.FormatterIndent, ..] -> 2
      _ -> 0
    }

    let #(_col_index, new_line) =
      rendered_line_nodes
      |> list.map_fold(0, fn(column_number, node) {
        case node {
          preprocessor.PreProcessedDeclaration(topic_id:, tokens:) -> {
            let new_column_number = case suppress_declaration {
              True -> column_number
              False -> column_number + 1
            }

            let rendered_node =
              node_view(
                topic_id:,
                tokens:,
                discussion:,
                declarations:,
                discussion_id: DiscussionId(
                  view_id:,
                  line_number: new_line_number,
                  column_number: new_column_number,
                ),
                selected_discussion:,
                node_view_kind: DeclarationView,
              )

            #(new_column_number, rendered_node)
          }

          preprocessor.PreProcessedReference(topic_id:, tokens:) -> {
            let new_column_number = column_number + 1

            let rendered_node =
              node_view(
                topic_id:,
                tokens:,
                discussion:,
                declarations:,
                discussion_id: DiscussionId(
                  view_id:,
                  line_number: new_line_number,
                  column_number: new_column_number,
                ),
                selected_discussion:,
                node_view_kind: ReferenceView,
              )

            #(new_column_number, rendered_node)
          }

          preprocessor.PreProcessedNode(element:)
          | preprocessor.PreProcessedGapNode(element:, ..) -> #(
            column_number,
            element.fragment([
              element.unsafe_raw_html("preprocessed-node", "span", [], element),
            ]),
          )

          preprocessor.FormatterIndent -> #(
            column_number,
            html.span([], [html.text("\u{a0}\u{a0}")]),
          )

          preprocessor.FormatterNewline | preprocessor.FormatterBlock(..) -> #(
            column_number,
            element.fragment([]),
          )
        }
      })

    let line_topic_id =
      get_signature_line_topic_id(rendered_line_nodes, suppress_declaration)

    let #(_, info_notes) = case line_topic_id {
      option.Some(line_topic_id) ->
        formatter.get_notes(discussion, indent_num, line_topic_id)
      option.None -> #([], [])
    }

    let new_line = [
      element.fragment(
        list.map(info_notes, fn(note) {
          let #(_note_index_id, note_message) = note
          html.p([attribute.class("comment italic")], [
            html.text(string.repeat("\u{a0}", indent_num) <> note_message),
          ])
        }),
      ),
      ..new_line
    ]

    #(new_line_number, [new_line, ..rendered_lines])
  })
  |> pair.second
  |> list.intersperse([html.br([])])
  |> list.flatten
}

pub type NodeViewKind {
  ReferenceView
  DeclarationView
  NewDiscussionPreview
  CommentPreview
}

pub fn node_view(
  topic_id topic_id: String,
  tokens tokens: String,
  discussion discussion,
  declarations declarations,
  discussion_id discussion_id,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
  node_view_kind node_view_kind: NodeViewKind,
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
        selected_discussion:,
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
    attribute.id(preprocessor.declaration_kind_to_string(node_declaration.kind)),
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
    event.on_blur(UserUnselectedDiscussionEntry(kind: Focus)),
    event.on_mouse_enter(UserSelectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
      node_id: option.Some(node_declaration.id),
      topic_id:,
      is_reference: False,
    )),
    event.on_mouse_leave(UserUnselectedDiscussionEntry(kind: Hover)),
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
    event.on_blur(UserUnselectedDiscussionEntry(kind: Focus)),
    event.on_mouse_enter(UserSelectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
      node_id: option.Some(node_declaration.id),
      topic_id:,
      is_reference: True,
    )),
    event.on_mouse_leave(UserUnselectedDiscussionEntry(kind: Hover)),
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
    event.on_blur(UserUnselectedDiscussionEntry(kind: Focus)),
    event.on_mouse_enter(UserSelectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
      node_id: option.None,
      topic_id:,
      is_reference: False,
    )),
    event.on_mouse_leave(UserUnselectedDiscussionEntry(kind: Hover)),
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
    event.on_blur(UserUnselectedDiscussionEntry(kind: Focus)),
    event.on_mouse_enter(UserSelectedDiscussionEntry(
      kind: Hover,
      discussion_id:,
      node_id: option.None,
      topic_id:,
      is_reference: False,
    )),
    event.on_mouse_leave(UserUnselectedDiscussionEntry(kind: Hover)),
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
    view_id: List(String),
    discussion_id: DiscussionId,
    current_note_draft: String,
    current_thread_id: String,
    active_thread: option.Option(ActiveThread),
    show_expanded_message_box: Bool,
    current_expanded_message_draft: option.Option(String),
    expanded_messages: set.Set(String),
    editing_note: option.Option(computed_note.ComputedNote),
    declarations: dict.Dict(String, preprocessor.Declaration),
    selected_discussion: option.Option(DiscussionId),
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
  view_id view_id: List(String),
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
    declarations: todo,
    selected_discussion: option.None,
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
}

pub type DiscussionOverlayEffect {
  SubmitNote(note: note.NoteSubmission, topic_id: String)
  FocusDiscussionInput(discussion_id: DiscussionId)
  FocusExpandedDiscussionInput(discussion_id: DiscussionId)
  UnfocusDiscussionInput(discussion_id: DiscussionId)
  MaximizeDiscussion(discussion_id: DiscussionId)
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

      let referenced_topic_ids =
        preprocessor.get_references(message, with: model.declarations)
        |> list.append(case expanded_message {
          option.Some(expanded_message) ->
            preprocessor.get_references(
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
  }
}

pub fn overlay_view(
  model: DiscussionOverlayModel,
  notes: dict.Dict(String, List(computed_note.ComputedNote)),
  declarations: dict.Dict(String, preprocessor.Declaration),
) {
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
            reference_header_view(model, current_thread_notes, notes),
          ])
        False ->
          element.fragment([
            html.div([attribute.class("overlay p-[.5rem]")], [
              thread_header_view(model, references, notes),
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

pub fn panel_view(model: DiscussionOverlayModel, notes, references) {
  let current_thread_notes =
    dict.get(notes, model.current_thread_id)
    |> result.unwrap([])

  html.div([attribute.style("padding", ".5rem")], [
    case model.is_reference {
      True -> reference_header_view(model, current_thread_notes, notes)
      False -> element.fragment([])
    },
    thread_header_view(model, references, notes),
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
  current_thread_notes,
  notes,
) {
  element.fragment([
    html.div(
      [
        attribute.class(
          "flex items-start justify-between width-full mb-[.5rem]",
        ),
      ],
      [
        html.span(
          [attribute.class("pt-[.1rem]")],
          get_topic_title(model, notes),
        ),
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

fn thread_header_view(model: DiscussionOverlayModel, references, notes) {
  let declaration =
    dict.get(model.declarations, model.topic_id)
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
            html.span(
              [attribute.class("pt-[.1rem]")],
              get_topic_title(model, notes),
            ),
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

fn new_message_input_view(model: DiscussionOverlayModel, current_thread_notes) {
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

fn get_topic_title(model: DiscussionOverlayModel, notes) {
  case dict.get(model.declarations, model.topic_id) {
    Ok(dec) ->
      topic_signature_view(
        view_id: model.discussion_id.view_id,
        signature: dec.signature,
        declarations: model.declarations,
        discussion: notes,
        suppress_declaration: True,
        line_number_offset: 0,
        selected_discussion: todo,
      )
    Error(Nil) -> [html.span([], [html.text("unknown")])]
  }
  todo
}

pub fn view_id_to_string(view_id) {
  string.join(view_id, "-")
}
