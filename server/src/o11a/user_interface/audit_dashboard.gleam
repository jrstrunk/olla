import filepath
import gleam/dict
import gleam/list
import gleam/string
import lib/persistent_concurrent_duplicate_dict as pcd_dict
import lib/server_componentx
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import o11a/note
import o11a/server/discussion

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(init, update, view, dict.new())
}

pub type Msg {
  ServerUpdatedDiscussion
}

pub type Model {
  Model(discussion: discussion.Discussion)
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

const style = "
.dashboard-link {
  text-decoration: none;
  color: var(--text-color);
}

.dashboard-link:hover {
  text-decoration: underline;
}
"

fn view(model: Model) -> element.Element(Msg) {
  let container_styles = [#("margin-left", "2rem")]

  let #(
    incomplete_todos,
    unanswered_questions,
    unconfirmed_findings,
    confirmed_findings,
  ) = find_open_notes(model.discussion)

  html.div([attribute.style(container_styles)], [
    html.style([], style),
    html.div([attribute.style([#("width", "40rem")])], [
      server_componentx.hide_skeleton(),
      html.h1([], [
        html.text(
          model.discussion.audit_name |> string.capitalise <> " audit dashboard",
        ),
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
    list.map(notes, fn(note: #(String, note.Note)) {
      html.li([], [
        html.a(
          [attribute.href("/" <> note.0), attribute.class("dashboard-link")],
          [html.text(note.0 |> filepath.base_name)],
        ),
        html.text(" - " <> { note.1 }.message),
      ])
    }),
  )
}

pub fn get_skeleton(for discussion) {
  Model(discussion:)
  |> view
}

pub fn find_open_notes(in discussion: discussion.Discussion) {
  let all_notes = pcd_dict.to_list(discussion.notes)

  let all_todos =
    list.filter(all_notes, fn(note) {
      case { note.1 }.significance {
        note.ToDo -> True
        _ -> False
      }
    })

  let incomplete_todos =
    list.filter(all_todos, fn(note) {
      let thread_notes = pcd_dict.get(discussion.notes, { note.1 }.note_id)

      let closing_note =
        list.find(thread_notes, fn(thread_note) {
          case { thread_note }.significance {
            note.ToDoDone -> True
            _ -> False
          }
        })

      // If we do not find a done note, then the todo is still open.
      case closing_note {
        Ok(..) -> False
        Error(Nil) -> True
      }
    })

  let all_questions =
    list.filter(all_notes, fn(note) {
      case { note.1 }.significance {
        note.Question -> True
        _ -> False
      }
    })

  let unanswered_questions =
    list.filter(all_questions, fn(note) {
      let thread_notes = pcd_dict.get(discussion.notes, { note.1 }.note_id)

      let closing_note =
        list.find(thread_notes, fn(thread_note) {
          case { thread_note }.significance {
            note.Answer -> True
            _ -> False
          }
        })

      // If we do not find an answer, then the question is still unanswered.
      case closing_note {
        Ok(..) -> False
        Error(Nil) -> True
      }
    })

  let all_findings =
    list.filter(all_notes, fn(note) {
      case { note.1 }.significance {
        note.FindingLead -> True
        _ -> False
      }
    })

  let unconfirmed_findings =
    list.filter(all_findings, fn(note) {
      let thread_notes = pcd_dict.get(discussion.notes, { note.1 }.note_id)

      let closing_note =
        list.find(thread_notes, fn(thread_note) {
          case { thread_note }.significance {
            note.FindingRejection -> True
            note.FindingConfirmation -> True
            _ -> False
          }
        })

      // If we do not find a rejection, then the finding is still open.
      case closing_note {
        Ok(..) -> False
        Error(Nil) -> True
      }
    })

  let confirmed_findings =
    list.filter(all_findings, fn(note) {
      let thread_notes = pcd_dict.get(discussion.notes, { note.1 }.note_id)

      let closing_note =
        list.find(thread_notes, fn(thread_note) {
          case { thread_note }.significance {
            note.FindingConfirmation -> True
            _ -> False
          }
        })

      // If we do not find a rejection, then the finding is still open.
      case closing_note {
        Ok(..) -> True
        Error(Nil) -> False
      }
    })

  #(
    incomplete_todos,
    unanswered_questions,
    unconfirmed_findings,
    confirmed_findings,
  )
}
