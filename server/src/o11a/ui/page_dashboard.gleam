import gleam/dict
import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/result
import gleam/string
import lib/elementx
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import o11a/note
import o11a/server/discussion
import o11a/ui/audit_dashboard as dashboard

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(init, update, cached_view, dict.new())
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

fn cached_view(model: Model) -> element.Element(Msg) {
  let render = view(model)

  // Update the skeleton so the initial render on the client's request is up to
  // date with server state.
  discussion.set_skeleton(
    model.discussion,
    for: get_skeleton_key(model.page_path),
    skeleton: render |> element.to_string,
  )

  render
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
      elementx.hide_skeleton(),
      html.h2([attribute.class("mb-[.5rem]")], [html.text("incomplete todos")]),
      notes_view(incomplete_todos),
      html.h2([attribute.class("mb-[.5rem]")], [
        html.text("unanswered questions"),
      ]),
      notes_view(unanswered_questions),
      html.h2([attribute.class("mb-[.5rem]")], [
        html.text("unconfirmed findings"),
      ]),
      notes_view(unconfirmed_findings),
      html.h2([attribute.class("mb-[.5rem]")], [html.text("confirmed findings")]),
      notes_view(confirmed_findings),
    ]),
  ])
}

pub fn notes_view(notes) {
  html.ul([attribute.class("mb-[2rem] text-[.9rem]")], case notes {
    [] -> [html.li([], [html.text("none")])]
    _ ->
      list.map(notes, fn(note: #(String, note.Note)) {
        let line_number =
          note.0
          |> string.split_once("#")
          |> result.unwrap(#("", ""))
          |> pair.second

        html.li([], [
          html.text("(" <> line_number <> ") " <> { note.1 }.message),
        ])
      })
  })
}

fn get_skeleton_key(for page_path) {
  "dsc" <> page_path
}

pub fn get_skeleton(discussion, for page_path) {
  case discussion.get_skeleton(discussion, for: get_skeleton_key(page_path)) {
    Ok(skeleton) -> skeleton
    Error(Nil) -> {
      let skeleton =
        html.div([], [
          html.div([attribute.class("p-[.5rem]")], [
            html.h2([attribute.class("mb-[.5rem]")], [
              html.text("incomplete todos"),
            ]),
            html.p([attribute.class("comment mb-[2rem] text-[.9rem]")], [
              html.text("..."),
            ]),
            html.h2([attribute.class("mb-[.5rem]")], [
              html.text("unanswered questions"),
            ]),
            html.p([attribute.class("comment mb-[2rem] text-[.9rem]")], [
              html.text("..."),
            ]),
            html.h2([attribute.class("mb-[.5rem]")], [
              html.text("unconfirmed findings"),
            ]),
            html.p([attribute.class("comment mb-[2rem] text-[.9rem]")], [
              html.text("..."),
            ]),
            html.h2([attribute.class("mb-[.5rem]")], [
              html.text("confirmed findings"),
            ]),
            html.p([attribute.class("comment mb-[2rem] text-[.9rem]")], [
              html.text("..."),
            ]),
          ]),
        ])
        |> element.to_string

      discussion.set_skeleton(discussion, for: page_path <> "dsc", skeleton:)

      skeleton
    }
  }
}
