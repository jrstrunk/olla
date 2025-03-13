import concurrent_dict
import filepath
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import gleam/result
import gleam/string
import lib/elementx
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import o11a/computed_note
import o11a/server/discussion

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(init, update, cached_view, dict.new())
}

pub type Msg {
  ServerUpdatedDiscussion
}

pub type Model {
  Model(
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

h1 {
  font-size: 2rem;
  font-weight: bold;
  margin-top: 1rem;
  margin-bottom: 1rem;
}

h2 {
  font-size: 1.5rem;
  font-weight: bold;
  margin-top: 1rem;
  margin-bottom: 1rem;
}
"

fn cached_view(model: Model) -> element.Element(Msg) {
  let render = view(model)

  // Update the skeleton so the initial render on the client's request is up to
  // date with server state.
  concurrent_dict.insert(
    model.skeletons,
    get_skeleton_key(model.discussion.audit_name),
    render |> element.to_string,
  )

  render
}

fn view(model: Model) -> element.Element(Msg) {
  let container_styles = [#("margin-left", "2rem")]

  let #(
    incomplete_todos,
    unanswered_questions,
    unconfirmed_findings,
    confirmed_findings,
  ) = find_open_notes(model.discussion, for: None)

  html.div([attribute.style(container_styles)], [
    html.style([], style),
    html.div([attribute.style([#("width", "40rem")])], [
      elementx.hide_skeleton(),
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

fn get_skeleton_key(for audit_name) {
  "dsh" <> audit_name
}

pub fn get_skeleton(skeletons, for audit_name) {
  concurrent_dict.get(skeletons, get_skeleton_key(audit_name))
  |> result.unwrap("")
}

pub fn find_open_notes(in discussion: discussion.Discussion, for page_path) {
  let all_notes =
    case page_path {
      Some(page_path) ->
        discussion.get_all_notes(discussion)
        |> list.filter_map(fn(note_data) {
          // The note_id will be the page path + the line number, but we want
          // everything in the page path
          case string.starts_with(note_data.0, page_path) {
            True -> Ok(note_data.1)
            False -> Error(Nil)
          }
        })

      None ->
        discussion.get_all_notes(discussion)
        |> list.map(pair.second)
    }
    |> list.flatten

  let incomplete_todos =
    list.filter(all_notes, fn(note) {
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
