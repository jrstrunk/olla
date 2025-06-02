import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
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
import o11a/events
import o11a/note
import o11a/preprocessor
import o11a/ui/discussion
import o11a/ui/formatter

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
    view_id: String,
    line_number: Int,
    column_number: Int,
    node_id: option.Option(Int),
    topic_id: String,
    is_reference: Bool,
  )
  UserUnselectedDiscussionEntry(kind: DiscussionSelectKind)
  UserClickedDiscussionEntry(
    view_id: String,
    line_number: Int,
    column_number: Int,
  )
  UserCtrlClickedNode(uri: String)
  UserUpdatedDiscussion(
    view_id: String,
    line_number: Int,
    column_number: Int,
    update: #(discussion.Model, discussion.Effect),
  )
  UserClickedInsideDiscussion(
    view_id: String,
    line_number: Int,
    column_number: Int,
  )
  UserHoveredInsideDiscussion(
    view_id: String,
    line_number: Int,
    column_number: Int,
  )
  UserUnhoveredInsideDiscussion(
    view_id: String,
    line_number: Int,
    column_number: Int,
  )
}

pub type DiscussionSelectKind {
  EntryHover
  EntryFocus
}

pub fn view(
  page_path page_path: String,
  preprocessed_source preprocessed_source: List(preprocessor.PreProcessedLine),
  discussion discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  declarations declarations: dict.Dict(String, preprocessor.Declaration),
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  html.div(
    [
      attribute.id("audit-page"),
      attribute.class("code-snippet"),
      attribute.data("lc", preprocessed_source |> list.length |> int.to_string),
    ],
    list.map(preprocessed_source, loc_view(
      _,
      page_path,
      discussion:,
      declarations:,
      selected_discussion:,
    )),
  )
}

fn loc_view(
  loc: preprocessor.PreProcessedLine,
  page_path page_path: String,
  discussion discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  declarations declarations,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  case loc.significance {
    preprocessor.EmptyLine -> {
      html.p([attribute.class("loc"), attribute.id(loc.line_tag)], [
        html.span([attribute.class("line-number code-extras relative")], [
          html.text(loc.line_number_text),
        ]),
        ..preprocessed_nodes_view(
          page_path,
          loc,
          selected_discussion:,
          discussion:,
          declarations:,
        )
      ])
    }

    preprocessor.SingleDeclarationLine(topic_id:) ->
      line_container_view(
        page_path,
        discussion:,
        declarations:,
        loc:,
        line_topic_id: topic_id,
        selected_discussion:,
      )

    preprocessor.NonEmptyLine(topic_id:) ->
      line_container_view(
        page_path,
        discussion:,
        declarations:,
        loc:,
        line_topic_id: topic_id,
        selected_discussion:,
      )
  }
}

fn line_container_view(
  page_path page_path: String,
  discussion discussion,
  declarations declarations,
  loc loc: preprocessor.PreProcessedLine,
  line_topic_id line_topic_id: String,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  let #(parent_notes, info_notes) =
    formatter.get_notes(discussion, loc.leading_spaces, line_topic_id)

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
          page_path,
          loc,
          selected_discussion:,
          discussion:,
          declarations:,
        )),
        inline_comment_preview_view(
          page_path:,
          parent_notes:,
          topic_id: line_topic_id,
          element_line_number: loc.line_number,
          element_column_number: column_count,
          selected_discussion:,
          discussion:,
          declarations:,
        ),
      ]),
    ],
  )
}

fn inline_comment_preview_view(
  page_path page_path: String,
  parent_notes parent_notes: List(computed_note.ComputedNote),
  topic_id topic_id: String,
  element_line_number line_number,
  element_column_number column_number,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
  discussion discussion,
  declarations declarations,
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
            line_number |> int.to_string,
            column_number |> int.to_string,
          ),
          event.on_mouse_enter(UserHoveredInsideDiscussion(
            view_id: page_path,
            line_number:,
            column_number:,
          )),
          event.on_mouse_leave(UserUnhoveredInsideDiscussion(
            view_id: page_path,
            line_number:,
            column_number:,
          )),
        ],
        [
          html.span(
            [
              attribute.class(
                "inline-comment font-code code-extras font-code fade-in",
              ),
              attribute.class("comment-preview"),
              attribute.class(classes.discussion_entry),
              attribute.class(topic_id),
              attribute.attribute("tabindex", "0"),
              event.on_focus(UserSelectedDiscussionEntry(
                kind: EntryFocus,
                view_id: page_path,
                line_number:,
                column_number:,
                node_id: option.None,
                topic_id:,
                is_reference: False,
              )),
              event.on_blur(UserUnselectedDiscussionEntry(kind: EntryFocus)),
              event.on_mouse_enter(UserSelectedDiscussionEntry(
                kind: EntryHover,
                view_id: page_path,
                line_number:,
                column_number:,
                node_id: option.None,
                topic_id:,
                is_reference: False,
              )),
              event.on_mouse_leave(UserUnselectedDiscussionEntry(
                kind: EntryHover,
              )),
              eventx.on_non_ctrl_click(UserClickedDiscussionEntry(
                view_id: page_path,
                line_number:,
                column_number:,
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
                view_id: page_path,
                line_number:,
                column_number:,
              ))
              |> event.stop_propagation,
            ],
            line_number:,
            column_number:,
            selected_discussion:,
            discussion:,
            declarations:,
          ),
        ],
      )

    Error(Nil) ->
      html.span(
        [
          attribute.class("relative"),
          attributes.encode_grid_location_data(
            line_number |> int.to_string,
            column_number |> int.to_string,
          ),
          event.on_mouse_enter(UserHoveredInsideDiscussion(
            view_id: page_path,
            line_number:,
            column_number:,
          )),
          event.on_mouse_leave(UserUnhoveredInsideDiscussion(
            view_id: page_path,
            line_number:,
            column_number:,
          )),
        ],
        [
          html.span(
            [
              attribute.class("inline-comment font-code code-extras"),
              attribute.class("new-thread-preview"),
              attribute.class(classes.discussion_entry),
              attribute.class(topic_id),
              attribute.attribute("tabindex", "0"),
              event.on_focus(UserSelectedDiscussionEntry(
                kind: EntryFocus,
                view_id: page_path,
                line_number:,
                column_number:,
                node_id: option.None,
                topic_id:,
                is_reference: False,
              )),
              event.on_blur(UserUnselectedDiscussionEntry(kind: EntryFocus)),
              event.on_mouse_enter(UserSelectedDiscussionEntry(
                kind: EntryHover,
                view_id: page_path,
                line_number:,
                column_number:,
                node_id: option.None,
                topic_id:,
                is_reference: False,
              )),
              event.on_mouse_leave(UserUnselectedDiscussionEntry(
                kind: EntryHover,
              )),
              eventx.on_non_ctrl_click(UserClickedDiscussionEntry(
                view_id: page_path,
                line_number:,
                column_number:,
              ))
                |> event.stop_propagation,
            ],
            [html.text("Start new thread")],
          ),
          discussion_view(
            [
              event.on_click(UserClickedInsideDiscussion(
                view_id: page_path,
                line_number:,
                column_number:,
              ))
              |> event.stop_propagation,
            ],
            line_number:,
            column_number:,
            selected_discussion:,
            discussion:,
            declarations:,
          ),
        ],
      )
  }
}

fn preprocessed_nodes_view(
  page_path: String,
  loc: preprocessor.PreProcessedLine,
  discussion discussion,
  declarations declarations,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  list.map_fold(loc.elements, 0, fn(index, element) {
    case element {
      preprocessor.PreProcessedDeclaration(topic_id:, tokens:) -> {
        let new_column_index = index + 1
        #(
          new_column_index,
          declaration_node_view(
            page_path:,
            topic_id:,
            tokens:,
            element_line_number: loc.line_number,
            element_column_number: new_column_index,
            selected_discussion:,
            discussion:,
            declarations:,
          ),
        )
      }

      preprocessor.PreProcessedReference(topic_id:, tokens:) -> {
        let new_column_index = index + 1
        #(
          new_column_index,
          reference_node_view(
            page_path:,
            topic_id:,
            tokens:,
            element_line_number: loc.line_number,
            element_column_number: new_column_index,
            selected_discussion:,
            discussion:,
            declarations:,
          ),
        )
      }

      preprocessor.PreProcessedNode(element:)
      | preprocessor.PreProcessedGapNode(element:, ..) -> #(
        index,
        element.unsafe_raw_html("preprocessed-node", "span", [], element),
      )

      preprocessor.FormatterNewline | preprocessor.FormatterBlock(..) -> #(
        index,
        element.fragment([]),
      )
    }
  })
  |> pair.second
}

fn declaration_node_view(
  page_path page_path: String,
  topic_id topic_id: String,
  tokens tokens: String,
  discussion discussion,
  declarations declarations,
  element_line_number line_number,
  element_column_number column_number,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  let node_declaration =
    dict.get(declarations, topic_id)
    |> result.unwrap(preprocessor.unknown_declaration)

  html.span(
    [
      attribute.class("relative"),
      attributes.encode_grid_location_data(
        line_number |> int.to_string,
        column_number |> int.to_string,
      ),
      event.on_mouse_enter(UserHoveredInsideDiscussion(
        view_id: page_path,
        line_number:,
        column_number:,
      )),
      event.on_mouse_leave(UserUnhoveredInsideDiscussion(
        view_id: page_path,
        line_number:,
        column_number:,
      )),
    ],
    [
      html.span(
        [
          attribute.id(preprocessor.declaration_to_id(node_declaration)),
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
            kind: EntryFocus,
            view_id: page_path,
            line_number:,
            column_number:,
            node_id: option.Some(node_declaration.id),
            topic_id: topic_id,
            is_reference: False,
          )),
          event.on_blur(UserUnselectedDiscussionEntry(kind: EntryFocus)),
          event.on_mouse_enter(UserSelectedDiscussionEntry(
            kind: EntryHover,
            view_id: page_path,
            line_number:,
            column_number:,
            node_id: option.Some(node_declaration.id),
            topic_id: topic_id,
            is_reference: False,
          )),
          event.on_mouse_leave(UserUnselectedDiscussionEntry(kind: EntryHover)),
          event.on_click(UserClickedDiscussionEntry(
            view_id: page_path,
            line_number:,
            column_number:,
          ))
            |> event.stop_propagation,
        ],
        [html.text(tokens)],
      ),
      discussion_view(
        [
          event.on_click(UserClickedInsideDiscussion(
            view_id: page_path,
            line_number:,
            column_number:,
          ))
          |> event.stop_propagation,
        ],
        line_number: line_number,
        column_number: column_number,
        selected_discussion:,
        discussion:,
        declarations:,
      ),
    ],
  )
}

fn reference_node_view(
  page_path page_path: String,
  topic_id topic_id: String,
  tokens tokens: String,
  discussion discussion,
  declarations declarations,
  element_line_number line_number,
  element_column_number column_number,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  let referenced_node_declaration =
    dict.get(declarations, topic_id)
    |> result.unwrap(preprocessor.unknown_declaration)

  html.span(
    [
      attribute.class("relative"),
      attributes.encode_grid_location_data(
        line_number |> int.to_string,
        column_number |> int.to_string,
      ),
      event.on_mouse_enter(UserHoveredInsideDiscussion(
        view_id: page_path,
        line_number:,
        column_number:,
      )),
      event.on_mouse_leave(UserUnhoveredInsideDiscussion(
        view_id: page_path,
        line_number:,
        column_number:,
      )),
    ],
    [
      html.span(
        [
          attribute.class(preprocessor.declaration_kind_to_string(
            referenced_node_declaration.kind,
          )),
          attribute.class(
            "reference-preview N"
            <> int.to_string(referenced_node_declaration.id),
          ),
          attribute.class(classes.discussion_entry),
          attribute.class(classes.discussion_entry_hover),
          attribute.attribute("tabindex", "0"),
          event.on_focus(UserSelectedDiscussionEntry(
            kind: EntryFocus,
            view_id: page_path,
            line_number:,
            column_number:,
            node_id: option.Some(referenced_node_declaration.id),
            topic_id:,
            is_reference: True,
          )),
          event.on_blur(UserUnselectedDiscussionEntry(kind: EntryFocus)),
          event.on_mouse_enter(UserSelectedDiscussionEntry(
            kind: EntryHover,
            view_id: page_path,
            line_number:,
            column_number:,
            node_id: option.Some(referenced_node_declaration.id),
            topic_id:,
            is_reference: True,
          )),
          event.on_mouse_leave(UserUnselectedDiscussionEntry(kind: EntryHover)),
          eventx.on_ctrl_click(
            ctrl_click: UserCtrlClickedNode(
              uri: preprocessor.declaration_to_link(referenced_node_declaration),
            ),
            non_ctrl_click: option.Some(UserClickedDiscussionEntry(
              view_id: page_path,
              line_number:,
              column_number:,
            )),
          )
            |> event.stop_propagation,
        ],
        [html.text(tokens)],
      ),
      discussion_view(
        [
          event.on_click(UserClickedInsideDiscussion(
            view_id: page_path,
            line_number:,
            column_number:,
          ))
          |> event.stop_propagation,
        ],
        discussion:,
        declarations:,
        line_number:,
        column_number:,
        selected_discussion:,
      ),
    ],
  )
}

fn discussion_view(
  attrs,
  discussion discussion,
  declarations declarations,
  line_number line_number,
  column_number column_number,
  selected_discussion selected_discussion: option.Option(DiscussionReference),
) {
  case selected_discussion {
    option.Some(selected_discussion) ->
      case
        line_number == selected_discussion.line_number
        && column_number == selected_discussion.column_number
      {
        True ->
          html.div(attrs, [
            discussion.overlay_view(
              selected_discussion.model,
              discussion,
              declarations,
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
    view_id: selected_discussion.model.view_id,
    line_number: selected_discussion.line_number,
    column_number: selected_discussion.column_number,
    update: discussion.update(selected_discussion.model, msg),
  )
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
