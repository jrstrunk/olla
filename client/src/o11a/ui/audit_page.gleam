import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/pair
import gleam/result
import gleam/string
import lib/enumerate
import lib/eventx
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event
import o11a/attributes
import o11a/classes
import o11a/client/attributes as client_attributes
import o11a/computed_note
import o11a/declaration
import o11a/events
import o11a/note
import o11a/preprocessor
import o11a/ui/discussion

pub type DiscussionReference {
  DiscussionReference(
    line_number: Int,
    column_number: Int,
    model: discussion.Model,
  )
}

pub type Model {
  Model(
    page_path: String,
    preprocessed_source: List(preprocessor.PreProcessedLine),
    discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  )
}

pub type Msg(msg) {
  UserSelectedDiscussionEntry(
    kind: DiscussionSelectKind,
    line_number: Int,
    column_number: Int,
    node_id: option.Option(Int),
    topic_id: String,
    topic_title: String,
    is_reference: Bool,
  )
  UserUnselectedDiscussionEntry(kind: DiscussionSelectKind)
  UserClickedDiscussionEntry(line_number: Int, column_number: Int)
  UserCtrlClickedNode(uri: String)
  UserUpdatedDiscussion(
    line_number: Int,
    column_number: Int,
    update: #(discussion.Model, discussion.Effect),
  )
  UserClickedInsideDiscussion(line_number: Int, column_number: Int)
}

pub type DiscussionSelectKind {
  EntryHover
  EntryFocus
}

pub fn view(
  preprocessed_source preprocessed_source: List(preprocessor.PreProcessedLine),
  discussion discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  references references: dict.Dict(String, List(declaration.Reference)),
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  html.div(
    [
      attribute.id("audit-page"),
      attribute.class("code-snippet"),
      attribute.data("lc", preprocessed_source |> list.length |> int.to_string),
    ],
    list.map(preprocessed_source, loc_view(
      discussion,
      references,
      _,
      selected_discussion:,
    )),
  )
}

fn loc_view(
  discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  references,
  loc: preprocessor.PreProcessedLine,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  case loc.significance {
    preprocessor.EmptyLine -> {
      html.p([attribute.class("loc"), attribute.id(loc.line_tag)], [
        html.span([attribute.class("line-number code-extras relative")], [
          html.text(loc.line_number_text),
        ]),
        ..preprocessed_nodes_view(
          loc,
          selected_discussion:,
          discussion:,
          references:,
        )
      ])
    }

    preprocessor.SingleDeclarationLine(signature:, topic_id:) ->
      line_container_view(
        discussion:,
        references:,
        loc:,
        line_topic_id: topic_id,
        line_topic_title: signature,
        selected_discussion:,
      )

    preprocessor.NonEmptyLine(topic_id:) ->
      line_container_view(
        discussion:,
        references:,
        loc:,
        line_topic_id: topic_id,
        line_topic_title: loc.line_tag,
        selected_discussion:,
      )
  }
}

fn line_container_view(
  discussion discussion,
  references references,
  loc loc: preprocessor.PreProcessedLine,
  line_topic_id line_topic_id: String,
  line_topic_title line_topic_title: String,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  let #(parent_notes, info_notes) =
    get_notes(discussion, loc.leading_spaces, line_topic_id)

  let column_count = loc.columns + 1

  html.div(
    [
      attribute.id(loc.line_tag),
      attribute.class(classes.line_container),
      client_attributes.encode_column_count_data(column_count),
    ],
    [
      element.fragment({
        use #(_note_index_id, note_message), index <- list.index_map(info_notes)

        let child =
          html.p([attribute.class("loc flex")], [
            html.span([attribute.class("line-number code-extras relative")], [
              html.text(loc.line_number_text),
              html.span(
                [
                  attribute.class(
                    "absolute code-extras pl-[.1rem] pt-[.15rem] text-[.9rem]",
                  ),
                ],
                [html.text(enumerate.translate_number_to_letter(index + 1))],
              ),
            ]),
            html.span([attribute.class("comment italic")], [
              html.text(
                list.repeat(" ", loc.leading_spaces) |> string.join("")
                <> note_message,
              ),
            ]),
          ])

        child
      }),
      html.p([attribute.class("loc flex")], [
        html.span([attribute.class("line-number code-extras relative")], [
          html.text(loc.line_number_text),
        ]),
        element.fragment(preprocessed_nodes_view(
          loc,
          selected_discussion:,
          discussion:,
          references:,
        )),
        inline_comment_preview_view(
          parent_notes,
          topic_id: line_topic_id,
          topic_title: line_topic_title,
          element_line_number: loc.line_number,
          element_column_number: column_count,
          selected_discussion:,
          discussion:,
          references:,
        ),
      ]),
    ],
  )
}

fn inline_comment_preview_view(
  parent_notes: List(computed_note.ComputedNote),
  topic_id topic_id: String,
  topic_title topic_title: String,
  element_line_number element_line_number,
  element_column_number element_column_number,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
  discussion discussion,
  references references,
) {
  let note_result =
    list.find(parent_notes, fn(note) {
      note.significance != computed_note.Informational
    })

  case note_result {
    Ok(note) ->
      html.span(
        [
          attribute.class("relative"),
          attributes.encode_grid_location_data(
            element_line_number |> int.to_string,
            element_column_number |> int.to_string,
          ),
        ],
        [
          html.span(
            [
              attribute.class(
                "inline-comment font-code code-extras font-code fade-in",
              ),
              attribute.class("comment-preview"),
              attribute.class(classes.discussion_entry),
              attribute.attribute("tabindex", "0"),
              event.on_focus(UserSelectedDiscussionEntry(
                kind: EntryFocus,
                line_number: element_line_number,
                column_number: element_column_number,
                node_id: option.None,
                topic_id:,
                topic_title:,
                is_reference: False,
              )),
              event.on_blur(UserUnselectedDiscussionEntry(kind: EntryFocus)),
              event.on_mouse_enter(UserSelectedDiscussionEntry(
                kind: EntryHover,
                line_number: element_line_number,
                column_number: element_column_number,
                node_id: option.None,
                topic_id:,
                topic_title:,
                is_reference: False,
              )),
              event.on_mouse_leave(UserUnselectedDiscussionEntry(
                kind: EntryHover,
              )),
              eventx.on_non_ctrl_click(UserClickedDiscussionEntry(
                line_number: element_line_number,
                column_number: element_column_number,
              ))
                |> event.stop_propagation,
            ],
            [
              html.text(case string.length(note.message) > 40 {
                True -> note.message |> string.slice(0, length: 37) <> "..."
                False -> note.message |> string.slice(0, length: 40)
              }),
            ],
          ),
          discussion_view(
            [
              event.on_click(UserClickedInsideDiscussion(
                element_line_number,
                element_column_number,
              ))
              |> event.stop_propagation,
            ],
            element_line_number:,
            element_column_number:,
            selected_discussion:,
            discussion:,
            references:,
          ),
        ],
      )

    Error(Nil) ->
      html.span(
        [
          attribute.class("relative"),
          attributes.encode_grid_location_data(
            element_line_number |> int.to_string,
            element_column_number |> int.to_string,
          ),
        ],
        [
          html.span(
            [
              attribute.class("inline-comment font-code code-extras"),
              attribute.class("new-thread-preview"),
              attribute.class(classes.discussion_entry),
              attribute.attribute("tabindex", "0"),
              event.on_focus(UserSelectedDiscussionEntry(
                kind: EntryFocus,
                line_number: element_line_number,
                column_number: element_column_number,
                node_id: option.None,
                topic_id:,
                topic_title:,
                is_reference: False,
              )),
              event.on_blur(UserUnselectedDiscussionEntry(kind: EntryFocus)),
              event.on_mouse_enter(UserSelectedDiscussionEntry(
                kind: EntryHover,
                line_number: element_line_number,
                column_number: element_column_number,
                node_id: option.None,
                topic_id:,
                topic_title:,
                is_reference: False,
              )),
              event.on_mouse_leave(UserUnselectedDiscussionEntry(
                kind: EntryHover,
              )),
              eventx.on_non_ctrl_click(UserClickedDiscussionEntry(
                line_number: element_line_number,
                column_number: element_column_number,
              ))
                |> event.stop_propagation,
            ],
            [html.text("Start new thread")],
          ),
          discussion_view(
            [
              event.on_click(UserClickedInsideDiscussion(
                element_line_number,
                element_column_number,
              ))
              |> event.stop_propagation,
            ],
            element_line_number:,
            element_column_number:,
            selected_discussion:,
            discussion:,
            references:,
          ),
        ],
      )
  }
}

fn preprocessed_nodes_view(
  loc: preprocessor.PreProcessedLine,
  discussion discussion,
  references references,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  list.map_fold(loc.elements, 0, fn(index, element) {
    case element {
      preprocessor.PreProcessedDeclaration(node_id:, node_declaration:, tokens:) -> {
        let new_column_index = index + 1
        #(
          new_column_index,
          declaration_node_view(
            node_id,
            node_declaration,
            tokens,
            element_line_number: loc.line_number,
            element_column_number: new_column_index,
            selected_discussion:,
            discussion:,
            references:,
          ),
        )
      }

      preprocessor.PreProcessedReference(
        referenced_node_id:,
        referenced_node_declaration:,
        tokens:,
      ) -> {
        let new_column_index = index + 1
        #(
          new_column_index,
          reference_node_view(
            referenced_node_id,
            referenced_node_declaration,
            tokens,
            element_line_number: loc.line_number,
            element_column_number: new_column_index,
            selected_discussion:,
            discussion:,
            references:,
          ),
        )
      }

      preprocessor.PreProcessedNode(element:)
      | preprocessor.PreProcessedGapNode(element:, ..) -> #(
        index,
        element.unsafe_raw_html("preprocessed-node", "span", [], element),
      )
    }
  })
  |> pair.second
}

fn declaration_node_view(
  node_id,
  node_declaration: declaration.Declaration,
  tokens tokens: String,
  discussion discussion,
  references references,
  element_line_number element_line_number,
  element_column_number element_column_number,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  html.span(
    [
      attribute.class("relative"),
      attributes.encode_grid_location_data(
        element_line_number |> int.to_string,
        element_column_number |> int.to_string,
      ),
    ],
    [
      html.span(
        [
          attribute.id(declaration.declaration_to_id(node_declaration)),
          attribute.class(declaration.declaration_kind_to_string(
            node_declaration.kind,
          )),
          attribute.class("declaration-preview N" <> int.to_string(node_id)),
          attribute.class(classes.discussion_entry),
          attribute.class(classes.discussion_entry_hover),
          attribute.attribute("tabindex", "0"),
          event.on_focus(UserSelectedDiscussionEntry(
            kind: EntryFocus,
            line_number: element_line_number,
            column_number: element_column_number,
            node_id: option.Some(node_id),
            topic_id: node_declaration.topic_id,
            topic_title: node_declaration.signature,
            is_reference: False,
          )),
          event.on_blur(UserUnselectedDiscussionEntry(kind: EntryFocus)),
          event.on_mouse_enter(UserSelectedDiscussionEntry(
            kind: EntryHover,
            line_number: element_line_number,
            column_number: element_column_number,
            node_id: option.Some(node_id),
            topic_id: node_declaration.topic_id,
            topic_title: node_declaration.signature,
            is_reference: False,
          )),
          event.on_mouse_leave(UserUnselectedDiscussionEntry(kind: EntryHover)),
          event.on_click(UserClickedDiscussionEntry(
            line_number: element_line_number,
            column_number: element_column_number,
          ))
            |> event.stop_propagation,
        ],
        [html.text(tokens)],
      ),
      discussion_view(
        [
          event.on_click(UserClickedInsideDiscussion(
            element_line_number,
            element_column_number,
          ))
          |> event.stop_propagation,
        ],
        element_line_number:,
        element_column_number:,
        selected_discussion:,
        discussion:,
        references:,
      ),
    ],
  )
}

fn reference_node_view(
  referenced_node_id: Int,
  referenced_node_declaration: declaration.Declaration,
  tokens: String,
  discussion discussion,
  references references,
  element_line_number element_line_number,
  element_column_number element_column_number,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  html.span(
    [
      attribute.class("relative"),
      attributes.encode_grid_location_data(
        element_line_number |> int.to_string,
        element_column_number |> int.to_string,
      ),
    ],
    [
      html.span(
        [
          attribute.class(declaration.declaration_kind_to_string(
            referenced_node_declaration.kind,
          )),
          attribute.class(
            "reference-preview N" <> int.to_string(referenced_node_id),
          ),
          attribute.class(classes.discussion_entry),
          attribute.class(classes.discussion_entry_hover),
          attribute.attribute("tabindex", "0"),
          event.on_focus(UserSelectedDiscussionEntry(
            kind: EntryFocus,
            line_number: element_line_number,
            column_number: element_column_number,
            node_id: option.Some(referenced_node_id),
            topic_id: referenced_node_declaration.topic_id,
            topic_title: referenced_node_declaration.signature,
            is_reference: True,
          )),
          event.on_blur(UserUnselectedDiscussionEntry(kind: EntryFocus)),
          event.on_mouse_enter(UserSelectedDiscussionEntry(
            kind: EntryHover,
            line_number: element_line_number,
            column_number: element_column_number,
            node_id: option.Some(referenced_node_id),
            topic_id: referenced_node_declaration.topic_id,
            topic_title: referenced_node_declaration.signature,
            is_reference: True,
          )),
          event.on_mouse_leave(UserUnselectedDiscussionEntry(kind: EntryHover)),
          eventx.on_ctrl_click(
            ctrl_click: UserCtrlClickedNode(
              uri: declaration.declaration_to_link(referenced_node_declaration),
            ),
            non_ctrl_click: option.Some(UserClickedDiscussionEntry(
              line_number: element_line_number,
              column_number: element_column_number,
            )),
          )
            |> event.stop_propagation,
        ],
        [html.text(tokens)],
      ),
      discussion_view(
        [
          event.on_click(UserClickedInsideDiscussion(
            element_line_number,
            element_column_number,
          ))
          |> event.stop_propagation,
        ],
        discussion:,
        references:,
        element_line_number:,
        element_column_number:,
        selected_discussion:,
      ),
    ],
  )
}

fn discussion_view(
  attrs,
  discussion discussion,
  references references,
  element_line_number element_line_number,
  element_column_number element_column_number,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  case selected_discussion {
    option.Some(selected_discussion) ->
      case
        element_line_number == selected_discussion.line_number
        && element_column_number == selected_discussion.column_number
      {
        True ->
          html.div(attrs, [
            discussion.overlay_view(
              selected_discussion.model,
              discussion,
              references,
            )
            |> element.map(map_discussion_msg(_, selected_discussion)),
          ])
        False -> element.fragment([])
      }
    option.None -> element.fragment([])
  }
}

fn map_discussion_msg(msg, selected_discussion: DiscussionReference) {
  UserUpdatedDiscussion(
    line_number: selected_discussion.line_number,
    column_number: selected_discussion.column_number,
    update: discussion.update(selected_discussion.model, msg),
  )
}

fn get_notes(
  discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  leading_spaces leading_spaces,
  topic_id topic_id,
) {
  let parent_notes =
    dict.get(discussion, topic_id)
    |> result.unwrap([])
    |> list.filter_map(fn(note) {
      case note.parent_id == topic_id {
        True -> Ok(note)
        False -> Error(Nil)
      }
    })

  let info_notes =
    parent_notes
    |> list.filter(fn(computed_note) {
      computed_note.significance == computed_note.Informational
    })
    |> list.map(split_info_note(_, leading_spaces))
    |> list.flatten

  #(parent_notes, info_notes)
}

fn split_info_note(note: computed_note.ComputedNote, leading_spaces) {
  note.message
  |> split_info_comment(note.expanded_message != None, leading_spaces)
  |> list.index_map(fn(comment, index) {
    #(note.note_id <> int.to_string(index), comment)
  })
}

fn split_info_comment(
  comment: String,
  contains_expanded_message: Bool,
  leading_spaces,
) {
  let comment_length = string.length(comment)
  let columns_remaining = 80 - leading_spaces

  case comment_length <= columns_remaining {
    True -> [
      comment
      <> case contains_expanded_message {
        True -> "^"
        False -> ""
      },
    ]
    False -> {
      let backwards =
        string.slice(comment, 0, columns_remaining)
        |> string.reverse

      let in_limit_comment_length =
        backwards
        |> string.split_once(" ")
        |> result.unwrap(#("", backwards))
        |> pair.second
        |> string.length

      let rest =
        string.slice(
          comment,
          in_limit_comment_length + 1,
          length: comment_length,
        )

      [
        string.slice(comment, 0, in_limit_comment_length),
        ..split_info_comment(rest, contains_expanded_message, leading_spaces)
      ]
    }
  }
}

pub fn on_user_submitted_line_note(msg) {
  event.on(events.user_submitted_note, {
    use note <- decode.subfield(
      ["detail", "note"],
      note.note_submission_decoder(),
    )
    use topic_id <- decode.subfield(["detail", "topic_id"], decode.string)

    decode.success(msg(note, topic_id))
  })
}
