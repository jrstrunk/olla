import given
import gleam/dict
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lib/server_componentx
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import o11a/config
import server/discussion
import simplifile
import snag

pub const name = "o11a-discussions"

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(init, update, view(_, False), dict.new())
}

pub type Msg {
  UserSubmittedNote
}

pub type Model {
  Model(preprocessed_source: List(String), page_notes: discussion.PageNotes)
}

pub fn init(init_model) -> #(Model, effect.Effect(Msg)) {
  #(init_model, effect.none())
}

pub fn update(model: Model, _msg: Msg) -> #(Model, effect.Effect(Msg)) {
  #(model, effect.none())
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
            preprocessed_source: source,
            page_notes: discussion.empty_page_notes(page_path),
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

fn loc_view(_model: Model, line_text, line_number, is_skeleton is_skeleton) {
  let line_number = int.to_string(line_number)

  use <- given.that(is_skeleton, return: fn() {
    html.p([attribute.class("loc"), attribute.id("L" <> line_number)], [
      html.span([attribute.class("line-number faded-code-extras")], [
        html.text(line_number),
      ]),
      html.text(line_text),
    ])
  })

  use <- given.that(line_text == "", return: fn() {
    html.p([attribute.class("loc")], [
      html.span([attribute.class("line-number faded-code-extras")], [
        html.text(line_number),
      ]),
      html.text(" "),
    ])
  })

  let comment_text =
    "this is a comment that keeps on going on and on and on and on and on and on and it just keeps on going and it wont stop ever at all forever and ever and on and ever and on and ever and on"

  html.div([attribute.class("hover-container")], [
    html.p([attribute.class("loc"), attribute.id("L" <> line_number)], [
      html.span([attribute.class("line-number faded-code-extras")], [
        html.text(line_number),
      ]),
      html.text(line_text),
      html.span([attribute.class("loc"), attribute.class("inline-comment")], [
        html.span([attribute.class("line-hover-discussion")], [
          html.text(comment_text),
          // html.input([event.on_submit()]),
        ]),
        html.span(
          [
            attribute.class("loc"),
            attribute.class("inline-comment-text faded-code-extras"),
          ],
          [html.text(comment_text |> string.slice(at_index: 0, length: 30))],
        ),
      ]),
    ]),
  ])
}
