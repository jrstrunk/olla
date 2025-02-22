import gleam/dynamic/decode
import gleam/function
import gleam/option
import gleam/result
import lib/persistent_concurrent_duplicate_dict as pcd_dict
import o11a/config
import o11a/note
import tempo/datetime

/// A per-audit discussion
pub type Discussion {
  Discussion(
    audit_name: String,
    function_test_notes: NoteCollection,
    function_invariant_notes: NoteCollection,
    line_comment_notes: NoteCollection,
    thread_notes: NoteCollection,
    votes: NoteVoteCollection,
  )
}

pub type NoteCollection =
  pcd_dict.PersistentConcurrentDuplicateDict(String, note.Note)

pub type NoteVoteCollection =
  pcd_dict.PersistentConcurrentDuplicateDict(String, note.NoteVote)

pub fn get_audit_discussion(audit_name: String) {
  use function_test_notes <- result.try(pcd_dict.build(
    config.get_notes_persist_path(for: audit_name, of: "function_test"),
    function.identity,
    function.identity,
    note.example_note(),
    note_persist_encoder,
    note_persist_decoder(),
  ))
  use function_invariant_notes <- result.try(pcd_dict.build(
    config.get_notes_persist_path(for: audit_name, of: "function_invariant"),
    function.identity,
    function.identity,
    note.example_note(),
    note_persist_encoder,
    note_persist_decoder(),
  ))
  use line_comment_notes <- result.try(pcd_dict.build(
    config.get_notes_persist_path(for: audit_name, of: "line_comment"),
    function.identity,
    function.identity,
    note.example_note(),
    note_persist_encoder,
    note_persist_decoder(),
  ))
  use thread_notes <- result.try(pcd_dict.build(
    config.get_notes_persist_path(for: audit_name, of: "thread"),
    function.identity,
    function.identity,
    note.example_note(),
    note_persist_encoder,
    note_persist_decoder(),
  ))
  use votes <- result.try(pcd_dict.build(
    config.get_notes_persist_path(for: audit_name, of: "votes"),
    function.identity,
    function.identity,
    note.example_note_vote(),
    note_vote_persist_encoder,
    note_vote_persist_decoder(),
  ))

  Discussion(
    audit_name:,
    function_test_notes:,
    function_invariant_notes:,
    line_comment_notes:,
    thread_notes:,
    votes:,
  )
  |> Ok
}

pub fn note_persist_encoder(note: note.Note) {
  [
    pcd_dict.text(note.parent_id),
    pcd_dict.int(note.note_type_to_int(note.note_type)),
    pcd_dict.int(note.note_significance_to_int(note.significance)),
    pcd_dict.int(note.user_id),
    pcd_dict.text(note.message),
    pcd_dict.text_nullable(note.expanded_message),
    pcd_dict.int(datetime.to_unix_milli(note.time)),
    pcd_dict.text_nullable(note.thread_id),
    pcd_dict.int_nullable(
      note.last_edit_time |> option.map(datetime.to_unix_milli),
    ),
  ]
}

pub fn note_persist_decoder() {
  use parent_id <- decode.field(0, decode.string)
  use note_type <- decode.field(1, decode.int)
  use significance <- decode.field(2, decode.int)
  use user_id <- decode.field(3, decode.int)
  use message <- decode.field(4, decode.string)
  use expanded_message <- decode.field(5, decode.optional(decode.string))
  use time <- decode.field(6, decode.int)
  use thread_id <- decode.field(7, decode.optional(decode.string))
  use last_edit_time <- decode.field(8, decode.optional(decode.int))

  note.Note(
    parent_id:,
    note_type: note.note_type_from_int(note_type),
    significance: note.note_significance_from_int(significance),
    user_id:,
    message:,
    expanded_message:,
    time: datetime.from_unix_milli(time),
    thread_id:,
    last_edit_time: last_edit_time |> option.map(datetime.from_unix_milli),
  )
  |> decode.success
}

pub fn note_vote_persist_encoder(note_vote: note.NoteVote) {
  [
    pcd_dict.text(note_vote.note_id),
    pcd_dict.int(note.note_vote_sigficance_to_int(note_vote.sigficance)),
    pcd_dict.int(note_vote.user_id),
  ]
}

pub fn note_vote_persist_decoder() {
  use note_id <- decode.field(0, decode.string)
  use sigficance <- decode.field(1, decode.int)
  use user_id <- decode.field(2, decode.int)

  note.NoteVote(
    note_id:,
    user_id:,
    sigficance: note.note_vote_sigficance_from_int(sigficance),
  )
  |> decode.success
}

pub fn empty_discussion(audit_name: String) {
  Discussion(
    audit_name:,
    function_test_notes: pcd_dict.empty(),
    function_invariant_notes: pcd_dict.empty(),
    line_comment_notes: pcd_dict.empty(),
    thread_notes: pcd_dict.empty(),
    votes: pcd_dict.empty(),
  )
}

pub fn add_note(discussion: Discussion, note: note.Note) {
  case note.note_type {
    note.FunctionTestNote ->
      pcd_dict.insert(discussion.function_test_notes, note.parent_id, note)
    note.FunctionInvariantNote ->
      pcd_dict.insert(discussion.function_invariant_notes, note.parent_id, note)
    note.LineCommentNote ->
      pcd_dict.insert(discussion.line_comment_notes, note.parent_id, note)
    note.ThreadNote ->
      pcd_dict.insert(discussion.thread_notes, note.parent_id, note)
  }
}
