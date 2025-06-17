import gleam/int
import gleam/list
import gleam/option
import lib/djotx
import lustre/element
import o11a/preprocessor
import o11a/topic

pub fn preprocess_source(ast ast: djotx.Document, declarations declarations) {
  use line, index <- list.index_map(consume_source(
    nodes: ast.nodes,
    declarations:,
  ))

  let line_number = index + 1
  let line_number_text = int.to_string(line_number)
  let line_tag = "L" <> line_number_text

  // TODO: One day we could give a line its own topic id if it has more than
  // one statement in it, that way users could reference an entire paragraph,
  // table, list, or code block all at once. For now all line are "empty" so 
  // so they don't have their own topic id
  let topic_id = option.None

  let columns =
    list.count(line, fn(node) {
      case node {
        preprocessor.PreProcessedDeclaration(..)
        | preprocessor.PreProcessedReference(..) -> True
        _ -> False
      }
    })

  let level = case line {
    [preprocessor.FormatterHeader(level), ..] -> level
    _ -> 0
  }

  preprocessor.PreProcessedLine(
    topic_id:,
    elements: line,
    line_number:,
    columns:,
    line_number_text:,
    line_tag:,
    level:,
    kind: preprocessor.Text,
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

      djotx.Heading(level:, inlines:, ..) -> {
        [
          preprocessor.FormatterHeader(level),
          ..list.map(inlines, inline_to_node(_, declarations))
        ]
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
      case topic.find_reference_topic(for: content, with: declarations) {
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
