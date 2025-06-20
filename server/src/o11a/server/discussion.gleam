import gleam/dynamic/decode
import gleam/function
import gleam/json
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/string
import lib/persistent_concurrent_duplicate_dict as pcd_dict
import lib/persistent_concurrent_structured_dict as pcs_dict
import o11a/computed_note
import o11a/config
import o11a/note
import tempo/datetime

/// A per-audit discussion
pub type Discussion =
  pcs_dict.PersistentConcurrentStructuredDict(
    String,
    note.NoteSubmission,
    note.Note,
    String,
    List(computed_note.ComputedNote),
  )

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

  notes
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
      json.array(note.referenced_topic_ids, json.string)
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
  use referenced_topic_ids <- decode.field(8, {
    use str <- decode.then(decode.string)
    case json.parse(str, decode.list(decode.string)) {
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
    referenced_topic_ids:,
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
  let #(removed_references, existing_references, new_references) = case
    note_submission.prior_referenced_topic_ids
  {
    option.Some(prior_referenced_topic_ids) -> {
      #(
        list.filter(prior_referenced_topic_ids, fn(prior_ref) {
          !list.contains(note_submission.referenced_topic_ids, prior_ref)
        }),
        list.filter(note_submission.referenced_topic_ids, fn(ref) {
          list.contains(prior_referenced_topic_ids, ref)
        }),
        list.filter(note_submission.referenced_topic_ids, fn(ref) {
          !list.contains(prior_referenced_topic_ids, ref)
        }),
      )
    }
    option.None -> {
      #([], [], note_submission.referenced_topic_ids)
    }
  }

  use note <- result.try(pcs_dict.insert(
    discussion,
    note_submission.parent_id,
    note_submission,
    rebuild_topics: list.append(
      [topic, ..removed_references],
      existing_references,
    ),
  ))

  echo "added note to discussion " <> string.inspect(note)

  // If the note made any new references, add them to their respective topics
  list.map(new_references, fn(reference_topic_id) {
    let reference_note =
      note.NoteSubmission(
        ..note_submission,
        parent_id: reference_topic_id,
        modifier: note.Reference(note.note_id),
      )

    pcs_dict.insert(
      discussion,
      reference_topic_id,
      reference_note,
      rebuild_topics: [reference_topic_id],
    )
  })
  |> result.all
  |> result.replace(Nil)
}

pub fn subscribe_to_note_updates(discussion: Discussion, effect: fn() -> Nil) {
  pcs_dict.subscribe(discussion, effect)
}

pub fn subscribe_to_line_updates(
  discussion: Discussion,
  line_id topic: String,
  run effect: fn() -> Nil,
) {
  pcs_dict.subscribe_to_topic(discussion, topic, effect)
}

pub fn get_notes(discussion: Discussion, line_id topic: String) {
  pcs_dict.get(discussion, topic:)
}

pub fn get_all_notes(discussion: Discussion) {
  pcs_dict.to_list(discussion)
}

fn build_structured_notes(
  notes_dict: pcd_dict.PersistentConcurrentDuplicateDict(
    String,
    note.NoteSubmission,
    note.Note,
  ),
  starting_from topic_id: String,
) {
  let notes =
    pcd_dict.get(notes_dict, topic_id)
    |> list.sort(fn(a, b) { datetime.compare(a.time, b.time) })

  let computed_notes =
    list.filter(notes, fn(note) {
      note.modifier != note.Edit && note.modifier != note.Delete
    })
    |> list.filter_map(fn(note) {
      let thread_id = case note.modifier {
        note.Reference(original_note_id) -> original_note_id
        _ -> note.note_id
      }

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
    pcs_dict.to_list(discussion)
    |> list.map(pair.second)
    |> list.flatten

  json.array(notes, computed_note.encode_computed_note)
}

pub fn dump_computed_notes_since(discussion: Discussion, since ref_time) {
  let notes =
    pcs_dict.to_list(discussion)
    |> list.map(pair.second)
    |> list.flatten
    |> list.filter(fn(note) {
      note.time |> datetime.is_later_or_equal(to: ref_time)
    })

  json.array(notes, computed_note.encode_computed_note)
}
