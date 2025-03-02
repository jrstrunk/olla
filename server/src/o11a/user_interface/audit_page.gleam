import given
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/regexp
import gleam/result
import gleam/string
import lib/server_componentx
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import lustre/server_component
import o11a/config
import o11a/note
import o11a/server/discussion
import o11a/user_interface/line_notes
import simplifile
import snag

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(init, update, view(_, False), dict.new())
}

pub type Msg {
  UserSubmittedNote(note: note.Note)
  ServerUpdatedDiscussion
}

pub type Model {
  Model(
    page_path: String,
    preprocessed_source: List(String),
    discussion: discussion.Discussion,
  )
}

pub fn init(init_model: Model) -> #(Model, effect.Effect(Msg)) {
  let subscribe_to_note_updates_effect =
    effect.from(fn(dispatch) {
      discussion.subscribe_to_note_updates(init_model.discussion, fn() {
        dispatch(ServerUpdatedDiscussion)
      })
    })

  #(init_model, subscribe_to_note_updates_effect)
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserSubmittedNote(note) -> {
      let assert Ok(Nil) = discussion.add_note(model.discussion, note)
      #(model, effect.none())
    }
    ServerUpdatedDiscussion -> #(model, effect.none())
  }
}

fn view(model: Model, is_skeleton is_skeleton) -> element.Element(Msg) {
  html.div([attribute.class("code-snippet")], [
    server_componentx.hide_skeleton(),
    ..list.index_map(model.preprocessed_source, fn(line, index) {
      loc_view(model, line, index + 1, is_skeleton)
    })
  ])
}

pub fn get_skeleton(for page_path) {
  let skeleton_path = config.get_full_page_skeleton_path(for: page_path)

  case simplifile.read(skeleton_path) {
    Ok(skeleton) -> Ok(skeleton)

    Error(simplifile.Enoent) -> {
      // Generates a skeleton page for the given page path, and writes it to disk.
      let skeleton: Result(String, snag.Snag) = {
        use source <- result.try(preprocess_source(for: page_path))

        let skeleton =
          Model(
            page_path:,
            preprocessed_source: source,
            discussion: discussion.empty_discussion(page_path),
          )
          |> view(is_skeleton: True)
          |> element.to_string

        use Nil <- result.map(
          simplifile.write(skeleton, to: skeleton_path)
          |> snag.map_error(simplifile.describe_error),
        )

        skeleton
      }

      case skeleton {
        Ok(skeleton) -> Ok(skeleton)

        Error(msg) -> string.inspect(msg) |> snag.error
      }
    }

    Error(msg) -> string.inspect(msg) |> snag.error
  }
}

pub fn preprocess_source(for page_path) {
  config.get_full_page_path(for: page_path)
  |> simplifile.read
  |> snag.map_error(simplifile.describe_error)
  |> result.map(string.split(_, on: "\n"))
  |> result.map(list.map(_, style_code_tokens))
}

fn loc_view(model: Model, line_text, line_number, is_skeleton is_skeleton) {
  let line_number_text = int.to_string(line_number)
  let line_tag = "L" <> line_number_text
  let line_id = model.page_path <> "#" <> line_tag

  use <- given.that(is_skeleton, return: fn() {
    html.p([attribute.class("loc"), attribute.id(line_tag)], [
      html.span([attribute.class("line-number code-extras")], [
        html.text(line_number_text),
      ]),
      html.span(
        [attribute.attribute("dangerous-unescaped-html", line_text)],
        [],
      ),
    ])
  })

  use <- given.that(line_text == "", return: fn() {
    html.p([attribute.class("loc"), attribute.id(line_tag)], [
      html.span([attribute.class("line-number code-extras")], [
        html.text(line_number_text),
      ]),
      html.text(" "),
    ])
  })

  html.p([attribute.class("loc"), attribute.id(line_tag)], [
    html.span([attribute.class("line-number code-extras")], [
      html.text(line_number_text),
    ]),
    html.span([attribute.attribute("dangerous-unescaped-html", line_text)], []),
    html.span([attribute.class("inline-comment")], [
      element.element(
        line_notes.component_name,
        [
          attribute.attribute(
            "line-notes",
            discussion.get_structured_notes(model.discussion, line_id)
              |> list.map(note.encode_structured_notes)
              |> json.preprocessed_array
              |> json.to_string,
          ),
          attribute.attribute("line-id", line_id),
          attribute.attribute("line-number", line_number_text),
          on_user_submitted_line_note(UserSubmittedNote),
          server_component.include(["detail"]),
        ],
        [],
      ),
    ]),
  ])
}

pub fn style_code_tokens(line_text) {
  let styled_line = line_text

  // Strings really conflict with the html source code ahh. Just ignore them
  // for now, they are not common enough
  // let assert Ok(string_regex) = regexp.from_string("\".*\"")

  // let styled_line =
  //   regexp.match_map(string_regex, styled_line, fn(match) {
  //     html.span([attribute.class("string")], [html.text(match.content)])
  //     |> element.to_string
  //   })

  // First cut out the comments so they don't get any formatting

  let assert Ok(comment_regex) =
    regexp.from_string(
      "(?:\\/\\/.*|^\\s*\\/\\*\\*.*|^\\s*\\*.*|^\\s*\\*\\/.*|\\/\\*.*?\\*\\/)",
    )

  let comments = regexp.scan(comment_regex, styled_line)

  let styled_line = regexp.replace(comment_regex, styled_line, "")

  let assert Ok(operator_regex) =
    regexp.from_string(
      "\\+|\\-|\\*|(?!/)\\/(?!/)|\\={1,2}|\\<(?!span)|(?!span)\\>|\\&|\\!|\\|",
    )

  let styled_line =
    regexp.match_map(operator_regex, styled_line, fn(match) {
      html.span([attribute.class("operator")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(keyword_regex) =
    regexp.from_string(
      "\\b(constructor|contract|fallback|override|mapping|immutable|interface|constant|pragma|solidity|event|error|require|revert|using|for|emit|function|if|else|returns|return|memory|calldata|public|private|external|view|pure|payable|internal|import|enum|struct|storage|is)\\b",
    )

  let styled_line =
    regexp.match_map(keyword_regex, styled_line, fn(match) {
      html.span([attribute.class("keyword")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(global_variable_regex) =
    regexp.from_string(
      "\\b(super|this|msg\\.sender|msg\\.value|tx\\.origin|block\\.timestamp|block\\.chainid)\\b",
    )

  let styled_line =
    regexp.match_map(global_variable_regex, styled_line, fn(match) {
      html.span([attribute.class("global-variable")], [html.text(match.content)])
      |> element.to_string
    })

  // A word with a capital letter at the beginning
  let assert Ok(capitalized_word_regex) = regexp.from_string("\\b[A-Z]\\w+\\b")

  let styled_line =
    regexp.match_map(capitalized_word_regex, styled_line, fn(match) {
      html.span([attribute.class("contract")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(function_regex) = regexp.from_string("\\b(\\w+)\\(")

  let styled_line =
    regexp.match_map(function_regex, styled_line, fn(match) {
      case match.submatches {
        [Some(function_name), ..] ->
          string.replace(
            match.content,
            each: function_name,
            with: element.to_string(
              html.span([attribute.class("function")], [
                html.text(function_name),
              ]),
            ),
          )
        _ -> line_text
      }
    })

  let assert Ok(type_regex) =
    regexp.from_string(
      "\\b(address|bool|bytes|string|int|uint|int\\d+|uint\\d+)\\b",
    )

  let styled_line =
    regexp.match_map(type_regex, styled_line, fn(match) {
      html.span([attribute.class("type")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(number_regex) =
    regexp.from_string(
      "(?<!\\w)\\d+(?:[_ \\.]\\d+)*(?:\\s+(?:days|ether|finney|wei))?(?!\\w)",
    )

  let styled_line =
    regexp.match_map(number_regex, styled_line, fn(match) {
      html.span([attribute.class("number")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(literal_regex) = regexp.from_string("\\b(true|false)\\b")

  let styled_line =
    regexp.match_map(literal_regex, styled_line, fn(match) {
      html.span([attribute.class("number")], [html.text(match.content)])
      |> element.to_string
    })

  styled_line
  <> case comments {
    [regexp.Match(match_content, ..), ..] ->
      html.span([attribute.class("comment")], [html.text(match_content)])
      |> element.to_string
    _ -> ""
  }
}

pub fn on_user_submitted_line_note(msg) {
  use event <- event.on(line_notes.user_submitted_note_event)

  let empty_error = [dynamic.DecodeError("", "", [])]

  use note <- result.try(
    decode.run(
      event,
      decode.field("detail", note.note_decoder(), decode.success),
    )
    |> result.replace_error(empty_error),
  )

  msg(note)
  |> Ok
}
