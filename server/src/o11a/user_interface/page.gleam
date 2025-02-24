import given
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
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
}

pub type Model {
  Model(
    page_path: String,
    preprocessed_source: List(String),
    discussion: discussion.Discussion,
  )
}

pub fn init(init_model) -> #(Model, effect.Effect(Msg)) {
  #(init_model, effect.none())
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserSubmittedNote(note) -> {
      io.debug("adding note")
      let assert Ok(Nil) = discussion.add_note(model.discussion, note)
      #(model, effect.none())
    }
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
  |> result.map(string.split(_, on: "\n"))
  |> snag.map_error(simplifile.describe_error)
}

fn loc_view(model: Model, line_text, line_number, is_skeleton is_skeleton) {
  let line_number_text = int.to_string(line_number)
  let line_tag = "L" <> line_number_text
  let line_id = model.page_path <> "#" <> line_tag

  use <- given.that(is_skeleton, return: fn() {
    html.p([attribute.class("loc"), attribute.id(line_tag)], [
      html.span([attribute.class("line-number faded-code-extras")], [
        html.text(line_number_text),
      ]),
      html.text(line_text),
    ])
  })

  use <- given.that(line_text == "", return: fn() {
    html.p([attribute.class("loc"), attribute.id(line_tag)], [
      html.span([attribute.class("line-number faded-code-extras")], [
        html.text(line_number_text),
      ]),
      html.text(" "),
    ])
  })

  let line_comments = discussion.get_structured_notes(model.discussion, line_id)

  let inline_comment_preview_text = case
    line_comments |> list.reverse |> list.take(1)
  {
    [comment] -> comment.message |> string.slice(at_index: 0, length: 30)
    _ -> "+"
  }

  html.p([attribute.class("loc"), attribute.id(line_tag)], [
    html.span([attribute.class("line-number faded-code-extras")], [
      html.text(line_number_text),
    ]),
    html.text(line_text),
    html.span(
      [
        attribute.class("inline-comment"),
        attribute.class("fade-in"),
        attribute.style([
          #("animation-delay", int.to_string(line_number * 4) <> "ms"),
        ]),
      ],
      [
        html.span([attribute.class("loc faded-code-extras")], [
          html.text(inline_comment_preview_text),
        ]),
        element.element(
          line_notes.component_name,
          [
            attribute.attribute(
              "line-notes",
              list.map(line_comments, note.encode_note)
                |> json.preprocessed_array
                |> json.to_string,
            ),
            attribute.attribute("line-id", line_id),
            on_user_submitted_line_note(UserSubmittedNote),
            server_component.include(["detail"]),
          ],
          [],
        ),
      ],
    ),
  ])
}

pub fn on_user_submitted_line_note(msg) {
  use event <- event.on(line_notes.user_submitted_note_event)
  io.debug("user submitted line note")

  let empty_error = [dynamic.DecodeError("", "", [])]

  use note <- result.try(
    decode.run(
      event,
      decode.field("detail", note.json_note_decoder(), decode.success),
    )
    |> result.replace_error(empty_error),
  )

  msg(note)
  |> Ok
}
