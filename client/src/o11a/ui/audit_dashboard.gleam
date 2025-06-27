import filepath
import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/computed_note
import o11a/note
import o11a/topic
import o11a/ui/discussion

const style = "
.dashboard-link {
  text-decoration: none;
  color: var(--text-color);
}

.dashboard-link:hover {
  text-decoration: underline;
}
"

const view_id = "audit-dashboard"

pub fn view(
  audit_name audit_name,
  attack_vectors attack_vectors: List(topic.Topic),
  discussion discussion,
  declarations declarations,
  discussion_context discussion_context,
) {
  let active_discussion =
    discussion.get_active_discussion_reference(view_id, discussion_context)

  let #(
    incomplete_todos,
    unanswered_questions,
    unconfirmed_findings,
    confirmed_findings,
  ) = find_open_notes(discussion, for: None, topics: declarations)

  html.div([attribute.style("margin-left", "2rem")], [
    html.style([], style),
    html.div([attribute.style("width", "40rem")], [
      html.h1([], [
        html.text(audit_name |> string.capitalise <> " Audit Dashboard"),
      ]),
      html.h2([], [html.text("Attack Vectors")]),
      element.fragment(
        list.index_map(attack_vectors, fn(attack_vector, index) {
          html.p([], [
            discussion.node_with_discussion_view(
              topic_id: attack_vector.topic_id,
              tokens: attack_vector.topic_id,
              discussion:,
              declarations:,
              discussion_id: discussion.DiscussionId(
                view_id:,
                container_id: option.None,
                line_number: index,
                column_number: 0,
              ),
              active_discussion:,
              discussion_context:,
              node_view_kind: discussion.DeclarationView,
            ),
            html.text(" - " <> topic.topic_name(attack_vector)),
          ])
        }),
      ),
      html.h2([], [html.text("Incomplete todos")]),
      notes_view(incomplete_todos, declarations, discussion, discussion_context),
      html.h2([], [html.text("Unanswered questions")]),
      notes_view(
        unanswered_questions,
        declarations,
        discussion,
        discussion_context,
      ),
      html.h2([], [html.text("Unconfirmed findings")]),
      notes_view(
        unconfirmed_findings,
        declarations,
        discussion,
        discussion_context,
      ),
      html.h2([], [html.text("Confirmed findings")]),
      notes_view(
        confirmed_findings,
        declarations,
        discussion,
        discussion_context,
      ),
    ]),
  ])
}

fn notes_view(notes, topics, discussion, discussion_context) {
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
        html.text(" - "),
        ..discussion.topic_signature_view(
          view_id:,
          signature: note.message,
          declarations: topics,
          discussion:,
          suppress_declaration: True,
          line_number_offset: 0,
          active_discussion: option.None,
          discussion_context: discussion_context,
        )
      ])
    }),
  )
}

pub fn find_open_notes(
  in notes: dict.Dict(String, List(note.NoteStub)),
  for page_path,
  topics topics: dict.Dict(String, topic.Topic),
) {
  let all_notes =
    case page_path {
      Some(page_path) ->
        dict.to_list(notes)
        |> list.map(fn(note_data) {
          // The note_id will be the page path + the line number, but we want
          // everything in the page path
          case string.starts_with(note_data.0, page_path) {
            True ->
              list.filter_map(note_data.1, fn(note: note.NoteStub) {
                topic.get_computed_note(topics, note.topic_id)
              })
            False -> []
          }
        })

      None ->
        dict.to_list(notes)
        |> list.map(fn(note_data) {
          list.filter_map(note_data.1, fn(note: note.NoteStub) {
            topic.get_computed_note(topics, note.topic_id)
          })
        })
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
