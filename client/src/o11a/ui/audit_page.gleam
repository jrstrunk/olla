import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/string
import lib/enumerate
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event
import o11a/classes
import o11a/client/attributes as client_attributes
import o11a/computed_note
import o11a/events
import o11a/note
import o11a/preprocessor
import o11a/ui/discussion
import o11a/ui/formatter

pub const view_id = "audit-page"

pub type Model {
  Model(
    page_path: String,
    preprocessed_source: List(preprocessor.PreProcessedLine),
    discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  )
}

pub fn view(
  preprocessed_source preprocessed_source: List(preprocessor.PreProcessedLine),
  discussion discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  declarations declarations: dict.Dict(String, preprocessor.Declaration),
  discussion_context discussion_context,
) {
  let active_discussion =
    discussion.get_active_discussion_reference(view_id, discussion_context)

  html.div(
    [
      attribute.id(view_id),
      attribute.class("code-snippet"),
      attribute.data("lc", preprocessed_source |> list.length |> int.to_string),
      event.on_click(discussion.UserClickedOutsideDiscussion(view_id:)),
    ],
    list.map(preprocessed_source, loc_view(
      _,
      discussion:,
      declarations:,
      active_discussion:,
      discussion_context:,
    )),
  )
}

fn loc_view(
  loc: preprocessor.PreProcessedLine,
  discussion discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  declarations declarations,
  active_discussion active_discussion: option.Option(
    discussion.DiscussionReference,
  ),
  discussion_context discussion_context,
) {
  case loc.significance {
    preprocessor.EmptyLine -> {
      html.p([attribute.class("loc"), attribute.id(loc.line_tag)], [
        html.span([attribute.class("line-number code-extras relative")], [
          html.text(loc.line_number_text),
        ]),
        ..preprocessed_nodes_view(
          loc,
          active_discussion:,
          discussion:,
          declarations:,
          discussion_context:,
        )
      ])
    }

    preprocessor.SingleDeclarationLine(topic_id:) ->
      line_container_view(
        discussion:,
        declarations:,
        loc:,
        line_topic_id: topic_id,
        active_discussion:,
        discussion_context:,
      )

    preprocessor.NonEmptyLine(topic_id:) ->
      line_container_view(
        discussion:,
        declarations:,
        loc:,
        line_topic_id: topic_id,
        active_discussion:,
        discussion_context:,
      )
  }
}

fn line_container_view(
  discussion discussion,
  declarations declarations,
  loc loc: preprocessor.PreProcessedLine,
  line_topic_id line_topic_id: String,
  active_discussion active_discussion: option.Option(
    discussion.DiscussionReference,
  ),
  discussion_context discussion_context,
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
          loc,
          active_discussion:,
          discussion:,
          declarations:,
          discussion_context:,
        )),
        inline_comment_preview_view(
          parent_notes:,
          topic_id: line_topic_id,
          element_line_number: loc.line_number,
          element_column_number: column_count,
          active_discussion:,
          discussion_context:,
          discussion:,
          declarations:,
        ),
      ]),
    ],
  )
}

fn inline_comment_preview_view(
  parent_notes parent_notes: List(computed_note.ComputedNote),
  topic_id topic_id: String,
  element_line_number line_number,
  element_column_number column_number,
  active_discussion active_discussion: option.Option(
    discussion.DiscussionReference,
  ),
  discussion_context discussion_context,
  discussion discussion,
  declarations declarations,
) {
  let note_result =
    // This operation is expensive and it happens every line on the page, maybe
    // we should calculate this in the update function and pass it in
    list.find(parent_notes, fn(note) {
      note.significance != computed_note.Informational
    })

  case note_result {
    Ok(note) ->
      discussion.node_with_discussion_view(
        topic_id:,
        tokens: case string.length(note.message) > 40 {
          True -> note.message |> string.slice(0, length: 37) <> "⋯"
          False -> note.message |> string.slice(0, length: 40)
        },
        discussion:,
        declarations:,
        discussion_id: discussion.DiscussionId(
          view_id:,
          line_number:,
          column_number:,
        ),
        active_discussion:,
        discussion_context:,
        node_view_kind: discussion.CommentPreview,
      )

    Error(Nil) ->
      discussion.node_with_discussion_view(
        topic_id:,
        tokens: "Start new thread",
        discussion:,
        declarations:,
        discussion_id: discussion.DiscussionId(
          view_id:,
          line_number:,
          column_number:,
        ),
        active_discussion:,
        discussion_context:,
        node_view_kind: discussion.NewDiscussionPreview,
      )
  }
}

fn preprocessed_nodes_view(
  loc: preprocessor.PreProcessedLine,
  discussion discussion,
  declarations declarations,
  active_discussion active_discussion: option.Option(
    discussion.DiscussionReference,
  ),
  discussion_context discussion_context,
) {
  list.map_fold(loc.elements, 0, fn(index, element) {
    case element {
      preprocessor.PreProcessedDeclaration(topic_id:, tokens:) -> {
        let new_column_index = index + 1
        #(
          new_column_index,
          discussion.node_with_discussion_view(
            topic_id:,
            tokens:,
            discussion_id: discussion.DiscussionId(
              view_id:,
              line_number: loc.line_number,
              column_number: new_column_index,
            ),
            active_discussion:,
            discussion_context:,
            discussion:,
            declarations:,
            node_view_kind: discussion.DeclarationView,
          ),
        )
      }

      preprocessor.PreProcessedReference(topic_id:, tokens:) -> {
        let new_column_index = index + 1
        #(
          new_column_index,
          discussion.node_with_discussion_view(
            topic_id:,
            tokens:,
            discussion_id: discussion.DiscussionId(
              view_id:,
              line_number: loc.line_number,
              column_number: new_column_index,
            ),
            active_discussion:,
            discussion_context:,
            discussion:,
            declarations:,
            node_view_kind: discussion.ReferenceView,
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
