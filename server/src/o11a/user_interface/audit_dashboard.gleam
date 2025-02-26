import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import lib/persistent_concurrent_duplicate_dict as pcd_dict
import lib/server_componentx
import lustre
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import o11a/config
import o11a/note
import o11a/server/discussion
import simplifile
import snag

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(init, update, view(_, False), dict.new())
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

fn view(model: Model, is_skeleton is_skeleton) -> element.Element(Msg) {
  let #(
    incomplete_todos,
    unanswered_questions,
    unconfirmed_findings,
    confirmed_findings,
  ) = find_open_notes(model.discussion)

  html.div([], [
    server_componentx.hide_skeleton(),
    html.button([event.on_click(ServerUpdatedDiscussion)], [
      html.text("Update Notes"),
    ]),
    html.h2([], [html.text("Incomplete ToDos")]),
    html.ul([], case is_skeleton {
      True -> []
      False ->
        list.map(incomplete_todos, fn(note) {
          html.li([], [html.text(note.0 <> " - " <> { note.1 }.message)])
        })
    }),
    html.h2([], [html.text("Unanswered Questions")]),
    html.ul([], case is_skeleton {
      True -> []
      False ->
        list.map(unanswered_questions, fn(note) {
          html.li([], [html.text(note.0 <> " - " <> { note.1 }.message)])
        })
    }),
    html.h2([], [html.text("Unconfirmed Findings")]),
    html.ul([], case is_skeleton {
      True -> []
      False ->
        list.map(unconfirmed_findings, fn(note) {
          html.li([], [html.text(note.0 <> " - " <> { note.1 }.message)])
        })
    }),
    html.h2([], [html.text("Confirmed Findings")]),
    html.ul([], case is_skeleton {
      True -> []
      False ->
        list.map(confirmed_findings, fn(note) {
          html.li([], [html.text(note.0 <> " - " <> { note.1 }.message)])
        })
    }),
  ])
}

pub fn get_skeleton(for audit_name) {
  let skeleton_path = config.get_full_dashboard_skeleton_path(for: audit_name)

  case simplifile.read(skeleton_path) {
    Ok(skeleton) -> Ok(skeleton)

    Error(simplifile.Enoent) -> {
      // Generates a skeleton page for the given page path, and writes it to disk.
      let skeleton: Result(String, snag.Snag) = {
        let skeleton =
          Model(discussion: discussion.empty_discussion(audit_name))
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
            note.FindingComfirmation -> True
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
            note.FindingComfirmation -> True
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
