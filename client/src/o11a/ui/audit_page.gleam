import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{None}
import gleam/pair
import gleam/result
import gleam/string
import lib/enumerate
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

pub type Model {
  Model(
    page_path: String,
    preprocessed_source: List(preprocessor.PreProcessedLine),
    discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  )
}

// pub fn init(init_model: Model) -> #(Model, effect.Effect(Msg)) {
//   // todo move this to a lustre event listener on the discussion component in
//   // the client controller app
//   let subscribe_to_discussion_updates_effect =
//     effect.from(fn(dispatch) {
//       window.add_event_listener(events.server_updated_discussion, fn(event) {
//         let res = {
//           use detail <- result.try(
//             // browser_event.detail(event)
//             Error(Nil)
//             |> result.replace_error(snag.new("Failed to get detail")),
//           )

//           use detail <- result.try(
//             decode.run(detail, decode.string)
//             |> snag.map_error(string.inspect)
//             |> snag.context("Failed to decode detail"),
//           )

//           use discussion <- result.try(
//             json.parse(
//               detail,
//               decode.list(computed_note.computed_note_decoder()),
//             )
//             |> snag.map_error(string.inspect)
//             |> snag.context("Failed to parse discussion"),
//           )

//           let discussion =
//             list.group(discussion, by: fn(note) { note.parent_id })

//           dispatch(ServerUpdatedDiscussion(discussion:))

//           Ok(Nil)
//         }

//         case res {
//           Ok(Nil) -> Nil
//           Error(e) -> io.println(snag.line_print(e))
//         }
//       })
//     })

//   #(init_model, subscribe_to_discussion_updates_effect)
// }

// pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
//   case msg {
//     ServerUpdatedDiscussion(discussion:) -> #(
//       Model(..model, discussion:),
//       effect.none(),
//     )
//   }
// }

pub fn view(
  preprocessed_source preprocessed_source: List(preprocessor.PreProcessedLine),
  discussion discussion: dict.Dict(String, List(computed_note.ComputedNote)),
) -> element.Element(msg) {
  html.div(
    [
      attribute.id("audit-page"),
      attribute.class("code-snippet"),
      attribute.data("lc", preprocessed_source |> list.length |> int.to_string),
    ],
    list.map(preprocessed_source, loc_view(discussion, _)),
  )
}

fn loc_view(
  discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  loc: preprocessor.PreProcessedLine,
) {
  case loc.significance {
    preprocessor.EmptyLine -> {
      html.p([attribute.class("loc"), attribute.id(loc.line_tag)], [
        html.span([attribute.class("line-number code-extras")], [
          html.text(loc.line_number_text),
        ]),
        ..preprocessed_nodes_view(loc)
      ])
    }

    preprocessor.SingleDeclarationLine(topic_id: decl_topic_id) ->
      line_container_view(discussion:, loc:, line_topic_id: decl_topic_id)

    preprocessor.NonEmptyLine ->
      line_container_view(discussion:, loc:, line_topic_id: loc.line_id)
  }
}

fn line_container_view(
  discussion discussion,
  loc loc: preprocessor.PreProcessedLine,
  line_topic_id line_topic_id: String,
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
      element.keyed(element.fragment, {
        use #(note_index_id, note_message), index <- list.index_map(info_notes)

        let child =
          html.p([attribute.class("loc flex")], [
            html.span(
              [attribute.class("line-number code-extras relative italic")],
              [
                html.text(loc.line_number_text),
                html.span(
                  [
                    attribute.class(
                      "absolute code-extras pl-[.1rem] pt-[.15rem] text-[.9rem]",
                    ),
                  ],
                  [html.text(enumerate.translate_number_to_letter(index + 1))],
                ),
              ],
            ),
            html.span([attribute.class("comment italic")], [
              html.text(
                list.repeat(" ", loc.leading_spaces) |> string.join("")
                <> note_message,
              ),
            ]),
          ])

        #(note_index_id, child)
      }),
      html.p([attribute.class("loc flex")], [
        html.span([attribute.class("line-number code-extras")], [
          html.text(loc.line_number_text),
        ]),
        element.fragment(preprocessed_nodes_view(loc)),
        inline_comment_preview_view(
          parent_notes,
          loc.line_number_text,
          int.to_string(column_count),
        ),
      ]),
    ],
  )
}

fn inline_comment_preview_view(
  parent_notes: List(computed_note.ComputedNote),
  line_number,
  column_number,
) {
  let note_result =
    list.reverse(parent_notes)
    |> list.find(fn(note) { note.significance != computed_note.Informational })

  case note_result {
    Ok(note) ->
      html.span(
        [
          attribute.class(
            "inline-comment relative font-code code-extras font-code fade-in",
          ),
          attribute.class("comment-preview"),
          attribute.class(classes.discussion_entry),
          attribute.attribute("tabindex", "0"),
          attributes.encode_grid_location_data(line_number, column_number),
        ],
        [
          html.text(case string.length(note.message) > 40 {
            True -> note.message |> string.slice(0, length: 37) <> "..."
            False -> note.message |> string.slice(0, length: 40)
          }),
        ],
      )

    Error(Nil) ->
      html.span(
        [
          attribute.class("inline-comment relative font-code code-extras"),
          attribute.class("new-thread-preview"),
          attribute.class(classes.discussion_entry),
          attribute.attribute("tabindex", "0"),
          attributes.encode_grid_location_data(line_number, column_number),
        ],
        [html.text("Start new thread")],
      )
  }
}

fn preprocessed_nodes_view(loc: preprocessor.PreProcessedLine) {
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
            loc.line_number_text,
            int.to_string(new_column_index),
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
            loc.line_number_text,
            int.to_string(new_column_index),
          ),
        )
      }

      preprocessor.PreProcessedNode(element:)
      | preprocessor.PreProcessedGapNode(element:, ..) -> #(
        index,
        html.span(
          [attribute.attribute("dangerous-unescaped-html", element)],
          [],
        ),
      )
    }
  })
  |> pair.second
}

fn declaration_node_view(
  node_id,
  node_declaration: preprocessor.NodeDeclaration,
  tokens tokens: String,
  line_number line_number,
  column_number column_number,
) {
  html.span(
    [
      attribute.id(node_declaration.topic_id),
      attribute.class(preprocessor.node_declaration_kind_to_string(
        node_declaration.kind,
      )),
      attribute.class("declaration-preview N" <> int.to_string(node_id)),
      attribute.class(classes.discussion_entry),
      attribute.class(classes.discussion_entry_hover),
      attribute.attribute("tabindex", "0"),
      attributes.encode_grid_location_data(line_number, column_number),
      attributes.encode_topic_id_data(node_declaration.topic_id),
      attributes.encode_topic_title_data(node_declaration.title),
      attributes.encode_is_reference_data(False),
    ],
    [html.text(tokens)],
  )
}

fn reference_node_view(
  referenced_node_id: Int,
  referenced_node_declaration: preprocessor.NodeDeclaration,
  tokens: String,
  line_number line_number,
  column_number column_number,
) {
  html.span(
    [
      attribute.class(preprocessor.node_declaration_kind_to_string(
        referenced_node_declaration.kind,
      )),
      attribute.class(
        "reference-preview N" <> int.to_string(referenced_node_id),
      ),
      attribute.class(classes.discussion_entry),
      attribute.class(classes.discussion_entry_hover),
      attribute.attribute("tabindex", "0"),
      attributes.encode_grid_location_data(line_number, column_number),
      attributes.encode_topic_id_data(referenced_node_declaration.topic_id),
      attributes.encode_topic_title_data(referenced_node_declaration.title),
      attributes.encode_is_reference_data(True),
    ],
    [html.text(tokens)],
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
  use event <- event.on(events.user_submitted_note)

  let empty_error = [dynamic.DecodeError("", "", [])]

  use note <- result.try(
    decode.run(
      event,
      decode.subfield(
        ["detail", "note"],
        note.note_submission_decoder(),
        decode.success,
      ),
    )
    |> result.replace_error(empty_error),
  )

  use topic_id <- result.try(
    decode.run(
      event,
      decode.subfield(["detail", "topic_id"], decode.string, decode.success),
    )
    |> result.replace_error(empty_error),
  )

  msg(note, topic_id)
  |> Ok
}
