import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import houdini
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/preprocessor
import o11a/topic

pub fn preprocess_source(ast ast: Document, declarations declarations) {
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

fn consume_source(nodes nodes: List(Container), declarations declarations) {
  list.map(nodes, fn(node) {
    case node {
      ThematicBreak -> [preprocessor.PreProcessedNode(element: "<hr>")]
      Paragraph(statements:, ..) -> {
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

      Codeblock(..) -> {
        [
          preprocessor.PreProcessedNode(
            element: container_to_elements(node, Nil)
            |> element.to_string,
          ),
        ]
      }

      Heading(level:, inlines:, ..) -> {
        [
          preprocessor.FormatterHeader(level),
          ..list.map(inlines, inline_to_node(_, declarations))
        ]
      }

      RawBlock(..) -> [preprocessor.PreProcessedNode(element: "")]

      BulletList(_layout, _style, _items) -> [
        preprocessor.PreProcessedNode(
          element: container_to_elements(node, Nil) |> element.to_string,
        ),
      ]
    }
  })
}

fn inline_to_node(inline, declarations) {
  case inline {
    Linebreak -> preprocessor.PreProcessedNode(element: "<br>")
    NonBreakingSpace -> preprocessor.PreProcessedNode(element: "\u{a0}")
    Code(content) ->
      case topic.find_reference_topic(for: content, with: declarations) {
        Ok(topic_id) ->
          preprocessor.PreProcessedReference(topic_id:, tokens: content)
        Error(Nil) ->
          preprocessor.PreProcessedNode(
            element: inline_to_element(inline, Nil) |> element.to_string,
          )
      }
    _ ->
      preprocessor.PreProcessedNode(
        element: inline_to_element(inline, Nil) |> element.to_string,
      )
  }
}

// Djot processing logic -------------------------------------------------------

pub fn main() {
  "Hello friend! This is `cool`.a

This is what I have to say.
"
  |> parse("main", "main", 0, [])
  |> fn(doc) { doc.0 }
  |> djot_document_to_elements
  |> element.fragment
  |> element.to_string
  |> echo
}

import gleam/string
import splitter.{type Splitter}

pub type Document {
  Document(
    nodes: List(Container),
    references: dict.Dict(String, String),
    footnotes: dict.Dict(String, List(Container)),
    document_parent: String,
  )
}

fn add_attribute(
  attributes: dict.Dict(String, String),
  key: String,
  value: String,
) -> dict.Dict(String, String) {
  case key {
    "class" ->
      dict.upsert(attributes, key, fn(previous) {
        case previous {
          None -> value
          Some(previous) -> previous <> " " <> value
        }
      })
    _ -> dict.insert(attributes, key, value)
  }
}

pub type Container {
  ThematicBreak
  Paragraph(attributes: dict.Dict(String, String), statements: List(Statement))
  Heading(
    attributes: dict.Dict(String, String),
    level: Int,
    inlines: List(Inline),
  )
  Codeblock(
    attributes: dict.Dict(String, String),
    language: Option(String),
    content: String,
  )
  RawBlock(content: String)
  BulletList(layout: ListLayout, style: String, items: List(List(Container)))
}

pub type Statement {
  Statement(inlines: List(Inline), topic_id: String)
}

pub type Inline {
  Linebreak
  NonBreakingSpace
  Text(String)
  Link(content: List(Inline), destination: Destination)
  Image(content: List(Inline), destination: Destination)
  Emphasis(content: List(Inline))
  Strong(content: List(Inline))
  Footnote(reference: String)
  Code(content: String)
  MathInline(content: String)
  MathDisplay(content: String)
}

pub type ListLayout {
  Tight
  Loose
}

pub type Destination {
  Reference(String)
  Url(String)
}

type Refs {
  Refs(
    urls: dict.Dict(String, String),
    footnotes: dict.Dict(String, List(Container)),
    document_id: String,
    document_parent: String,
    max_topic_id: Int,
    declarations: dict.Dict(String, topic.Topic),
    topics: List(topic.Topic),
  )
}

type Splitters {
  Splitters(
    verbatim_line_end: Splitter,
    codeblock_language: Splitter,
    inline: Splitter,
    link_destination: Splitter,
    math_end: Splitter,
  )
}

// pub type dict.Dict {
//   dict.Dict(
//     insert: fn(String, String) -> dict.Dict,
//   )
// }

/// Convert a string of Djot into a tree of records.
///
/// This may be useful when you want more control over the HTML to be converted
/// to, or you wish to convert Djot to some other format.
///
pub fn parse(
  source source: String,
  document_id document_id: String,
  document_parent document_parent: String,
  max_topic_id max_topic_id: Int,
  topics topics: List(topic.Topic),
) {
  let splitters =
    Splitters(
      verbatim_line_end: splitter.new([" ", "\n"]),
      codeblock_language: splitter.new(["`", "\n"]),
      inline: splitter.new([
        "\\", "_", "*", "[^", "[", "![", "$$`", "$`", "`", "\n", ".", "!", "?",
      ]),
      link_destination: splitter.new([")", "]", "\n"]),
      math_end: splitter.new(["`"]),
    )
  let refs =
    Refs(
      dict.new(),
      dict.new(),
      document_id:,
      document_parent:,
      max_topic_id:,
      declarations: dict.new(),
      topics:,
    )

  let #(ast, Refs(urls, footnotes, max_topic_id:, declarations:, ..), _) =
    source
    |> string.replace("\r\n", "\n")
    |> parse_document_content(refs, splitters, [], dict.new())

  #(Document(ast, urls, footnotes, document_parent), max_topic_id, declarations)
}

fn drop_lines(in: String) -> String {
  case in {
    "\n" <> rest -> drop_lines(rest)
    other -> other
  }
}

fn drop_spaces(in: String) -> String {
  case in {
    " " <> rest -> drop_spaces(rest)
    other -> other
  }
}

fn count_drop_spaces(in: String, count: Int) -> #(String, Int) {
  case in {
    " " <> rest -> count_drop_spaces(rest, count + 1)
    other -> #(other, count)
  }
}

fn parse_document_content(
  in: String,
  refs: Refs,
  splitters: Splitters,
  ast: List(Container),
  attrs: dict.Dict(String, String),
) -> #(List(Container), Refs, String) {
  let in = drop_lines(in)
  let #(in, spaces_count) = count_drop_spaces(in, 0)

  let #(in, refs, container, attrs) =
    parse_container(in, refs, splitters, attrs, spaces_count)
  let ast = case container {
    None -> ast
    Some(container) -> [container, ..ast]
  }
  case in {
    "" -> #(list.reverse(ast), refs, in)
    _ -> parse_document_content(in, refs, splitters, ast, attrs)
  }
}

/// Parse a block of Djot that ends once the content is no longer indented
/// to a certain level.
/// For example:
///
/// ```djot
/// Here's the reference.[^ref]
///
/// [^ref]: This footnote is a block with two paragraphs.
///
///   This is part of the block because it is indented past the start of `[^ref]`
///
/// But this would not be parsed as part of the block because it has no indentation
/// ```
fn parse_block(
  in: String,
  refs: Refs,
  splitters: Splitters,
  ast: List(Container),
  attrs: dict.Dict(String, String),
  required_spaces: Int,
) -> #(List(Container), Refs, String) {
  let in = drop_lines(in)
  let #(in, indentation) = count_drop_spaces(in, 0)

  case indentation < required_spaces {
    True -> #(list.reverse(ast), refs, in)
    False -> {
      let #(in, refs, container, attrs) =
        parse_container(in, refs, splitters, attrs, indentation)
      let ast = case container {
        None -> ast
        Some(container) -> [container, ..ast]
      }
      case in {
        "" -> #(list.reverse(ast), refs, in)
        _ -> parse_block(in, refs, splitters, ast, attrs, required_spaces)
      }
    }
  }
}

/// This function allows us to parse the contents of a block after we know
/// that the *first* container meets indentation requirements, but we want to
/// ensure that once this container is parsed, future containers meet the
/// indentation requirements
fn parse_block_after_indent_checked(
  in: String,
  refs: Refs,
  splitters: Splitters,
  ast: List(Container),
  attrs: dict.Dict(String, String),
  required_spaces required_spaces: Int,
  indentation indentation: Int,
) -> #(List(Container), Refs, String) {
  let #(in, refs, container, attrs) =
    parse_container(in, refs, splitters, attrs, indentation)
  let ast = case container {
    None -> ast
    Some(container) -> [container, ..ast]
  }
  case in {
    "" -> #(list.reverse(ast), refs, in)
    _ -> parse_block(in, refs, splitters, ast, attrs, required_spaces)
  }
}

fn parse_container(
  in: String,
  refs: Refs,
  splitters: Splitters,
  attrs: dict.Dict(String, String),
  indentation: Int,
) -> #(String, Refs, Option(Container), dict.Dict(String, String)) {
  case in {
    "" -> #(in, refs, None, dict.new())

    "{" <> in2 ->
      case parse_attributes(in2, attrs) {
        None -> {
          let #(paragraph, refs, in) =
            parse_paragraph(in, refs, attrs, splitters)
          #(in, refs, Some(paragraph), dict.new())
        }
        Some(#(attrs, in)) -> #(in, refs, None, attrs)
      }

    "#" <> in -> {
      let #(heading, refs, in) = parse_heading(in, refs, splitters, attrs)
      #(in, refs, Some(heading), dict.new())
    }

    "~" as delim <> in2 | "`" as delim <> in2 -> {
      case parse_codeblock(in2, attrs, delim, indentation, splitters) {
        None -> {
          let #(paragraph, refs, in) =
            parse_paragraph(in, refs, attrs, splitters)
          #(in, refs, Some(paragraph), dict.new())
        }
        Some(#(codeblock, in)) -> #(in, refs, Some(codeblock), dict.new())
      }
    }

    "-" as style <> in2 | "*" as style <> in2 -> {
      case parse_thematic_break(1, in2), in2 {
        None, " " <> in2 | None, "\n" <> in2 -> {
          let #(list, in) =
            parse_bullet_list(in2, refs, attrs, style, Tight, [], splitters)
          #(in, refs, Some(list), dict.new())
        }
        None, _ -> {
          let #(paragraph, refs, in) =
            parse_paragraph(in, refs, attrs, splitters)
          #(in, refs, Some(paragraph), dict.new())
        }
        Some(#(thematic_break, in)), _ -> {
          #(in, refs, Some(thematic_break), dict.new())
        }
      }
    }

    "[^" <> in2 -> {
      case parse_footnote_def(in2, refs, splitters, "^") {
        None -> {
          let #(paragraph, refs, in) =
            parse_paragraph(in, refs, attrs, splitters)
          #(in, refs, Some(paragraph), dict.new())
        }
        Some(#(id, footnote, refs, in)) -> {
          let refs =
            Refs(..refs, footnotes: dict.insert(refs.footnotes, id, footnote))
          #(in, refs, None, dict.new())
        }
      }
    }

    "[" <> in2 -> {
      case parse_ref_def(in2, "") {
        None -> {
          let #(paragraph, refs, in) =
            parse_paragraph(in, refs, attrs, splitters)
          #(in, refs, Some(paragraph), dict.new())
        }
        Some(#(id, url, in)) -> {
          let refs = Refs(..refs, urls: dict.insert(refs.urls, id, url))
          #(in, refs, None, dict.new())
        }
      }
    }

    _ -> {
      let #(paragraph, refs, in) = parse_paragraph(in, refs, attrs, splitters)
      #(in, refs, Some(paragraph), dict.new())
    }
  }
}

fn parse_thematic_break(count: Int, in: String) -> Option(#(Container, String)) {
  case in {
    "" | "\n" <> _ if count >= 3 -> Some(#(ThematicBreak, in))
    " " <> rest | "\t" <> rest -> parse_thematic_break(count, rest)
    "-" <> rest | "*" <> rest -> parse_thematic_break(count + 1, rest)
    _ -> None
  }
}

fn parse_codeblock(
  in: String,
  attrs: dict.Dict(String, String),
  delim: String,
  indentation: Int,
  splitters: Splitters,
) -> Option(#(Container, String)) {
  let out = parse_codeblock_start(in, splitters, delim, 1)
  use #(language, count, in) <- option.then(out)
  let #(content, in) =
    parse_codeblock_content(in, delim, count, indentation, "", splitters)
  case language {
    Some("=html") -> Some(#(RawBlock(string.trim_end(content)), in))
    _ -> Some(#(Codeblock(attrs, language, content), in))
  }
}

fn parse_codeblock_start(
  in: String,
  splitters: Splitters,
  delim: String,
  count: Int,
) -> Option(#(Option(String), Int, String)) {
  case in {
    "`" as c <> in | "~" as c <> in if c == delim ->
      parse_codeblock_start(in, splitters, delim, count + 1)

    "\n" <> in if count >= 3 -> Some(#(None, count, in))

    "" -> None
    _non_empty if count >= 3 -> {
      let in = drop_spaces(in)
      use #(language, in) <- option.map(parse_codeblock_language(
        in,
        splitters,
        "",
      ))
      #(language, count, in)
    }

    _ -> None
  }
}

fn parse_codeblock_content(
  in: String,
  delim: String,
  count: Int,
  indentation: Int,
  acc: String,
  splitters: Splitters,
) -> #(String, String) {
  case parse_codeblock_end(in, delim, count) {
    None -> {
      let #(acc, in) = slurp_verbatim_line(in, indentation, acc, splitters)
      parse_codeblock_content(in, delim, count, indentation, acc, splitters)
    }
    Some(in) -> #(acc, in)
  }
}

fn slurp_verbatim_line(
  in: String,
  indentation: Int,
  acc: String,
  splitters: Splitters,
) -> #(String, String) {
  case splitter.split(splitters.verbatim_line_end, in) {
    #(before, "\n", in) -> #(acc <> before <> "\n", in)
    #("", " ", in) if indentation > 0 ->
      slurp_verbatim_line(in, indentation - 1, acc, splitters)
    #(before, split, in) ->
      slurp_verbatim_line(in, indentation, acc <> before <> split, splitters)
  }
}

fn parse_codeblock_end(in: String, delim: String, count: Int) -> Option(String) {
  case in {
    "\n" <> in if count == 0 -> Some(in)
    _ if count == 0 -> Some(in)

    // if the codeblock is indented (ex: in a footnote block), we need to accept an indented end marker
    " " <> in -> parse_codeblock_end(in, delim, count)

    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, in)) if c == delim -> parse_codeblock_end(in, delim, count - 1)
        Ok(_) -> None
        Error(_) -> Some(in)
      }
  }
}

fn parse_codeblock_language(
  in: String,
  splitters: Splitters,
  language: String,
) -> Option(#(Option(String), String)) {
  case splitter.split(splitters.codeblock_language, in) {
    // A language specifier cannot contain a backtick
    #(_, "`", _) -> None
    #(a, "\n", _) if a == "" && language == "" -> Some(#(None, in))
    #(a, "\n", in) -> Some(#(Some(language <> a), in))
    _ -> Some(#(None, in))
  }
}

fn parse_ref_def(in: String, id: String) -> Option(#(String, String, String)) {
  case in {
    "]:" <> in -> parse_ref_value(in, id, "")
    "" | "]" <> _ | "\n" <> _ -> None
    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, in)) -> parse_ref_def(in, id <> c)
        Error(_) -> None
      }
  }
}

fn parse_ref_value(
  in: String,
  id: String,
  url: String,
) -> Option(#(String, String, String)) {
  case in {
    "\n " <> in -> parse_ref_value(drop_spaces(in), id, url)
    "\n" <> in -> Some(#(id, string.trim(url), in))
    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, in)) -> parse_ref_value(in, id, url <> c)
        Error(_) -> Some(#(id, string.trim(url), ""))
      }
  }
}

fn parse_footnote_def(
  in: String,
  refs: Refs,
  splitters: Splitters,
  id: String,
) -> Option(#(String, List(Container), Refs, String)) {
  case in {
    "]:" <> in -> {
      let #(in, spaces_count) = count_drop_spaces(in, 0)
      // Because this is the beginning of the block, we don't have to make sure
      // it is properly indented, so we might be able to skip that process.
      let block_parser = case in {
        // However, if there is a new line directly following the beginning of the block,
        // we need to check the indentation to be sure that it is not an empty block
        "\n" <> _ -> parse_block
        _ -> fn(in, refs, splitters, ast, attrs, required_spaces) {
          parse_block_after_indent_checked(
            in,
            refs,
            splitters,
            ast,
            attrs,
            required_spaces,
            indentation: 4 + string.length(id) + spaces_count,
          )
        }
      }
      let #(block, refs, rest) =
        block_parser(in, refs, splitters, [], dict.new(), 1)
      Some(#(id, block, refs, rest))
    }
    "" | "]" <> _ | "\n" <> _ -> None
    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, in)) -> parse_footnote_def(in, refs, splitters, id <> c)
        Error(_) -> None
      }
  }
}

fn parse_attributes(
  in: String,
  attrs: dict.Dict(String, String),
) -> Option(#(dict.Dict(String, String), String)) {
  let in = drop_spaces(in)
  case in {
    "" -> None
    "}" <> in -> parse_attributes_end(in, attrs)
    "#" <> in -> {
      case parse_attributes_id_or_class(in, "") {
        Some(#(id, in)) -> parse_attributes(in, add_attribute(attrs, "id", id))
        None -> None
      }
    }
    "." <> in -> {
      case parse_attributes_id_or_class(in, "") {
        Some(#(c, in)) -> parse_attributes(in, add_attribute(attrs, "class", c))
        None -> None
      }
    }
    _ -> {
      case parse_attribute(in, "") {
        Some(#(k, v, in)) -> parse_attributes(in, add_attribute(attrs, k, v))
        None -> None
      }
    }
  }
}

fn parse_attribute(in: String, key: String) -> Option(#(String, String, String)) {
  case in {
    "" | " " <> _ -> None
    "=\"" <> in -> parse_attribute_quoted_value(in, key, "")
    "=" <> in -> parse_attribute_value(in, key, "")
    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, in)) -> parse_attribute(in, key <> c)
        Error(_) -> None
      }
  }
}

fn parse_attribute_value(
  in: String,
  key: String,
  value: String,
) -> Option(#(String, String, String)) {
  case in {
    "" -> None
    " " <> in -> Some(#(key, value, in))
    "}" <> _ -> Some(#(key, value, in))
    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, in)) -> parse_attribute_value(in, key, value <> c)
        Error(_) -> None
      }
  }
}

fn parse_attribute_quoted_value(
  in: String,
  key: String,
  value: String,
) -> Option(#(String, String, String)) {
  case in {
    "" -> None
    "\"" <> in -> Some(#(key, value, in))
    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, in)) -> parse_attribute_quoted_value(in, key, value <> c)
        Error(_) -> None
      }
  }
}

fn parse_attributes_id_or_class(
  in: String,
  id: String,
) -> Option(#(String, String)) {
  case in {
    "" | "}" <> _ | " " <> _ -> Some(#(id, in))
    "#" <> _ | "." <> _ | "=" <> _ -> None
    // TODO: in future this will be permitted as attributes can be over multiple lines
    "\n" <> _ -> None
    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, in)) -> parse_attributes_id_or_class(in, id <> c)
        Error(_) -> Some(#(id, in))
      }
  }
}

fn parse_attributes_end(
  in: String,
  attrs: dict.Dict(String, String),
) -> Option(#(dict.Dict(String, String), String)) {
  case in {
    "" -> Some(#(attrs, ""))
    "\n" <> in -> Some(#(attrs, in))
    " " <> in -> parse_attributes_end(in, attrs)
    _ -> None
  }
}

fn parse_heading(
  in: String,
  refs: Refs,
  splitters: Splitters,
  attrs: dict.Dict(String, String),
) -> #(Container, Refs, String) {
  case heading_level(in, 1) {
    Some(#(level, in)) -> {
      let in = drop_spaces(in)
      let #(inline_in, in) = take_heading_chars(in, level, "")
      let #(inline, inline_in_remaining) =
        parse_inline(inline_in, splitters, "", [])
      let text = take_inline_text(inline, "")
      let #(refs, attrs) = case id_sanitise(text) {
        "" -> #(refs, attrs)
        id -> {
          case dict.get(refs.urls, id) {
            Ok(_) -> #(refs, attrs)
            Error(_) -> {
              let refs =
                Refs(..refs, urls: dict.insert(refs.urls, id, "#" <> id))
              let attrs = add_attribute(attrs, "id", id)
              #(refs, attrs)
            }
          }
        }
      }
      let heading = Heading(attrs, level, inline)
      #(heading, refs, inline_in_remaining <> in)
    }

    None -> {
      let #(p, refs, in) = parse_paragraph("#" <> in, refs, attrs, splitters)
      #(p, refs, in)
    }
  }
}

fn id_sanitise(content: String) -> String {
  content
  |> string.replace("#", "")
  |> string.replace("?", "")
  |> string.replace("!", "")
  |> string.replace(",", "")
  |> string.trim
  |> string.replace(" ", "-")
  |> string.replace("\n", "-")
}

fn take_heading_chars(in: String, level: Int, acc: String) -> #(String, String) {
  case in {
    "" | "\n" -> #(acc, "")
    "\n\n" <> in -> #(acc, in)
    "\n#" <> rest -> {
      case take_heading_chars_newline_hash(rest, level - 1, acc <> "\n") {
        Some(#(acc, in)) -> take_heading_chars(in, level, acc)
        None -> #(acc, in)
      }
    }
    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, in)) -> take_heading_chars(in, level, acc <> c)
        Error(_) -> #(acc, "")
      }
  }
}

fn take_heading_chars_newline_hash(
  in: String,
  level: Int,
  acc: String,
) -> Option(#(String, String)) {
  case in {
    _ if level < 0 -> None
    "" if level > 0 -> None

    "" if level == 0 -> Some(#(acc, ""))
    " " <> in if level == 0 -> Some(#(acc, in))

    "#" <> rest -> take_heading_chars_newline_hash(rest, level - 1, acc)

    _ -> None
  }
}

fn parse_inline(
  in: String,
  splitters: Splitters,
  text: String,
  acc: List(Inline),
) -> #(List(Inline), String) {
  case splitter.split(splitters.inline, in) {
    // End of the input
    #(text2, "", "") ->
      case text <> text2 {
        "" -> #(list.reverse(acc), "")
        text -> #(list.reverse([Text(text), ..acc]), "")
      }

    // // Escapes
    #(a, "\\", in) -> {
      let text = text <> a
      case in {
        "!" as e <> in
        | "\"" as e <> in
        | "#" as e <> in
        | "$" as e <> in
        | "%" as e <> in
        | "&" as e <> in
        | "'" as e <> in
        | "(" as e <> in
        | ")" as e <> in
        | "*" as e <> in
        | "+" as e <> in
        | "," as e <> in
        | "-" as e <> in
        | "." as e <> in
        | "/" as e <> in
        | ":" as e <> in
        | ";" as e <> in
        | "<" as e <> in
        | "=" as e <> in
        | ">" as e <> in
        | "?" as e <> in
        | "@" as e <> in
        | "[" as e <> in
        | "\\" as e <> in
        | "]" as e <> in
        | "^" as e <> in
        | "_" as e <> in
        | "`" as e <> in
        | "{" as e <> in
        | "|" as e <> in
        | "}" as e <> in
        | "~" as e <> in -> parse_inline(in, splitters, text <> e, acc)

        "\n" <> in ->
          parse_inline(in, splitters, "", [Linebreak, Text(text), ..acc])

        " " <> in ->
          parse_inline(in, splitters, "", [NonBreakingSpace, Text(text), ..acc])

        _other -> parse_inline(in, splitters, text <> "\\", acc)
      }
    }

    #(a, "_" as start, in) | #(a, "*" as start, in) -> {
      let text = text <> a
      case in {
        " " as b <> in | "\t" as b <> in | "\n" as b <> in ->
          parse_inline(in, splitters, text <> start <> b, acc)
        _ ->
          case parse_emphasis(in, splitters, start) {
            None -> parse_inline(in, splitters, text <> start, acc)
            Some(#(inner, in)) -> {
              let item = case start {
                "*" -> Strong(inner)
                _ -> Emphasis(inner)
              }
              parse_inline(in, splitters, "", [item, Text(text), ..acc])
            }
          }
      }
    }

    #(a, "[^", rest) -> {
      let text = text <> a
      case parse_footnote(rest, "^") {
        None -> parse_inline(rest, splitters, text <> "[^", acc)
        // if this is actually a definition instead of a reference, return early
        // This applies in situations such as the following:
        // ```
        // [^footnote]: very long footnote[^another-footnote]
        // [^another-footnote]: bla bla[^another-footnote]
        // ```
        Some(#(_footnote, ":" <> _)) if text != "" -> #(
          list.reverse([Text(text), ..acc]),
          in,
        )
        Some(#(_footnote, ":" <> _)) -> #(list.reverse(acc), in)
        Some(#(footnote, in)) ->
          parse_inline(in, splitters, "", [footnote, Text(text), ..acc])
      }
    }

    // Link and image
    #(a, "[", in) -> {
      let text = text <> a
      case parse_link(in, splitters, Link) {
        None -> parse_inline(in, splitters, text <> "[", acc)
        Some(#(link, in)) ->
          parse_inline(in, splitters, "", [link, Text(text), ..acc])
      }
    }

    #(a, "![", in) -> {
      let text = text <> a
      case parse_link(in, splitters, Image) {
        None -> parse_inline(in, splitters, text <> "![", acc)
        Some(#(image, in)) ->
          parse_inline(in, splitters, "", [image, Text(text), ..acc])
      }
    }

    // Code
    #(a, "`", in) -> {
      let text = text <> a
      let #(code, in) = parse_code(in, 1)
      parse_inline(in, splitters, "", [code, Text(text), ..acc])
    }

    #(a, "\n", in) -> {
      let text = text <> a
      drop_spaces(in)
      |> parse_inline(splitters, text <> "\n", acc)
    }

    // Math (inline)
    #(a, "$`", in) -> {
      let text = text <> a
      case parse_math(in, splitters, False) {
        None -> parse_inline(in, splitters, text <> "$`", acc)
        Some(#(math, in)) ->
          parse_inline(in, splitters, "", [math, Text(text), ..acc])
      }
    }

    // Math (display)
    #(a, "$$`", in) -> {
      let text = text <> a
      case parse_math(in, splitters, True) {
        None -> parse_inline(in, splitters, text <> "$$`", acc)
        Some(#(math, in)) ->
          parse_inline(in, splitters, "", [math, Text(text), ..acc])
      }
    }

    #(text2, text3, in) ->
      case text <> text2 <> text3 {
        "" -> #(list.reverse(acc), in)
        text -> #(list.reverse([Text(text), ..acc]), in)
      }
  }
}

fn parse_math(
  in: String,
  splitters: Splitters,
  display: Bool,
) -> Option(#(Inline, String)) {
  case splitter.split(splitters.math_end, in) {
    #(_, "", "") -> None
    #(latex, _, rest) -> {
      let math = case display {
        True -> MathDisplay(latex)
        False -> MathInline(latex)
      }

      Some(#(math, rest))
    }
  }
}

fn parse_code(in: String, count: Int) -> #(Inline, String) {
  case in {
    "`" <> in -> parse_code(in, count + 1)
    _ -> {
      let #(content, in) = parse_code_content(in, count, "")

      // If the string has a single space at the end then a backtick we are
      // supposed to not include that space. This is so inline code can start
      // with a backtick.
      let content = case string.starts_with(content, " `") {
        True -> string.trim_start(content)
        False -> content
      }
      let content = case string.ends_with(content, "` ") {
        True -> string.trim_end(content)
        False -> content
      }
      #(Code(content), in)
    }
  }
}

fn parse_code_content(
  in: String,
  count: Int,
  content: String,
) -> #(String, String) {
  case in {
    "" -> #(content, in)
    "`" <> in -> {
      let #(done, content, in) = parse_code_end(in, count, 1, content)
      case done {
        True -> #(content, in)
        False -> parse_code_content(in, count, content)
      }
    }

    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, in)) -> parse_code_content(in, count, content <> c)
        Error(_) -> #(content, in)
      }
  }
}

fn parse_code_end(
  in: String,
  limit: Int,
  count: Int,
  content: String,
) -> #(Bool, String, String) {
  case in {
    "" -> #(True, content, in)
    "`" <> in -> parse_code_end(in, limit, count + 1, content)
    _ if limit == count -> #(True, content, in)
    _ -> #(False, content <> string.repeat("`", count), in)
  }
}

fn parse_emphasis(
  in: String,
  splitters: Splitters,
  close: String,
) -> Option(#(List(Inline), String)) {
  case take_emphasis_chars(in, close, "") {
    None -> None

    Some(#(inline_in, in)) -> {
      let #(inline, inline_in_remaining) =
        parse_inline(inline_in, splitters, "", [])
      Some(#(inline, inline_in_remaining <> in))
    }
  }
}

fn take_emphasis_chars(
  in: String,
  close: String,
  acc: String,
) -> Option(#(String, String)) {
  case in {
    "" -> None

    // Inline code overrides emphasis
    "`" <> _ -> None

    // The close is not a close if it is preceeded by whitespace
    "\t" as ws <> in | "\n" as ws <> in | " " as ws <> in ->
      case string.pop_grapheme(in) {
        Ok(#(c, in)) if c == close ->
          take_emphasis_chars(in, close, acc <> ws <> c)
        _ -> take_emphasis_chars(in, close, acc <> ws)
      }

    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, __)) if c == close && acc == "" -> None
        Ok(#(c, in)) if c == close -> Some(#(acc, in))
        Ok(#(c, in)) -> take_emphasis_chars(in, close, acc <> c)
        Error(_) -> None
      }
  }
}

fn parse_link(
  in: String,
  splitters: Splitters,
  to_inline: fn(List(Inline), Destination) -> Inline,
) -> Option(#(Inline, String)) {
  case take_link_chars(in, "", splitters) {
    // This wasn't a link, it was just a `[` in the text
    None -> None

    Some(#(inline_in, ref, in)) -> {
      let #(inline, inline_in_remaining) =
        parse_inline(inline_in, splitters, "", [])
      let ref = case ref {
        Reference("") -> Reference(take_inline_text(inline, ""))
        ref -> ref
      }
      Some(#(to_inline(inline, ref), inline_in_remaining <> in))
    }
  }
}

fn take_link_chars(
  in: String,
  inline_in: String,
  splitters: Splitters,
) -> Option(#(String, Destination, String)) {
  case string.split_once(in, "]") {
    Ok(#(before, "[" <> in)) ->
      take_link_chars_destination(in, False, inline_in <> before, splitters, "")

    Ok(#(before, "(" <> in)) ->
      take_link_chars_destination(in, True, inline_in <> before, splitters, "")

    Ok(#(before, in)) -> take_link_chars(in, inline_in <> before, splitters)

    // This wasn't a link, it was just a `[..]` in the text
    Error(_) -> None
  }
}

fn take_link_chars_destination(
  in: String,
  is_url: Bool,
  inline_in: String,
  splitters: Splitters,
  acc: String,
) -> Option(#(String, Destination, String)) {
  case splitter.split(splitters.link_destination, in) {
    #(a, ")", in) if is_url -> Some(#(inline_in, Url(acc <> a), in))
    #(a, "]", in) if !is_url -> Some(#(inline_in, Reference(acc <> a), in))

    #(a, "\n", rest) if is_url ->
      take_link_chars_destination(rest, is_url, inline_in, splitters, acc <> a)
    #(a, "\n", rest) if !is_url ->
      take_link_chars_destination(
        rest,
        is_url,
        inline_in,
        splitters,
        acc <> a <> " ",
      )

    _ -> None
  }
}

fn parse_footnote(in: String, acc: String) -> Option(#(Inline, String)) {
  case in {
    // This wasn't a footnote, it was just a `[^` in the text
    "" -> None

    "]" <> rest -> {
      Some(#(Footnote(acc), rest))
    }
    _ ->
      case string.pop_grapheme(in) {
        Ok(#(c, rest)) -> parse_footnote(rest, acc <> c)
        // This wasn't a footnote, it was just a `[^` in the text
        Error(_) -> None
      }
  }
}

fn heading_level(in: String, level: Int) -> Option(#(Int, String)) {
  case in {
    "#" <> rest -> heading_level(rest, level + 1)

    "" if level > 0 -> Some(#(level, ""))
    " " <> rest | "\n" <> rest if level != 0 -> Some(#(level, rest))

    _ -> None
  }
}

pub fn take_inline_text(inlines: List(Inline), acc: String) -> String {
  case inlines {
    [] -> acc
    [first, ..rest] ->
      case first {
        NonBreakingSpace -> take_inline_text(rest, acc <> " ")
        Text(text) | Code(text) | MathInline(text) | MathDisplay(text) ->
          take_inline_text(rest, acc <> text)
        Strong(inlines) | Emphasis(inlines) ->
          take_inline_text(list.append(inlines, rest), acc)
        Link(nested, _) | Image(nested, _) -> {
          let acc = take_inline_text(nested, acc)
          take_inline_text(rest, acc)
        }
        Linebreak | Footnote(_) -> {
          take_inline_text(rest, acc)
        }
      }
  }
}

fn parse_paragraph(
  in: String,
  refs: Refs,
  attrs: dict.Dict(String, String),
  splitters: Splitters,
) -> #(Container, Refs, String) {
  let #(inline_in, in) = take_paragraph_chars(in)

  let #(statements, refs, inline_in_remaining) =
    do_parse_paragraph_statements(inline_in, refs, attrs, splitters, [])
  #(
    Paragraph(
      attrs,
      statements
        |> list.reverse,
    ),
    refs,
    inline_in_remaining <> in,
  )
}

fn do_parse_paragraph_statements(
  inline_in: String,
  refs: Refs,
  attrs: dict.Dict(String, String),
  splitters,
  statements: List(Statement),
) {
  let #(inline, inline_in_remaining) =
    parse_inline(inline_in, splitters, "", [])
  case inline, inline_in_remaining {
    _, "" | _, "\n" -> {
      let max_topic_id = refs.max_topic_id + 1

      let topic_id = refs.document_id <> "-" <> int.to_string(max_topic_id)

      let declaration =
        topic.TextDeclaration(
          topic_id:,
          name: topic_id,
          signature: [
            preprocessor.TextSnippetLine(
              elements: list.map(inline, inline_to_node(_, refs.topics)),
            ),
          ],
          scope: preprocessor.Scope(
            file: refs.document_parent,
            contract: option.Some(refs.document_id),
            member: option.None,
          ),
        )

      let refs =
        Refs(
          ..refs,
          max_topic_id:,
          declarations: dict.insert(refs.declarations, topic_id, declaration),
        )

      #([Statement(inline, topic_id:), ..statements], refs, inline_in_remaining)
    }
    [], _ -> #(statements, refs, inline_in_remaining)
    _, _ -> {
      let max_topic_id = refs.max_topic_id + 1

      let topic_id = refs.document_id <> "-" <> int.to_string(max_topic_id)

      let declaration =
        topic.TextDeclaration(
          topic_id:,
          name: topic_id,
          signature: [
            preprocessor.TextSnippetLine(
              elements: list.map(inline, inline_to_node(_, refs.topics)),
            ),
          ],
          scope: preprocessor.Scope(
            file: refs.document_parent,
            contract: option.Some(refs.document_id),
            member: option.None,
          ),
        )

      let refs =
        Refs(
          ..refs,
          max_topic_id:,
          declarations: dict.insert(refs.declarations, topic_id, declaration),
        )

      do_parse_paragraph_statements(
        inline_in_remaining,
        refs,
        attrs,
        splitters,
        [Statement(inline, topic_id:), ..statements],
      )
    }
  }
}

fn parse_bullet_list(
  in: String,
  refs: Refs,
  attrs: dict.Dict(String, String),
  style: String,
  layout: ListLayout,
  items: List(List(Container)),
  splitters: Splitters,
) -> #(Container, String) {
  let #(inline_in, in, end) = take_list_item_chars(in, "", style)
  let item = parse_list_item(inline_in, refs, attrs, splitters, [])
  let items = [item, ..items]
  case end {
    True -> #(BulletList(layout:, style:, items: list.reverse(items)), in)
    False -> parse_bullet_list(in, refs, attrs, style, layout, items, splitters)
  }
}

fn parse_list_item(
  in: String,
  refs: Refs,
  attrs: dict.Dict(String, String),
  splitters: Splitters,
  children: List(Container),
) -> List(Container) {
  let #(in, refs, container, attrs) =
    parse_container(in, refs, splitters, attrs, 0)
  let children = case container {
    None -> children
    Some(container) -> [container, ..children]
  }
  case in {
    "" -> list.reverse(children)
    _ -> parse_list_item(in, refs, attrs, splitters, children)
  }
}

fn take_list_item_chars(
  in: String,
  acc: String,
  style: String,
) -> #(String, String, Bool) {
  let #(in, acc) = case string.split_once(in, "\n") {
    Ok(#(content, in)) -> #(in, acc <> content)
    Error(_) -> #("", acc <> in)
  }

  case in {
    " " <> in -> take_list_item_chars(in, acc <> "\n ", style)
    "- " <> in if style == "-" -> #(acc, in, False)
    "\n- " <> in if style == "-" -> #(acc, in, False)
    "* " <> in if style == "*" -> #(acc, in, False)
    "\n* " <> in if style == "*" -> #(acc, in, False)
    _ -> #(acc, in, True)
  }
}

fn take_paragraph_chars(in: String) -> #(String, String) {
  case string.split_once(in, "\n\n") {
    Ok(#(content, in)) -> #(content, in)
    Error(Nil) ->
      case string.ends_with(in, "\n") {
        True -> #(string.drop_end(in, 1), "")
        False -> #(in, "")
      }
  }
}

/// Convert a document tree into a string of HTML.
///
/// See `to_html` for further documentation.
///
pub fn djot_document_to_elements(document: Document) {
  containers_to_elements(document.nodes, Nil)
}

fn containers_to_elements(
  containers: List(Container),
  refs,
) -> List(element.Element(msg)) {
  list.map(containers, fn(container) { container_to_elements(container, refs) })
}

pub fn container_to_elements(container: Container, refs) -> element.Element(msg) {
  case container {
    ThematicBreak -> html.hr([])

    Paragraph(attrs, statements) -> {
      html.p(
        attrs |> dict_to_attributes,
        statements_to_elements(statements, refs),
      )
    }

    Codeblock(attrs, language, content) -> {
      let code_attrs = case language {
        Some(lang) -> add_attribute(attrs, "class", "language-" <> lang)
        None -> attrs
      }

      html.pre([attribute.class("codeblock")], [
        html.code(code_attrs |> dict_to_attributes, [
          html.text(houdini.escape(content)),
        ]),
      ])
    }

    Heading(attrs, level, inlines) -> {
      let tag = "h" <> int.to_string(level)
      element.element(
        tag,
        attrs |> dict_to_attributes,
        inlines_to_elements(inlines, refs),
      )
    }

    RawBlock(_content) -> element.fragment([])

    BulletList(layout:, style: _, items:) -> {
      html.ul([], list_items_to_html([], layout, items, refs) |> list.reverse)
    }
  }
}

fn dict_to_attributes(dict: dict.Dict(String, String)) {
  dict
  |> dict.to_list
  |> list.map(fn(pair) { attribute.attribute(pair.0, pair.1) })
}

fn list_items_to_html(
  elements: List(element.Element(msg)),
  layout: ListLayout,
  items: List(List(Container)),
  refs,
) -> List(element.Element(msg)) {
  case items {
    [] -> elements

    [[Paragraph(_, statements)], ..rest] if layout == Tight -> {
      [html.li([], statements_to_elements(statements, refs)), ..elements]
      |> list_items_to_html(layout, rest, refs)
    }

    [item, ..rest] -> {
      [html.li([], containers_to_elements(item, refs)), ..elements]
      |> list_items_to_html(layout, rest, refs)
    }
  }
}

fn statements_to_elements(statements: List(Statement), refs) {
  list.map(statements, fn(s: Statement) {
    html.span(
      [attribute.class("statement")],
      inlines_to_elements(s.inlines, refs),
    )
  })
}

fn inlines_to_elements(
  inlines: List(Inline),
  refs,
) -> List(element.Element(msg)) {
  list.map(inlines, fn(inline) { inline_to_element(inline, refs) })
}

pub fn inline_to_element(inline: Inline, refs) -> element.Element(msg) {
  case inline {
    MathInline(latex) -> {
      let latex = "\\(" <> houdini.escape(latex) <> "\\)"

      html.span([attribute.class("math inline")], [html.text(latex)])
    }
    MathDisplay(latex) -> {
      let latex = "\\[" <> houdini.escape(latex) <> "\\]"

      html.span([attribute.class("math display")], [html.text(latex)])
    }
    NonBreakingSpace -> {
      html.text("\u{a0}")
    }
    Linebreak -> {
      html.br([])
    }
    Text(text) -> {
      let text = houdini.escape(text)
      html.text(text)
    }
    Strong(inlines) -> {
      html.strong([], inlines_to_elements(inlines, refs))
    }
    Emphasis(inlines) -> {
      html.em([], inlines_to_elements(inlines, refs))
    }
    Link(text, destination) -> {
      html.a(
        [destination_attribute("href", destination)],
        inlines_to_elements(text, refs),
      )
    }
    Image(text, destination) -> {
      html.img([
        destination_attribute("src", destination),
        attribute.alt(houdini.escape(take_inline_text(text, ""))),
      ])
    }
    Code(content) -> {
      let content = houdini.escape(content)
      html.code([], [html.text(content)])
    }
    Footnote(reference) -> html.text(reference)
  }
}

fn destination_attribute(key: String, destination: Destination) {
  case destination {
    Url(url) -> attribute.attribute(key, houdini.escape(url))
    Reference(id) -> attribute.attribute(key, houdini.escape(id))
  }
}
