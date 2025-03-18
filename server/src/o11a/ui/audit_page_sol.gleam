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
import o11a/server/preprocessor_sol as preprocessor

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(init, update, cached_view, dict.new())
}

pub type Msg {
  UserSubmittedNote(note: note.Note, topic_id: String)
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
    UserSubmittedNote(note:, topic_id:) -> {
      let assert Ok(Nil) =
        discussion.add_note(model.discussion, note, topic_id:)
      #(model, effect.none())
    }
    ServerUpdatedDiscussion -> #(model, effect.none())
  }
}

fn cached_view(model: Model) -> element.Element(Msg) {
  io.print("Rendering page " <> model.page_path)

  // Update the skeleton so the initial render on the client's request is up to
  // date with server state.
  concurrent_dict.insert(
    model.skeletons,
    get_skeleton_key(model.page_path),
    view(model, is_skeleton: True) |> element.to_string,
  )

  io.print(", cached")
  let v = view(model, is_skeleton: False)

  io.println(", rendered")
  v
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

fn loc_view(model: Model, loc: preprocessor.PreProcessedLine(Msg), is_skeleton) {
  case loc.significance {
    preprocessor.EmptyLine -> {
      html.p([attribute.class("loc"), attribute.id(loc.line_tag)], [
        html.span([attribute.class("line-number code-extras")], [
          html.text(loc.line_number_text),
        ]),
        ..list.map(loc.nodes, empty_node_view)
      ])
    }

    preprocessor.SingleDeclarationLine(topic_id:, title:) ->
      line_container_view(
        model:,
        loc:,
        line_topic_id: topic_id,
        line_topic_title: title,
        is_single_declaration_line: True,
        is_skeleton:,
      )

    preprocessor.NonEmptyLine ->
      line_container_view(
        model:,
        loc:,
        line_topic_id: loc.line_id,
        line_topic_title: "line " <> loc.line_number_text,
        is_single_declaration_line: False,
        is_skeleton:,
      )
  }
}

fn line_container_view(
  model model: Model,
  loc loc: preprocessor.PreProcessedLine(Msg),
  line_topic_id line_topic_id: String,
  line_topic_title line_topic_title: String,
  is_single_declaration_line is_single_declaration_line,
  is_skeleton is_skeleton,
) {
  let #(notes, parent_notes, info_notes) =
    get_notes(model.discussion, loc.leading_spaces, line_topic_id)

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
              html.text(
                list.repeat(" ", loc.leading_spaces) |> string.join("")
                <> note.1,
              ),
            ]),
          ])

        #(note.0, child)
      }),
      html.p([attribute.class("loc flex")], [
        html.span([attribute.class("line-number code-extras")], [
          html.text(loc.line_number_text),
        ]),
        element.fragment(
          list.map(loc.nodes, fn(node) {
            case node {
              preprocessor.PreProcessedNode(element:)
              | preprocessor.PreProcessedGapNode(element:, ..) -> element

              preprocessor.PreProcessedDeclaration(
                build_element:,
                node_declaration:,
              ) ->
                build_element(discussion_overlay_view(
                  model:,
                  line_number: loc.line_number,
                  topic_id: node_declaration.topic_id,
                  topic_title: node_declaration.title,
                  is_reference: False,
                  notes: case is_single_declaration_line {
                    True -> option.Some(notes)
                    False -> option.None
                  },
                  is_skeleton:,
                ))

              preprocessor.PreProcessedReference(
                build_element:,
                referenced_node_declaration:,
              ) ->
                build_element(discussion_overlay_view(
                  model:,
                  line_number: loc.line_number,
                  topic_id: referenced_node_declaration.topic_id,
                  topic_title: referenced_node_declaration.title,
                  is_reference: True,
                  notes: None,
                  is_skeleton:,
                ))
            }
          }),
        ),
        html.span([attribute.class("inline-comment relative font-code")], [
          inline_comment_preview_view(parent_notes),
          discussion_overlay_view(
            model:,
            line_number: loc.line_number,
            topic_id: line_topic_id,
            topic_title: line_topic_title,
            is_reference: False,
            notes: option.Some(notes),
            is_skeleton:,
          ),
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

fn empty_node_view(node: preprocessor.PreProcessedNode(Msg)) {
  case node {
    preprocessor.PreProcessedNode(element:)
    | preprocessor.PreProcessedGapNode(element:, ..) -> element

    preprocessor.PreProcessedDeclaration(build_element:, ..)
    | preprocessor.PreProcessedReference(build_element:, ..) ->
      build_element(element.fragment([]))
  }
}

fn discussion_overlay_view(
  model model: Model,
  line_number line_number,
  topic_id topic_id,
  topic_title topic_title,
  is_reference is_reference,
  notes notes: option.Option(List(computed_note.ComputedNote)),
  is_skeleton is_skeleton,
) {
  use <- given.that(is_skeleton, return: fn() { element.fragment([]) })

  let reference_notes =
    notes
    |> option.unwrap(
      discussion.get_notes(model.discussion, topic_id)
      |> result.unwrap([]),
    )

  element.element(
    components.line_discussion,
    [
      attribute.class(
        "absolute z-[3] w-[30rem] invisible not-italic text-wrap select-text left-[-.3rem]",
      ),
      // The line discussion component is too close to the edge of the
      // screen, so we want to show it below the line
      case line_number < 27 {
        True -> attribute.class("top-[1.4rem]")
        False -> attribute.class("bottom-[1.4rem]")
      },
      attribute.attribute(
        "dsc-data",
        json.object([
          #("topic_id", json.string(topic_id)),
          #("topic_title", json.string(topic_title)),
          #("line_number", json.int(0)),
          #("is_reference", json.bool(is_reference)),
        ])
          |> json.to_string,
      ),
      attribute.attribute(
        "dsc",
        computed_note.encode_computed_notes(reference_notes)
          |> json.to_string,
      ),
      on_user_submitted_line_note(UserSubmittedNote),
      server_component.include(["detail"]),
    ],
    [],
  )
}

fn get_notes(
  discussion: discussion.Discussion,
  leading_spaces leading_spaces,
  topic_id topic_id,
) {
  let notes =
    discussion.get_notes(discussion, topic_id)
    |> result.unwrap([])

  let parent_notes =
    list.filter_map(notes, fn(note) {
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

  #(notes, parent_notes, info_notes)
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
      decode.subfield(["detail", "note"], note.note_decoder(), decode.success),
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
