import gleam/dict
import gleam/int
import gleam/list
import gleam/result
import gleam/string
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
  lustre.component(init, update, view, dict.new())
}

pub type Msg {
  Msg
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

fn view(model: Model) -> element.Element(Msg) {
  html.div([], [
    html.h1([], [html.text(model.page_notes.page_path)]),
    html.div(
      [attribute.class("code-snippet")],
      loc_hmtl(model.preprocessed_source, False),
    ),
  ])
}

pub fn get_skeleton(for page_path) {
  let skeleton_path = config.get_full_page_skeleton_path(for: page_path)

  case simplifile.read(skeleton_path) {
    Ok(skeleton) -> Ok(skeleton)

    Error(simplifile.Enoent) ->
      case generate_skeleton(for: page_path) {
        Ok(skeleton) -> Ok(skeleton)

        Error(msg) -> string.inspect(msg) |> snag.error
      }

    Error(msg) -> string.inspect(msg) |> snag.error
  }
}

/// Generates a skeleton page for the given page path, and writes it to disk.
fn generate_skeleton(for page_path) {
  use source <- result.try(preprocess_source(for: page_path))
  let skeleton =
    html.div([attribute.class("code-snippet")], loc_hmtl(source, True))
    |> element.to_string

  use Nil <- result.map(
    simplifile.write(
      skeleton,
      to: config.get_full_page_skeleton_path(for: page_path),
    )
    |> snag.map_error(simplifile.describe_error),
  )

  skeleton
}

pub fn preprocess_source(for page_path) {
  config.get_full_page_path(for: page_path)
  |> simplifile.read
  |> result.map(string.split(_, on: "\n"))
  |> snag.map_error(simplifile.describe_error)
}

fn loc_hmtl(preprocessed_source text: List(String), skeleton skeleton: Bool) {
  list.index_map(text, fn(original_line, index) {
    case original_line {
      "" -> html.p([attribute.class("loc")], [html.text(" ")])
      _ -> {
        let line = original_line

        case skeleton {
          True ->
            html.p(
              [
                attribute.class("loc"),
                attribute.id("loc" <> int.to_string(index)),
              ],
              [html.text(line)],
            )
          False ->
            html.div([attribute.class("hover-container")], [
              html.p(
                [
                  attribute.class("loc"),
                  attribute.id("loc" <> int.to_string(index)),
                ],
                [
                  html.text(line),
                  html.span([attribute.class("line-hover-discussion")], [
                    html.text("!"),
                  ]),
                ],
              ),
            ])
        }
      }
    }
  })
}
