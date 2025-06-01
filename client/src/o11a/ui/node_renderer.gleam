import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/computed_note
import o11a/preprocessor
import o11a/ui/formatter

type SignatureLine(msg) {
  SignatureLine(
    indent: String,
    indent_num: Int,
    nodes: List(preprocessor.PreProcessedNode),
  )
}

fn split_lines(nodes, indent indent) {
  let #(current_line, block_lines) =
    list.fold(nodes, #([], []), fn(acc, node) {
      let #(current_line, block_lines) = acc

      case node {
        preprocessor.FormatterNewline -> #([], [
          SignatureLine(
            indent: case indent {
              True -> "\u{a0}\u{a0}"
              False -> ""
            },
            indent_num: case indent {
              True -> 2
              False -> 0
            },
            nodes: current_line,
          ),
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
    SignatureLine(
      indent: case indent {
        True -> "\u{a0}\u{a0}"
        False -> ""
      },
      indent_num: case indent {
        True -> 2
        False -> 0
      },
      nodes: current_line,
    ),
    ..block_lines
  ]
}

fn get_signature_line_topic_id(line: SignatureLine(msg), suppress_declaration) {
  let topic_count =
    list.count(line.nodes, fn(node) {
      case node {
        preprocessor.PreProcessedDeclaration(..) -> !suppress_declaration
        preprocessor.PreProcessedReference(..) -> True
        _ -> False
      }
    })

  case topic_count == 1 {
    True -> {
      let assert Ok(topic_id) =
        list.find_map(line.nodes, fn(node) {
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

pub fn render_topic_signature(
  signature signature: List(preprocessor.PreProcessedNode),
  declarations declarations,
  discussion discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  suppress_declaration suppress_declaration: Bool,
) {
  split_lines(signature, indent: False)
  |> list.fold([], fn(rendered_lines, rendered_line) {
    let line_topic_id =
      get_signature_line_topic_id(rendered_line, suppress_declaration)

    let #(_, info_notes) = case line_topic_id {
      option.Some(line_topic_id) ->
        formatter.get_notes(discussion, rendered_line.indent_num, line_topic_id)
      option.None -> #([], [])
    }

    let new_line =
      rendered_line.nodes
      |> list.reverse
      |> list.map_fold(#(0, False), fn(index, node) {
        let #(index, indented) = index

        case node {
          preprocessor.PreProcessedDeclaration(topic_id:, tokens:) -> {
            let declaration =
              dict.get(declarations, topic_id)
              |> result.unwrap(preprocessor.unknown_declaration)

            let rendered_node =
              element.fragment([
                html.span([attribute.class("relative")], [
                  case indented {
                    True -> element.fragment([])
                    False -> html.text(rendered_line.indent)
                  },
                  html.span(
                    [
                      attribute.class(preprocessor.declaration_kind_to_string(
                        declaration.kind,
                      )),
                    ],
                    [html.text(tokens)],
                  ),
                ]),
              ])

            #(#(index, True), rendered_node)
          }

          preprocessor.PreProcessedReference(topic_id:, tokens:) -> {
            let new_index = index + 1

            let referenced_declaraion =
              dict.get(declarations, topic_id)
              |> result.unwrap(preprocessor.unknown_declaration)

            let rendered_node =
              html.span([attribute.class("relative")], [
                case indented {
                  True -> element.fragment([])
                  False -> html.text(rendered_line.indent)
                },
                html.span(
                  [
                    attribute.class(preprocessor.declaration_kind_to_string(
                      referenced_declaraion.kind,
                    )),
                    attribute.class(
                      "N" <> int.to_string(referenced_declaraion.id),
                    ),
                  ],
                  [html.text(tokens)],
                ),
              ])

            #(#(new_index, True), rendered_node)
          }

          preprocessor.PreProcessedNode(element:)
          | preprocessor.PreProcessedGapNode(element:, ..) -> #(
            #(index, True),
            element.fragment([
              case indented {
                True -> element.fragment([])
                False -> html.text(rendered_line.indent)
              },
              element.unsafe_raw_html("preprocessed-node", "span", [], element),
            ]),
          )

          preprocessor.FormatterNewline | preprocessor.FormatterBlock(..) -> #(
            #(index, indented),
            element.fragment([]),
          )
        }
      })
      |> pair.second

    let new_line = [
      element.fragment(
        list.map(info_notes, fn(note) {
          let #(_note_index_id, note_message) = note
          html.p([attribute.class("comment italic")], [
            html.text(rendered_line.indent <> note_message),
          ])
        }),
      ),
      ..new_line
    ]

    [new_line, ..rendered_lines]
  })
  |> list.intersperse([html.br([])])
  |> list.flatten
}
