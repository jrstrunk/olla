import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/result
import gleam/string
import lib/server_componentx
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import o11a/note
import o11a/server/discussion
import o11a/ui/audit_dashboard as dashboard

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(init, update, view, dict.new())
}

pub type Msg {
  ServerUpdatedDiscussion
}

pub type Model {
  Model(discussion: discussion.Discussion, page_path: String)
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

pub fn update(model: Model, _msg: Msg) -> #(Model, effect.Effect(Msg)) {
  #(model, effect.none())
}

fn view(model: Model) -> element.Element(Msg) {
  let #(
    incomplete_todos,
    unanswered_questions,
    unconfirmed_findings,
    confirmed_findings,
  ) = dashboard.find_open_notes(model.discussion, for: Some(model.page_path))

  html.div([], [
    html.div([attribute.class("p-[.5rem]")], [
      server_componentx.hide_skeleton(),
      html.h2(
        [
          attribute.class("mb-[.5rem] fade-in"),
          attribute.style([#("animation-delay", "25ms")]),
        ],
        [html.text("incomplete todos")],
      ),
      notes_view(incomplete_todos, 25),
      html.h2(
        [
          attribute.class("mb-[.5rem] fade-in"),
          attribute.style([#("animation-delay", "50ms")]),
        ],
        [html.text("unanswered questions")],
      ),
      notes_view(unanswered_questions, 50),
      html.h2(
        [
          attribute.class("mb-[.5rem] fade-in"),
          attribute.style([#("animation-delay", "75ms")]),
        ],
        [html.text("unconfirmed findings")],
      ),
      notes_view(unconfirmed_findings, 75),
      html.h2(
        [
          attribute.class("mb-[.5rem] fade-in"),
          attribute.style([#("animation-delay", "100ms")]),
        ],
        [html.text("confirmed findings")],
      ),
      notes_view(confirmed_findings, 100),
    ]),
  ])
}

pub fn notes_view(notes, base_delay) {
  html.ul([attribute.class("mb-[2rem]")], case notes {
    [] -> [
      html.li(
        [
          attribute.class("fade-in"),
          attribute.style([
            #("animation-delay", int.to_string(2 + base_delay) <> "ms"),
          ]),
        ],
        [html.text("none")],
      ),
    ]
    _ ->
      list.index_map(notes, fn(note: #(String, note.Note), index) {
        let line_number =
          note.0
          |> string.split_once("#")
          |> result.unwrap(#("", ""))
          |> pair.second

        html.li(
          [
            attribute.class("fade-in"),
            attribute.style([
              #(
                "animation-delay",
                int.to_string({ { index + 1 } * 2 } + base_delay) <> "ms",
              ),
            ]),
          ],
          [html.text("(" <> line_number <> ") " <> { note.1 }.message)],
        )
      })
  })
}

pub fn get_skeleton() {
  ""
}
