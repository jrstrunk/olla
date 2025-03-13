import concurrent_dict
import given
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/regexp
import gleam/result
import gleam/string
import lib/elementx
import lib/enumerate
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import lustre/server_component
import o11a/components
import o11a/computed_note
import o11a/config
import o11a/events
import o11a/note
import o11a/server/discussion
import simplifile

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(init, update, cached_view, dict.new())
}

pub type Msg {
  UserSubmittedNote(note: note.Note, line_id: String)
  ServerUpdatedDiscussion
}

pub type Model {
  Model(
    page_path: String,
    preprocessed_source: List(String),
    discussion: discussion.Discussion,
    skeletons: concurrent_dict.ConcurrentDict(String, String),
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
    UserSubmittedNote(note, line_id) -> {
      let assert Ok(Nil) = discussion.add_note(model.discussion, note, line_id)
      #(model, effect.none())
    }
    ServerUpdatedDiscussion -> #(model, effect.none())
  }
}

fn cached_view(model: Model) -> element.Element(Msg) {
  // Update the skeleton so the initial render on the client's request is up to
  // date with server state.
  concurrent_dict.insert(
    model.skeletons,
    get_skeleton_key(model.page_path),
    view(model, is_skeleton: True) |> element.to_string,
  )

  view(model, is_skeleton: False)
}

fn get_skeleton_key(for page_path) {
  "adpg" <> page_path
}

pub fn get_skeleton(skeletons, for page_path) {
  concurrent_dict.get(skeletons, get_skeleton_key(page_path))
  |> result.unwrap("")
}

fn view(model: Model, is_skeleton is_skeleton) -> element.Element(Msg) {
  io.println("Rendering page " <> model.page_path)

  html.div([attribute.class("code-snippet")], [
    case is_skeleton {
      True -> element.fragment([])
      False -> elementx.hide_skeleton()
    },
    ..list.index_map(model.preprocessed_source, fn(line, index) {
      loc_view(model, line, index + 1, is_skeleton)
    })
  ])
}

pub fn preprocess_source(for page_path) {
  config.get_full_page_path(for: page_path)
  |> simplifile.read
  |> result.map(string.split(_, on: "\n"))
  |> result.map(list.map(_, style_code_tokens))
}

fn loc_view(model: Model, line_text, line_number, is_skeleton) {
  let line_number_text = int.to_string(line_number)
  let line_tag = "L" <> line_number_text
  let line_id = model.page_path <> "#" <> line_tag

  use <- given.that(line_text == "", return: fn() {
    html.p([attribute.class("loc"), attribute.id(line_tag)], [
      html.span([attribute.class("line-number code-extras")], [
        html.text(line_number_text),
      ]),
      html.text(" "),
    ])
  })

  let notes =
    discussion.get_notes(model.discussion, line_id)
    |> result.unwrap([])

  let parent_notes =
    list.filter_map(notes, fn(note) {
      case note.parent_id == line_id {
        True -> Ok(note)
        False -> Error(Nil)
      }
    })

  let info_notes =
    parent_notes
    |> list.filter(fn(computed_note) {
      computed_note.significance == computed_note.Informational
    })

  html.div(
    [
      attribute.id(line_tag),
      attribute.class("line-container"),
      attribute.data("line-number", line_number_text),
    ],
    [
      element.fragment(
        list.index_map(info_notes, fn(note, index) {
          html.p([attribute.class("loc flex"), attribute.id(note.note_id)], [
            html.span(
              [attribute.class("line-number code-extras relative italic")],
              [
                html.text(line_number_text),
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
                enumerate.get_leading_spaces(line_text)
                <> note.message
                <> case note.expanded_message {
                  Some(..) -> "*"
                  None -> ""
                },
              ),
            ]),
          ])
        }),
      ),
      html.p([attribute.class("loc flex")], [
        html.span([attribute.class("line-number code-extras")], [
          html.text(line_number_text),
        ]),
        html.span(
          [attribute.attribute("dangerous-unescaped-html", line_text)],
          [],
        ),
        html.span([attribute.class("inline-comment relative font-code")], [
          inline_comment_preview_view(parent_notes),
          case is_skeleton {
            True -> element.fragment([])
            False ->
              element.element(
                components.line_discussion,
                [
                  attribute.class(
                    "absolute z-[3] w-[30rem] invisible not-italic text-wrap select-text left-[-.3rem] bottom-[1.4rem]",
                  ),
                  attribute.attribute("line-number", line_number_text),
                  attribute.attribute("line-id", line_id),
                  attribute.attribute(
                    "line-discussion",
                    notes
                      |> computed_note.encode_computed_notes
                      |> json.to_string,
                  ),
                  on_user_submitted_line_note(UserSubmittedNote),
                  server_component.include(["detail"]),
                ],
                [],
              )
          },
        ]),
      ]),
    ],
  )
}

fn inline_comment_preview_view(parent_notes: List(computed_note.ComputedNote)) {
  let note_result =
    list.reverse(parent_notes)
    |> list.find(fn(note) { note.significance != computed_note.Informational })

  case note_result {
    Ok(note) ->
      html.span(
        [
          attribute.class("code-extras font-code fade-in"),
          attribute.class("comment-preview discussion-entry"),
          attribute.attribute("tabindex", "0"),
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
          attribute.class("code-extras"),
          attribute.class("new-thread-preview discussion-entry"),
          attribute.attribute("tabindex", "0"),
        ],
        [html.text("Start new thread")],
      )
  }
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
      "\\b(constructor|contract|fallback|override|mapping|immutable|interface|constant|pragma|library|solidity|event|error|require|revert|using|for|emit|function|if|else|returns|return|memory|calldata|public|private|external|view|pure|payable|internal|import|enum|struct|storage|is)\\b",
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
  use event <- event.on(events.user_submitted_note)

  let empty_error = [dynamic.DecodeError("", "", [])]

  use note <- result.try(
    decode.run(
      event,
      decode.subfield(["detail", "note"], note.note_decoder(), decode.success),
    )
    |> result.replace_error(empty_error),
  )

  use line_id <- result.try(
    decode.run(
      event,
      decode.subfield(["detail", "line_id"], decode.string, decode.success),
    )
    |> result.replace_error(empty_error),
  )

  msg(note, line_id)
  |> Ok
}
