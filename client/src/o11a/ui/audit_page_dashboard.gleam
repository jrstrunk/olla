import gleam/list
import gleam/option.{Some}
import gleam/pair
import gleam/result
import gleam/string
import lib/elementx
import lustre/attribute
import lustre/element/html
import o11a/computed_note
import o11a/ui/audit_dashboard as dashboard

pub fn view(notes, page_path, topics) {
  let #(
    incomplete_todos,
    unanswered_questions,
    unconfirmed_findings,
    confirmed_findings,
  ) = dashboard.find_open_notes(notes, for: Some(page_path), topics:)

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
      list.map(notes, fn(note: computed_note.ComputedNote) {
        let line_number =
          note.parent_id
          |> string.split_once("#")
          |> result.unwrap(#("", ""))
          |> pair.second

        html.li([], [html.text("(" <> line_number <> ") " <> note.message)])
      })
  })
}
