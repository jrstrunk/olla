import concurrent_dict
import given
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/pair
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
import o11a/events
import o11a/note
import o11a/server/discussion
import o11a/server/preprocessor_sol

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
    preprocessed_source: List(preprocessor_sol.PreprocessedSourceLine(Msg)),
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
  io.println("Rendering page " <> model.page_path)

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
  html.div([attribute.class("code-snippet")], [
    case is_skeleton {
      True -> element.fragment([])
      False -> elementx.hide_skeleton()
    },
    ..list.map(model.preprocessed_source, loc_view(model, _, is_skeleton))
  ])
}

fn loc_view(
  model: Model,
  loc: preprocessor_sol.PreprocessedSourceLine(Msg),
  is_skeleton,
) {
  use <- given.that(loc.sigificance == preprocessor_sol.Empty, return: fn() {
    html.p([attribute.class("loc"), attribute.id(loc.line_tag)], [
      html.span([attribute.class("line-number code-extras")], [
        html.text(loc.line_number_text),
      ]),
      html.text(loc.line_text_raw),
    ])
  })

  let notes =
    discussion.get_notes(model.discussion, loc.line_id)
    |> result.unwrap([])

  let parent_notes =
    list.filter_map(notes, fn(note) {
      case note.parent_id == loc.line_id {
        True -> Ok(note)
        False -> Error(Nil)
      }
    })

  let info_notes =
    parent_notes
    |> list.filter(fn(computed_note) {
      computed_note.significance == computed_note.Informational
    })
    |> list.map(split_info_note(_, loc.leading_spaces))
    |> list.flatten

  html.div(
    [
      attribute.id(loc.line_tag),
      attribute.class("line-container"),
      attribute.data("line-number", loc.line_number_text),
    ],
    [
      element.keyed(element.fragment, {
        use note, index <- list.index_map(info_notes)

        let child =
          html.p([attribute.class("loc flex")], [
            html.span(
              [attribute.class("line-number code-extras relative italic")],
              [
                html.text(loc.line_number_text),
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
              html.text(loc.leading_spaces <> note.1),
            ]),
          ])

        #(note.0, child)
      }),
      html.p([attribute.class("loc flex")], [
        html.span([attribute.class("line-number code-extras")], [
          html.text(loc.line_number_text),
        ]),
        case loc.preprocessed_line {
          preprocessor_sol.PreprocessedLine(preprocessed_line_text) ->
            element.fragment([
              html.span(
                [
                  attribute.attribute(
                    "dangerous-unescaped-html",
                    preprocessed_line_text,
                  ),
                ],
                [],
              ),
              html.span([attribute.class("inline-comment relative font-code")], [
                inline_comment_preview_view(parent_notes),
                case is_skeleton {
                  True -> element.fragment([])
                  // The line discussion component is too close to the edge of the
                  // screen, so we want to show it below the line
                  False ->
                    element.element(
                      components.line_discussion,
                      [
                        attribute.class(
                          "absolute z-[3] w-[30rem] invisible not-italic text-wrap select-text left-[-.3rem] "
                          <> case loc.line_number < 27 {
                            True -> "top-[1.4rem]"
                            False -> "bottom-[1.4rem]"
                          },
                        ),
                        attribute.attribute("line-number", loc.line_number_text),
                        attribute.attribute("line-id", loc.line_id),
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
            ])
          preprocessor_sol.PreprocessedContractDefinition(
            contract_name,
            contract_inheritances,
            process_line,
          ) ->
            element.fragment([
              process_line(
                html.div([attribute.class(contract_name)], []),
                list.map(contract_inheritances, fn(inheritance) {
                  html.span([attribute.class(inheritance.id <> " contract")], [
                    html.text(inheritance.name),
                  ])
                }),
              ),
              html.span([attribute.class("inline-comment relative font-code")], [
                inline_comment_preview_view(parent_notes),
                case is_skeleton {
                  True -> element.fragment([])
                  // The line discussion component is too close to the edge of the
                  // screen, so we want to show it below the line
                  False ->
                    element.element(
                      components.line_discussion,
                      [
                        attribute.class(
                          "absolute z-[3] w-[30rem] invisible not-italic text-wrap select-text left-[-.3rem] "
                          <> case loc.line_number < 27 {
                            True -> "top-[1.4rem]"
                            False -> "bottom-[1.4rem]"
                          },
                        ),
                        attribute.attribute("line-number", loc.line_number_text),
                        attribute.attribute("line-id", loc.line_id),
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
            ])
        },
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

fn split_info_note(note: computed_note.ComputedNote, leading_spaces) {
  note.message
  |> split_info_comment(note.expanded_message != None, leading_spaces)
  |> list.index_map(fn(comment, index) {
    #(note.note_id <> int.to_string(index), comment)
  })
}

pub fn split_info_comment(
  comment: String,
  contains_expanded_message: Bool,
  leading_spaces,
) {
  let comment_length = string.length(comment)
  let columns_remaining = 80 - string.length(leading_spaces)

  case comment_length <= columns_remaining {
    True -> [
      comment
      <> case contains_expanded_message {
        True -> "^"
        False -> ""
      },
    ]
    False -> {
      let backwards =
        string.slice(comment, 0, columns_remaining)
        |> string.reverse

      let in_limit_comment_length =
        backwards
        |> string.split_once(" ")
        |> result.unwrap(#("", backwards))
        |> pair.second
        |> string.length

      let rest =
        string.slice(
          comment,
          in_limit_comment_length + 1,
          length: comment_length,
        )

      [
        string.slice(comment, 0, in_limit_comment_length),
        ..split_info_comment(rest, contains_expanded_message, leading_spaces)
      ]
    }
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
