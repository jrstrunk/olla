import gleam/dict
import gleam/int
import gleam/list
import gleam/pair
import gleam/result
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/preprocessor

pub fn render_topic_signature(
  signature signatures: List(preprocessor.PreProcessedNode),
  declarations declarations,
) {
  list.map_fold(signatures, 0, fn(index, node) {
    case node {
      preprocessor.PreProcessedDeclaration(topic_id:, tokens:) -> {
        let declaration =
          dict.get(declarations, topic_id)
          |> result.unwrap(preprocessor.unknown_declaration)

        let rendered_node =
          html.span([attribute.class("relative")], [
            html.span(
              [
                attribute.class(preprocessor.declaration_kind_to_string(
                  declaration.kind,
                )),
              ],
              [html.text(tokens)],
            ),
          ])

        #(index, rendered_node)
      }

      preprocessor.PreProcessedReference(topic_id:, tokens:) -> {
        let new_index = index + 1

        let referenced_declaraion =
          dict.get(declarations, topic_id)
          |> result.unwrap(preprocessor.unknown_declaration)

        let rendered_node =
          html.span([attribute.class("relative")], [
            html.span(
              [
                attribute.class(preprocessor.declaration_kind_to_string(
                  referenced_declaraion.kind,
                )),
                attribute.class("N" <> int.to_string(referenced_declaraion.id)),
              ],
              [html.text(tokens)],
            ),
          ])

        #(new_index, rendered_node)
      }

      preprocessor.PreProcessedNode(element:)
      | preprocessor.PreProcessedGapNode(element:, ..) -> {
        #(
          index,
          element.unsafe_raw_html("preprocessed-node", "span", [], element),
        )
      }
    }
  })
  |> pair.second
}
