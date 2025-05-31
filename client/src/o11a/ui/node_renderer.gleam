import gleam/dict
import gleam/int
import gleam/list
import gleam/pair
import gleam/result
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/preprocessor

type RenderedLine(msg) {
  RenderedLine(indent: String, nodes: List(preprocessor.PreProcessedNode))
}

fn split_lines(nodes, indent indent) {
  let #(current_line, block_lines) =
    list.fold(nodes, #([], []), fn(acc, node) {
      let #(current_line, block_lines) = acc

      case node {
        preprocessor.FormatterNewline -> #([], [
          RenderedLine(
            indent: case indent {
              True -> "\u{a0}\u{a0}"
              False -> ""
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
    RenderedLine(
      indent: case indent {
        True -> "\u{a0}\u{a0}"
        False -> ""
      },
      nodes: current_line,
    ),
    ..block_lines
  ]
}

pub fn render_topic_signature(
  signature signature: List(preprocessor.PreProcessedNode),
  declarations declarations,
) {
  split_lines(signature, indent: False)
  |> list.fold([], fn(rendered_lines, rendered_line) {
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

    [new_line, ..rendered_lines]
  })
  |> list.intersperse([html.br([])])
  |> list.flatten
}
