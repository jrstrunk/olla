import given
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import o11a/note
import tempo
import tempo/datetime

/// Represents a note's complete state, factoring in other notes in the database
pub type ComputedNote {
  ComputedNote(
    note_id: String,
    parent_id: String,
    significance: ComputedNoteSignificance,
    user_name: String,
    message: String,
    expanded_message: Option(String),
    time: tempo.DateTime,
    referenced_topic_ids: List(String),
    edited: Bool,
    referee_topic_id: option.Option(String),
  )
}

pub fn encode_computed_note(computed_note: ComputedNote) -> json.Json {
  json.object([
    #("n", json.string(computed_note.note_id)),
    #("p", json.string(computed_note.parent_id)),
    #("s", json.int(significance_to_int(computed_note.significance))),
    #("u", json.string(computed_note.user_name)),
    #("m", json.string(computed_note.message)),
    #("x", case computed_note.expanded_message {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
    #("t", json.int(datetime.to_unix_milli(computed_note.time))),
    #("e", json.bool(computed_note.edited)),
    #("r", json.array(computed_note.referenced_topic_ids, json.string)),
    #("f", json.nullable(computed_note.referee_topic_id, json.string)),
  ])
}

pub fn computed_note_decoder() -> decode.Decoder(ComputedNote) {
  use note_id <- decode.field("n", decode.string)
  use parent_id <- decode.field("p", decode.string)
  use significance <- decode.field("s", decode.int)
  use user_name <- decode.field("u", decode.string)
  use message <- decode.field("m", decode.string)
  use expanded_message <- decode.field("x", decode.optional(decode.string))
  use time <- decode.field("t", decode.int)
  use edited <- decode.field("e", decode.bool)
  use referenced_topic_ids <- decode.field("r", decode.list(decode.string))
  use referee_topic_id <- decode.field("f", decode.optional(decode.string))

  decode.success(ComputedNote(
    note_id:,
    parent_id:,
    significance: significance_from_int(significance),
    user_name:,
    message:,
    expanded_message:,
    time: datetime.from_unix_milli(time),
    referenced_topic_ids:,
    edited:,
    referee_topic_id:,
  ))
}

pub type ComputedNoteSignificance {
  Comment
  UnansweredQuestion
  AnsweredQuestion
  Answer
  IncompleteToDo
  CompleteToDo
  ToDoCompletion
  UnconfirmedFinding
  ConfirmedFinding
  RejectedFinding
  FindingConfirmation
  FindingRejection
  UnansweredDeveloperQuestion
  AnsweredDeveloperQuestion
  Informational
  RejectedInformational
  InformationalRejection
  InformationalConfirmation
}

pub fn significance_to_int(note_significance) {
  case note_significance {
    Comment -> 0
    UnansweredQuestion -> 1
    AnsweredQuestion -> 2
    Answer -> 3
    IncompleteToDo -> 4
    CompleteToDo -> 5
    ToDoCompletion -> 6
    UnconfirmedFinding -> 7
    ConfirmedFinding -> 8
    RejectedFinding -> 9
    FindingConfirmation -> 10
    FindingRejection -> 11
    UnansweredDeveloperQuestion -> 12
    AnsweredDeveloperQuestion -> 13
    Informational -> 14
    RejectedInformational -> 15
    InformationalRejection -> 16
    InformationalConfirmation -> 17
  }
}

pub fn significance_from_int(note_significance) {
  case note_significance {
    0 -> Comment
    1 -> UnansweredQuestion
    2 -> AnsweredQuestion
    3 -> Answer
    4 -> IncompleteToDo
    5 -> CompleteToDo
    6 -> ToDoCompletion
    7 -> UnconfirmedFinding
    8 -> ConfirmedFinding
    9 -> RejectedFinding
    10 -> FindingConfirmation
    11 -> FindingRejection
    12 -> UnansweredDeveloperQuestion
    13 -> AnsweredDeveloperQuestion
    14 -> Informational
    15 -> RejectedInformational
    16 -> InformationalRejection
    17 -> InformationalConfirmation
    _ -> panic as "Invalid note significance found"
  }
}

pub fn significance_to_string(significance) {
  case significance {
    Comment -> None
    UnansweredQuestion -> Some("Unanswered Question")
    AnsweredQuestion -> Some("Answered")
    Answer -> Some("Answer")
    IncompleteToDo -> Some("Incomplete ToDo")
    CompleteToDo -> Some("Complete")
    ToDoCompletion -> Some("Completion")
    UnconfirmedFinding -> Some("Unconfirmed Finding")
    ConfirmedFinding -> Some("Confirmed Finding")
    RejectedFinding -> Some("Rejected Finding")
    FindingConfirmation -> Some("Confirmation")
    FindingRejection -> Some("Rejection")
    UnansweredDeveloperQuestion -> Some("Unanswered Dev Question")
    AnsweredDeveloperQuestion -> Some("Answered Dev Question")
    Informational -> Some("Info")
    RejectedInformational -> Some("Incorrect Info")
    InformationalRejection -> Some("Rejection")
    InformationalConfirmation -> Some("Confirmation")
  }
}

pub fn is_significance_threadable(note_significance) {
  case note_significance {
    Comment -> False
    UnansweredQuestion -> True
    AnsweredQuestion -> True
    Answer -> False
    IncompleteToDo -> True
    CompleteToDo -> True
    ToDoCompletion -> False
    UnconfirmedFinding -> True
    ConfirmedFinding -> True
    RejectedFinding -> True
    FindingConfirmation -> False
    FindingRejection -> False
    UnansweredDeveloperQuestion -> True
    AnsweredDeveloperQuestion -> True
    Informational -> True
    RejectedInformational -> True
    InformationalRejection -> False
    InformationalConfirmation -> False
  }
}

pub fn encode_computed_notes(note: List(ComputedNote)) {
  json.array(note, encode_computed_note)
}

pub fn decode_computed_notes(notes: dynamic.Dynamic) {
  use notes <- result.try(decode.run(notes, decode.string))

  use notes <- result.map(
    json.parse(notes, decode.list(computed_note_decoder()))
    |> result.replace_error([
      decode.DecodeError(
        "json-encoded computed note",
        string.inspect(notes),
        [],
      ),
    ]),
  )

  list.group(notes, by: fn(note) { note.parent_id })
}

pub fn from_note(original_note: note.Note, thread_notes: List(note.Note)) {
  // When we are searching for compound values, search from the end of the
  // list first to get the most recently added note.
  let thread_notes = list.reverse(thread_notes)

  // If the note has been deleted, return a nil error so it can be filtered out
  use Nil <- given.ok(
    list.find(thread_notes, fn(thread_note) {
      thread_note.modifier == note.Delete
    }),
    return: fn(_) { Error(Nil) },
  )

  // Find the most recent edit of the note
  let edited_note =
    list.find(thread_notes, fn(thread_note) {
      thread_note.modifier == note.Edit
    })

  // Update the note with the most recent edited messages, if any
  let #(note, edited) = case edited_note {
    Ok(edit) -> #(
      note.Note(
        ..original_note,
        message: edit.message,
        expanded_message: edit.expanded_message,
        significance: edit.significance,
        referenced_topic_ids: edit.referenced_topic_ids,
      ),
      True,
    )
    Error(Nil) -> #(original_note, False)
  }

  // If this note is a reference note, then it should have a reference to its
  // topic in its references list. If it does not, then an edit must have been
  // made to the note that removed the reference. In this case, return a
  // nil error so it can be filtered out.
  use referee_topic_id <- given.ok(
    case note.modifier {
      note.Reference(referee_topic_id:) ->
        list.find(note.referenced_topic_ids, fn(reference_topic_id) {
          reference_topic_id == note.parent_id
        })
        |> result.replace(option.Some(referee_topic_id))

      _ -> Ok(option.None)
    },
    else_return: fn(_) { Error(Nil) },
  )

  let significance = case note.significance {
    note.Comment -> Comment
    note.Question ->
      case
        list.find(thread_notes, fn(thread_note) {
          thread_note.significance == note.Answer
        })
      {
        Ok(..) -> AnsweredQuestion
        Error(Nil) -> UnansweredQuestion
      }
    note.DevelperQuestion ->
      case
        list.find(thread_notes, fn(thread_note) {
          thread_note.significance == note.Answer
        })
      {
        Ok(..) -> AnsweredDeveloperQuestion
        Error(Nil) -> UnansweredDeveloperQuestion
      }
    note.Answer -> Answer
    note.ToDo ->
      case
        list.find(thread_notes, fn(thread_note) {
          thread_note.significance == note.ToDoCompletion
        })
      {
        Ok(..) -> CompleteToDo
        Error(Nil) -> IncompleteToDo
      }
    note.ToDoCompletion -> ToDoCompletion
    note.FindingLead ->
      case
        list.find_map(thread_notes, fn(thread_note) {
          case thread_note.significance {
            note.FindingRejection -> Ok(FindingRejection)
            note.FindingConfirmation -> Ok(FindingConfirmation)
            _ -> Error(Nil)
          }
        })
      {
        Ok(FindingRejection) -> RejectedFinding
        Ok(FindingConfirmation) -> ConfirmedFinding
        Ok(..) -> UnconfirmedFinding
        Error(Nil) -> UnconfirmedFinding
      }
    note.FindingConfirmation -> FindingConfirmation
    note.FindingRejection -> FindingRejection
    note.Informational ->
      case
        list.find_map(thread_notes, fn(thread_note) {
          case thread_note.significance {
            note.InformationalRejection -> Ok(InformationalRejection)
            note.InformationalConfirmation -> Ok(InformationalConfirmation)
            _ -> Error(Nil)
          }
        })
      {
        Ok(InformationalRejection) -> RejectedInformational
        Ok(InformationalConfirmation) -> Informational
        Ok(..) -> Informational
        Error(Nil) -> Informational
      }
    note.InformationalRejection -> InformationalRejection
    note.InformationalConfirmation -> InformationalConfirmation
  }

  Ok(ComputedNote(
    note_id: note.note_id,
    parent_id: note.parent_id,
    significance:,
    user_name: note.user_name,
    message: note.message,
    expanded_message: note.expanded_message,
    time: note.time,
    edited:,
    referenced_topic_ids: note.referenced_topic_ids,
    referee_topic_id:,
  ))
}
