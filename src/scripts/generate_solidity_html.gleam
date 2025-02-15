import gleam/int
import gleam/list
import gleam/regexp
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html
import simplifile
import text

pub fn main() {
  run(text.file_body, "audit")
}

pub fn run(solidity_source text: String, with_name name: String) {
  let html_content =
    text
    |> string.split(on: "\n")
    |> list.index_map(fn(original_line, index) {
      case original_line {
        "" -> html.p([attribute.class("loc")], [html.text("&nbsp;")])
        _ -> {
          let line =
            original_line
            |> string.trim_start
            |> string.append(get_leading_escaped_spaces(original_line), _)

          html.div(
            [
              attribute.class("hover-container"),
              attribute.id("loc" <> int.to_string(index)),
            ],
            [
              html.p([attribute.class("allow-indent"), attribute.class("loc")], [
                html.text(line),
                html.span([attribute.class("line-hover-discussion")], [
                  html.text("D!"),
                ]),
              ]),
            ],
          )
        }
      }
      |> element.to_string
    })
    |> string.join("\n")
    |> string.replace("&amp;", with: "&")

  { "<!DOCTYPE html>
<html lang=\"en\">

<head>
  <meta charset=\"utf-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <title>Olla</title>
  <link rel=\"stylesheet\" href=\"/styles.css\">
  <script type=\"module\" src=\"/lustre-server-component.mjs\"></script>
</head>

<body><div class=\"code-snippet\">" <> html_content <> "</div></body>

 </html>" }
  |> simplifile.write(to: "priv/static/" <> name <> ".html")
}

pub fn get_leading_escaped_spaces(line: String) {
  let assert Ok(re) =
    regexp.compile(
      "^\\s*",
      regexp.Options(multi_line: False, case_insensitive: True),
    )

  let leading_count = case regexp.scan(with: re, content: line) {
    [regexp.Match(content: match, submatches: _), ..] -> string.length(match)
    [] -> 0
  }

  list.repeat("&nbsp;", leading_count)
  |> string.join("")
}
