import filepath
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import gleam/string
import lustre/attribute
import lustre/element/html
import o11a/computed_note

const style = "
.dashboard-link {
  text-decoration: none;
  color: var(--text-color);
}

.dashboard-link:hover {
  text-decoration: underline;
}
"

pub fn view(notes, audit_name) {
  let #(
    incomplete_todos,
    unanswered_questions,
    unconfirmed_findings,
    confirmed_findings,
  ) = find_open_notes(notes, for: None)

  html.div([attribute.style("margin-left", "2rem")], [
    html.style([], style),
    html.div([attribute.style("width", "40rem")], [
      html.h1([], [
        html.text(audit_name |> string.capitalise <> " Audit Dashboard"),
      ]),
      html.h2([], [html.text("Incomplete todos")]),
      notes_view(incomplete_todos),
      html.h2([], [html.text("Unanswered questions")]),
      notes_view(unanswered_questions),
      html.h2([], [html.text("Unconfirmed findings")]),
      notes_view(unconfirmed_findings),
      html.h2([], [html.text("Confirmed findings")]),
      notes_view(confirmed_findings),
    ]),
  ])
}

fn notes_view(notes) {
  html.ul(
    [],
    list.map(notes, fn(note: computed_note.ComputedNote) {
      html.li([], [
        html.a(
          [
            attribute.href("/" <> note.parent_id),
            attribute.class("dashboard-link"),
          ],
          [html.text(note.parent_id |> filepath.base_name)],
        ),
        html.text(" - " <> note.message),
      ])
    }),
  )
}

pub fn find_open_notes(in notes, for page_path) {
  let all_notes =
    case page_path {
      Some(page_path) ->
        dict.to_list(notes)
        |> list.filter_map(fn(note_data) {
          // The note_id will be the page path + the line number, but we want
          // everything in the page path
          case string.starts_with(note_data.0, page_path) {
            True -> Ok(note_data.1)
            False -> Error(Nil)
          }
        })

      None ->
        dict.to_list(notes)
        |> list.map(pair.second)
    }
    |> list.flatten

  let incomplete_todos =
    list.filter(all_notes, fn(note: computed_note.ComputedNote) {
      case note.significance {
        computed_note.IncompleteToDo -> True
        _ -> False
      }
    })

  let _complete_todos =
    list.filter(all_notes, fn(note) {
      case note.significance {
        computed_note.CompleteToDo -> True
        _ -> False
      }
    })

  let unanswered_questions =
    list.filter(all_notes, fn(note) {
      case note.significance {
        computed_note.UnansweredQuestion -> True
        _ -> False
      }
    })

  let _answered_questions =
    list.filter(all_notes, fn(note) {
      case note.significance {
        computed_note.AnsweredQuestion -> True
        _ -> False
      }
    })

  let unconfirmed_findings =
    list.filter(all_notes, fn(note) {
      case note.significance {
        computed_note.UnconfirmedFinding -> True
        _ -> False
      }
    })

  let confirmed_findings =
    list.filter(all_notes, fn(note) {
      case note.significance {
        computed_note.ConfirmedFinding -> True
        _ -> False
      }
    })

  #(
    incomplete_todos,
    unanswered_questions,
    unconfirmed_findings,
    confirmed_findings,
  )
}
