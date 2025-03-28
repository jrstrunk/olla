import concurrent_dict
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
import o11a/classes
import o11a/computed_note
import o11a/events
import o11a/note
import o11a/server/discussion
import o11a/server/preprocessor_sol as preprocessor

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(
    init,
    update,
    cached_view,
    dict.from_list([
      #("note-submission", fn(dy) {
        use note_data <- result.try(
          decode.run(dy, decode.string)
          |> result.replace_error([
            dynamic.DecodeError(
              "json-encoded computed note",
              string.inspect(dy),
              [],
            ),
          ]),
        )

        use #(note, topic_id) <- result.map(
          json.parse(note_data, {
            use topic_id <- decode.field("topic_id", decode.string)
            use note_submission <- decode.field(
              "note_submission",
              note.note_submission_decoder(),
            )

            decode.success(#(note_submission, topic_id))
          })
          |> result.replace_error([
            dynamic.DecodeError(
              "json-encoded note submission",
              string.inspect(note_data),
              [],
            ),
          ]),
        )

        UserSubmittedNote(note, topic_id)
      }),
    ]),
  )
}

pub type Msg {
  UserSubmittedNote(note_submission: note.NoteSubmission, topic_id: String)
  ServerUpdatedDiscussion
}

pub type Model {
  Model(
    page_path: String,
    preprocessed_source: List(preprocessor.PreProcessedLine(Msg)),
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
    UserSubmittedNote(note_submission:, topic_id:) -> {
      let assert Ok(Nil) =
        discussion.add_note(model.discussion, note_submission, topic_id:)
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
    html.script(
      [attribute.type_("application/json"), attribute.id("discussion-data")],
      discussion.dump_computed_notes(model.discussion) |> json.to_string,
    ),
    ..list.map(model.preprocessed_source, loc_view(model, _))
  ])
}

fn loc_view(model: Model, loc: preprocessor.PreProcessedLine(Msg)) {
  case loc.significance {
    preprocessor.EmptyLine -> {
      html.p([attribute.class("loc"), attribute.id(loc.line_tag)], [
        html.span([attribute.class("line-number code-extras")], [
          html.text(loc.line_number_text),
        ]),
        html.span(
          [attribute.attribute("dangerous-unescaped-html", loc.elements)],
          [],
        ),
      ])
    }

    preprocessor.SingleDeclarationLine(topic_id:, ..) ->
      line_container_view(model:, loc:, line_topic_id: topic_id)

    preprocessor.NonEmptyLine ->
      line_container_view(model:, loc:, line_topic_id: loc.line_id)
  }
}

fn line_container_view(
  model model: Model,
  loc loc: preprocessor.PreProcessedLine(Msg),
  line_topic_id line_topic_id: String,
) {
  let #(parent_notes, info_notes) =
    get_notes(model.discussion, loc.leading_spaces, line_topic_id)

  html.div(
    [
      attribute.id(loc.line_tag),
      attribute.class("line-container"),
      attribute.data("line-number", loc.line_number_text),
    ],
    [
      element.keyed(element.fragment, {
        use #(note_index_id, note_message), index <- list.index_map(info_notes)

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
              html.text(
                list.repeat(" ", loc.leading_spaces) |> string.join("")
                <> note_message,
              ),
            ]),
          ])

        #(note_index_id, child)
      }),
      html.p([attribute.class("loc flex")], [
        html.span([attribute.class("line-number code-extras")], [
          html.text(loc.line_number_text),
        ]),
        html.span(
          [attribute.attribute("dangerous-unescaped-html", loc.elements)],
          [],
        ),
        html.span([attribute.class("inline-comment relative font-code")], [
          inline_comment_preview_view(parent_notes),
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
          attribute.class("comment-preview"),
          attribute.class(classes.discussion_entry),
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
          attribute.class("new-thread-preview"),
          attribute.class(classes.discussion_entry),
          attribute.class(classes.discussion_entry),
          attribute.attribute("tabindex", "0"),
        ],
        [html.text("Start new thread")],
      )
  }
}

fn get_notes(
  discussion: discussion.Discussion,
  leading_spaces leading_spaces,
  topic_id topic_id,
) {
  let parent_notes =
    discussion.get_notes(discussion, topic_id)
    |> result.unwrap([])
    |> list.filter_map(fn(note) {
      case note.parent_id == topic_id {
        True -> Ok(note)
        False -> Error(Nil)
      }
    })

  let info_notes =
    parent_notes
    |> list.filter(fn(computed_note) {
      computed_note.significance == computed_note.Informational
    })
    |> list.map(split_info_note(_, leading_spaces))
    |> list.flatten

  #(parent_notes, info_notes)
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
  let columns_remaining = 80 - leading_spaces

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
      decode.subfield(
        ["detail", "note"],
        note.note_submission_decoder(),
        decode.success,
      ),
    )
    |> result.replace_error(empty_error),
  )

  use topic_id <- result.try(
    decode.run(
      event,
      decode.subfield(["detail", "topic_id"], decode.string, decode.success),
    )
    |> result.replace_error(empty_error),
  )

  msg(note, topic_id)
  |> Ok
}
