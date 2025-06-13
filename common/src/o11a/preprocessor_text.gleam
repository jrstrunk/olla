import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import houdini
import lustre/attribute
import lustre/element
import lustre/element/html
import lib/djotx

pub fn main() {
  "Hello friend! This is `cool`.a

This is what I have to say.
"
  |> djotx.parse
  |> djot_document_to_elements
  |> element.fragment
  |> element.to_string
  |> echo
}

/// Convert a document tree into a string of HTML.
///
/// See `to_html` for further documentation.
///
pub fn djot_document_to_elements(document: djotx.Document) {
  containers_to_elements(document.content, Nil)
}

fn containers_to_elements(
  containers: List(djotx.Container),
  refs,
) -> List(element.Element(msg)) {
  list.map(containers, fn(container) { container_to_elements(container, refs) })
}

fn container_to_elements(container: djotx.Container, refs) -> element.Element(msg) {
  case container {
    djotx.ThematicBreak -> html.hr([])

    djotx.Paragraph(attrs, statements) -> {
      html.p(
        attrs |> dict_to_attributes,
        statements_to_elements(statements, refs),
      )
    }

    djotx.Codeblock(attrs, language, content) -> {
      let code_attrs = case language {
        Some(lang) -> djotx.add_attribute(attrs, "class", "language-" <> lang)
        None -> attrs
      }

      html.pre([attribute.class("codeblock")], [
        html.code(code_attrs |> dict_to_attributes, [
          html.text(houdini.escape(content)),
        ]),
      ])
    }

    djotx.Heading(attrs, level, inlines) -> {
      let tag = "h" <> int.to_string(level)
      element.element(
        tag,
        attrs |> dict_to_attributes,
        inlines_to_elements(inlines, refs),
      )
    }

    djotx.RawBlock(_content) -> element.fragment([])

    djotx.BulletList(layout:, style: _, items:) -> {
      html.ul([], list_items_to_html([], layout, items, refs) |> list.reverse)
    }
  }
}

fn dict_to_attributes(dict: Dict(String, String)) {
  dict
  |> dict.to_list
  |> list.map(fn(pair) { attribute.attribute(pair.0, pair.1) })
}

fn list_items_to_html(
  elements: List(element.Element(msg)),
  layout: djotx.ListLayout,
  items: List(List(djotx.Container)),
  refs,
) -> List(element.Element(msg)) {
  case items {
    [] -> elements

    [[djotx.Paragraph(_, statements)], ..rest] if layout == djotx.Tight -> {
      [html.li([], statements_to_elements(statements, refs)), ..elements]
      |> list_items_to_html(layout, rest, refs)
    }

    [item, ..rest] -> {
      [html.li([], containers_to_elements(item, refs)), ..elements]
      |> list_items_to_html(layout, rest, refs)
    }
  }
}

fn statements_to_elements(statements: List(djotx.Statement), refs) {
  list.map(statements, fn(s: djotx.Statement) {
    html.span(
      [attribute.class("statement")],
      inlines_to_elements(s.inlines, refs),
    )
  })
}

fn inlines_to_elements(
  inlines: List(djotx.Inline),
  refs,
) -> List(element.Element(msg)) {
  list.map(inlines, fn(inline) { inline_to_element(inline, refs) })
}

fn inline_to_element(inline: djotx.Inline, refs) -> element.Element(msg) {
  case inline {
    djotx.MathInline(latex) -> {
      let latex = "\\(" <> houdini.escape(latex) <> "\\)"

      html.span([attribute.class("math inline")], [html.text(latex)])
    }
    djotx.MathDisplay(latex) -> {
      let latex = "\\[" <> houdini.escape(latex) <> "\\]"

      html.span([attribute.class("math display")], [html.text(latex)])
    }
    djotx.NonBreakingSpace -> {
      html.text("\u{a0}")
    }
    djotx.Linebreak -> {
      html.br([])
    }
    djotx.Text(text) -> {
      let text = houdini.escape(text)
      html.text(text)
    }
    djotx.Strong(inlines) -> {
      html.strong([], inlines_to_elements(inlines, refs))
    }
    djotx.Emphasis(inlines) -> {
      html.em([], inlines_to_elements(inlines, refs))
    }
    djotx.Link(text, destination) -> {
      html.a(
        [destination_attribute("href", destination)],
        inlines_to_elements(text, refs),
      )
    }
    djotx.Image(text, destination) -> {
      html.img([
        destination_attribute("src", destination),
        attribute.alt(houdini.escape(djotx.take_inline_text(text, ""))),
      ])
    }
    djotx.Code(content) -> {
      let content = houdini.escape(content)
      html.code([], [html.text(content)])
    }
    djotx.Footnote(reference) -> html.text(reference)
  }
}

fn destination_attribute(key: String, destination: djotx.Destination) {
  case destination {
    djotx.Url(url) -> attribute.attribute(key, houdini.escape(url))
    djotx.Reference(id) -> attribute.attribute(key, houdini.escape(id))
  }
}
