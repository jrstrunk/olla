import gleam/dynamic/decode
import gleam/function
import gleam/list
import gleam/result
import gleam/string
import lib/concurrent_dict
import lib/persistent_concurrent_duplicate_dict as pcd_dict
import o11a/computed_note
import o11a/config
import o11a/note
import tempo/datetime

/// A per-audit discussion
pub type Discussion {
  Discussion(
    audit_name: String,
    notes: pcd_dict.PersistentConcurrentDuplicateDict(String, note.Note),
    votes: pcd_dict.PersistentConcurrentDuplicateDict(String, note.NoteVote),
    skeletons: concurrent_dict.ConcurrentDict(String, String),
  )
}

pub fn get_audit_discussion(audit_name: String) {
  use notes <- result.try(pcd_dict.build(
    config.get_notes_persist_path(for: audit_name),
    function.identity,
    function.identity,
    note.example_note(),
    note_persist_encoder,
    note_persist_decoder(),
  ))
  use votes <- result.try(pcd_dict.build(
    config.get_votes_persist_path(for: audit_name),
    function.identity,
    function.identity,
    note.example_note_vote(),
    note_vote_persist_encoder,
    note_vote_persist_decoder(),
  ))
  let skeletons = concurrent_dict.new()

  Discussion(audit_name:, notes:, votes:, skeletons:)
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

  note.Note(
    note_id:,
    parent_id:,
    significance: note.note_significance_from_int(significance),
    user_name:,
    message:,
    expanded_message:,
    time: datetime.from_unix_milli(time),
    deleted: False,
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

pub fn empty_discussion(audit_name: String) {
  Discussion(
    audit_name:,
    notes: pcd_dict.empty(),
    votes: pcd_dict.empty(),
    skeletons: concurrent_dict.new(),
  )
}

pub fn add_note(discussion: Discussion, note: note.Note) {
  pcd_dict.insert(discussion.notes, note.parent_id, note)
}

pub fn subscribe_to_note_updates(discussion: Discussion, effect: fn() -> Nil) {
  pcd_dict.subscribe(discussion.notes, effect)
}

pub fn get_notes(discussion: Discussion, only_for parent_id: String) {
  pcd_dict.get(discussion.notes, parent_id)
}

pub fn get_structured_notes(
  discussion: Discussion,
  starting_from parent_id: String,
) -> List(#(String, List(computed_note.ComputedNote))) {
  let notes =
    pcd_dict.get(discussion.notes, parent_id)
    |> list.sort(fn(a, b) { datetime.compare(b.time, a.time) })

  let computed_notes =
    list.map(notes, fn(note) {
      computed_note.from_note(
        note,
        pcd_dict.get(discussion.notes, note.note_id),
      )
    })
    |> list.filter(fn(computed_note) {
      computed_note.note_id |> string.slice(0, 4) != "edit"
    })

  case computed_notes {
    [] -> []
    _ ->
      list.map(computed_notes, fn(computed_note) {
        get_structured_notes(discussion, computed_note.note_id)
      })
      |> list.flatten
      |> list.append([#(parent_id, computed_notes)])
  }
}

pub fn get_skeleton(discussion: Discussion, for view) {
  concurrent_dict.get(discussion.skeletons, view)
}

pub fn set_skeleton(discussion: Discussion, for view, skeleton skeleton) {
  concurrent_dict.insert(discussion.skeletons, view, skeleton)
}
