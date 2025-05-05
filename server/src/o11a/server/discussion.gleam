import gleam/dynamic/decode
import gleam/function
import gleam/json
import gleam/list
import gleam/pair
import gleam/result
import gleam/string
import lib/persistent_concurrent_duplicate_dict as pcd_dict
import lib/persistent_concurrent_structured_dict as pcs_dict
import o11a/audit_metadata
import o11a/computed_note
import o11a/config
import o11a/note
import tempo/datetime

/// A per-audit discussion
pub type Discussion {
  Discussion(
    audit_name: String,
    notes: pcs_dict.PersistentConcurrentStructuredDict(
      String,
      note.NoteSubmission,
      note.Note,
      String,
      List(computed_note.ComputedNote),
    ),
    votes: pcd_dict.PersistentConcurrentDuplicateDict(
      String,
      note.NoteVote,
      note.NoteVote,
    ),
  )
}

pub fn build_audit_discussion(audit_name: String) {
  use notes <- result.try(pcs_dict.build(
    config.get_notes_persist_path(for: audit_name),
    function.identity,
    function.identity,
    note.build_note,
    note.example_note(),
    note_persist_encoder,
    note_persist_decoder(),
    function.identity,
    function.identity,
    builder: build_structured_notes,
  ))

  use votes <- result.try(pcd_dict.build(
    config.get_votes_persist_path(for: audit_name),
    function.identity,
    function.identity,
    fn(val, _) { val },
    note.example_note_vote(),
    note_vote_persist_encoder,
    note_vote_persist_decoder(),
  ))

  Discussion(audit_name:, notes:, votes:)
  |> Ok
}

pub fn note_persist_encoder(note: note.Note) {
  [
    pcd_dict.text(note.note_id),
    pcd_dict.text(note.parent_id),
    pcd_dict.int(note.note_significance_to_int(note.significance)),
    pcd_dict.text(note.user_name),
    pcd_dict.text(note.message),
    pcd_dict.text_nullable(note.expanded_message),
    pcd_dict.int(datetime.to_unix_milli(note.time)),
    pcd_dict.text(note.modifier |> note.note_modifier_to_string),
    pcd_dict.text(
      json.array(note.references, audit_metadata.encode_addressable_symbol)
      |> json.to_string,
    ),
  ]
}

pub fn note_persist_decoder() {
  use note_id <- decode.field(0, decode.string)
  use parent_id <- decode.field(1, decode.string)
  use significance <- decode.field(2, decode.int)
  use user_name <- decode.field(3, decode.string)
  use message <- decode.field(4, decode.string)
  use expanded_message <- decode.field(5, decode.optional(decode.string))
  use time <- decode.field(6, decode.int)
  use modifier <- decode.field(7, note.note_modifier_decoder())
  use references <- decode.field(8, {
    use str <- decode.then(decode.string)
    case
      json.parse(str, decode.list(audit_metadata.addressable_symbol_decoder()))
    {
      Ok(references) -> decode.success(references)
      Error(e) -> decode.failure([], "references - " <> string.inspect(e))
    }
  })

  note.Note(
    note_id:,
    parent_id:,
    significance: note.note_significance_from_int(significance),
    user_name:,
    message:,
    expanded_message:,
    time: datetime.from_unix_milli(time),
    modifier:,
    references:,
  )
  |> decode.success
}

pub fn note_vote_persist_encoder(note_vote: note.NoteVote) {
  [
    pcd_dict.text(note_vote.note_id),
    pcd_dict.int(note.note_vote_sigficance_to_int(note_vote.sigficance)),
    pcd_dict.text(note_vote.user_name),
  ]
}

pub fn note_vote_persist_decoder() {
  use note_id <- decode.field(0, decode.string)
  use sigficance <- decode.field(1, decode.int)
  use user_name <- decode.field(2, decode.string)

  note.NoteVote(
    note_id:,
    user_name:,
    sigficance: note.note_vote_sigficance_from_int(sigficance),
  )
  |> decode.success
}

pub fn add_note(
  discussion: Discussion,
  note_submission: note.NoteSubmission,
  topic_id topic,
) {
  use note <- result.try(
    pcs_dict.insert(
      discussion.notes,
      note_submission.parent_id,
      note_submission,
      rebuild_topics: [
        topic,
        ..list.filter_map(note_submission.references, fn(ref) {
          // It is a performance optimization to not rebuild the topics of
          // new references here, as they will be built
          // when those new notes are inserted
          case list.contains(note_submission.new_references, ref) {
            True -> Error(Nil)
            False -> Ok(ref.topic_id)
          }
        })
      ],
    ),
  )

  echo "added note to discussion " <> string.inspect(note)

  // If the note made any new references, add them to their respective topics
  list.map(note_submission.new_references, fn(reference) {
    let reference_note =
      note.NoteSubmission(
        ..note_submission,
        parent_id: reference.topic_id,
        modifier: note.Reference(note.note_id),
      )

    pcs_dict.insert(
      discussion.notes,
      reference.topic_id,
      reference_note,
      rebuild_topics: [reference.topic_id],
    )
  })
  |> result.all
  |> result.replace(Nil)
}

pub fn subscribe_to_note_updates(discussion: Discussion, effect: fn() -> Nil) {
  pcs_dict.subscribe(discussion.notes, effect)
}

pub fn subscribe_to_line_updates(
  discussion: Discussion,
  line_id topic: String,
  run effect: fn() -> Nil,
) {
  pcs_dict.subscribe_to_topic(discussion.notes, topic, effect)
}

pub fn get_notes(discussion: Discussion, line_id topic: String) {
  pcs_dict.get(discussion.notes, topic:)
}

pub fn get_all_notes(discussion: Discussion) {
  pcs_dict.to_list(discussion.notes)
}

fn build_structured_notes(
  notes_dict: pcd_dict.PersistentConcurrentDuplicateDict(
    String,
    note.NoteSubmission,
    note.Note,
  ),
  starting_from parent_id: String,
) {
  let notes =
    pcd_dict.get(notes_dict, parent_id)
    |> list.sort(fn(a, b) { datetime.compare(a.time, b.time) })

  let computed_notes =
    list.filter(notes, fn(note) {
      note.modifier != note.Edit && note.modifier != note.Delete
    })
    |> list.filter_map(fn(note) {
      echo "found note " <> string.inspect(note)
      let thread_id = case note.modifier {
        note.Reference(original_note_id) -> original_note_id
        _ -> note.note_id
      }
      echo "thread id " <> thread_id

      computed_note.from_note(note, pcd_dict.get(notes_dict, thread_id))
    })

  case computed_notes {
    [] -> []
    _ ->
      list.map(computed_notes, fn(computed_note) {
        build_structured_notes(notes_dict, computed_note.note_id)
      })
      |> list.flatten
      |> list.append(computed_notes)
  }
}

pub fn dump_computed_notes(discussion: Discussion) {
  let notes =
    pcs_dict.to_list(discussion.notes)
    |> list.map(pair.second)
    |> list.flatten

  json.array(notes, computed_note.encode_computed_note)
}

pub fn dump_computed_notes_since(discussion: Discussion, since ref_time) {
  let notes =
    pcs_dict.to_list(discussion.notes)
    |> list.map(pair.second)
    |> list.flatten
    |> list.filter(fn(note) {
      note.time |> datetime.is_later_or_equal(to: ref_time)
    })

  json.array(notes, computed_note.encode_computed_note)
}
