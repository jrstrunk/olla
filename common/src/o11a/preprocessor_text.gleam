import gleam/int
import gleam/list
import lib/djotx
import lustre/element
import o11a/preprocessor

pub fn preprocess_source(
  nodes nodes: List(djotx.Container),
  declarations declarations,
) {
  use line, index <- list.index_map(consume_source(nodes:, declarations:))

  let line_number = index + 1
  let line_number_text = int.to_string(line_number)
  let line_tag = "L" <> line_number_text
  let leading_spaces = 0

  // TODO: One day we could give a line its own topic id if it has more than
  // one statement in it, that way users could reference an entire paragraph,
  // table, list, or code block all at once. For now all line are "empty" so 
  // so they don't have their own topic id
  let significance = preprocessor.EmptyLine

  let columns =
    list.count(line, fn(node) {
      case node {
        preprocessor.PreProcessedDeclaration(..)
        | preprocessor.PreProcessedReference(..) -> True
        _ -> False
      }
    })

  preprocessor.PreProcessedLine(
    significance:,
    line_number:,
    line_number_text:,
    line_tag:,
    leading_spaces:,
    elements: line,
    columns:,
    kind: preprocessor.TextLine,
  )
}

fn consume_source(nodes nodes: List(djotx.Container), declarations declarations) {
  list.map(nodes, fn(node) {
    case node {
      djotx.ThematicBreak -> [preprocessor.PreProcessedNode(element: "<hr>")]
      djotx.Paragraph(statements:, ..) -> {
        list.map(statements, fn(statement) {
          list.map(statement.inlines, inline_to_node(_, declarations))
          |> list.append([
            preprocessor.PreProcessedDeclaration(
              topic_id: statement.topic_id,
              tokens: "^",
            ),
          ])
        })
        |> list.flatten
      }

      djotx.Codeblock(..) -> {
        [
          preprocessor.PreProcessedNode(
            element: djotx.container_to_elements(node, Nil)
            |> element.to_string,
          ),
        ]
      }

      djotx.Heading(level: _, inlines:, ..) -> {
        list.map(inlines, inline_to_node(_, declarations))
      }

      djotx.RawBlock(..) -> [preprocessor.PreProcessedNode(element: "")]

      djotx.BulletList(_layout, _style, _items) -> [
        preprocessor.PreProcessedNode(
          element: djotx.container_to_elements(node, Nil) |> element.to_string,
        ),
      ]
    }
  })
}

fn inline_to_node(inline, declarations) {
  case inline {
    djotx.Linebreak -> preprocessor.PreProcessedNode(element: "<br>")
    djotx.NonBreakingSpace -> preprocessor.PreProcessedNode(element: "\u{a0}")
    djotx.Code(content) ->
      case preprocessor.find_reference(for: content, with: declarations) {
        Ok(topic_id) ->
          preprocessor.PreProcessedReference(topic_id:, tokens: content)
        Error(Nil) ->
          preprocessor.PreProcessedNode(
            element: djotx.inline_to_element(inline, Nil) |> element.to_string,
          )
      }
    _ ->
      preprocessor.PreProcessedNode(
        element: djotx.inline_to_element(inline, Nil) |> element.to_string,
      )
  }
}
