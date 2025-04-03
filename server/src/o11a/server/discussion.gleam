import gleam/dynamic/decode
import gleam/function
import gleam/json
import gleam/list
import gleam/pair
import gleam/result
import lib/persistent_concurrent_duplicate_dict as pcd_dict
import lib/persistent_concurrent_structured_dict as pcs_dict
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
    pcd_dict.int(note.modifier |> note.note_modifier_to_int),
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
  use modifier <- decode.field(7, decode.int)

  note.Note(
    note_id:,
    parent_id:,
    significance: note.note_significance_from_int(significance),
    user_name:,
    message:,
    expanded_message:,
    time: datetime.from_unix_milli(time),
    modifier: note.note_modifier_from_int(modifier),
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
  topic_id topic: String,
) {
  pcs_dict.insert(
    discussion.notes,
    note_submission.parent_id,
    note_submission,
    topic:,
  )
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
    |> list.map(fn(note) {
      computed_note.from_note(note, pcd_dict.get(notes_dict, note.note_id))
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
