import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/result
import gleam/string
import tempo
import tempo/datetime

/// Represents the way data is stored in the database and how clients should
/// send data to the server.
pub type Note {
  Note(
    note_id: String,
    parent_id: String,
    significance: NoteSignificance,
    user_name: String,
    message: String,
    expanded_message: Option(String),
    time: tempo.DateTime,
    deleted: Bool,
  )
}

pub type NoteCollection =
  dict.Dict(String, List(Note))

pub type NoteSignificance {
  Comment
  Question
  Answer
  ToDo
  ToDoCompletion
  FindingLead
  FindingConfirmation
  FindingRejection
  DevelperQuestion
  Informational
  InformationalRejection
  InformationalConfirmation
}

pub fn note_significance_to_int(note_significance) {
  case note_significance {
    Comment -> 1
    Question -> 2
    Answer -> 3
    ToDo -> 4
    ToDoCompletion -> 5
    FindingLead -> 6
    FindingConfirmation -> 7
    FindingRejection -> 8
    DevelperQuestion -> 9
    Informational -> 10
    InformationalRejection -> 11
    InformationalConfirmation -> 12
  }
}

pub fn note_significance_from_int(note_significance) {
  case note_significance {
    1 -> Comment
    2 -> Question
    3 -> Answer
    4 -> ToDo
    5 -> ToDoCompletion
    6 -> FindingLead
    7 -> FindingConfirmation
    8 -> FindingRejection
    9 -> DevelperQuestion
    10 -> Informational
    11 -> InformationalRejection
    12 -> InformationalConfirmation
    _ -> panic as "Invalid note significance found"
  }
}

pub type NoteVoteSigficance {
  UpVote
  DownVote
}

pub fn note_vote_sigficance_to_int(note_vote_sigficance) {
  case note_vote_sigficance {
    UpVote -> 1
    DownVote -> 2
  }
}

pub fn note_vote_sigficance_from_int(note_vote_sigficance) {
  case note_vote_sigficance {
    1 -> UpVote
    2 -> DownVote
    _ -> panic as "Invalid note vote significance found"
  }
}

pub type NoteVote {
  NoteVote(note_id: String, user_name: String, sigficance: NoteVoteSigficance)
}

/// A dictionary mapping each note id to a list of votes for it. The data is
/// stored here instead of in the notes data so it can easily and quickly be
/// updated.
pub type NoteVoteCollection =
  dict.Dict(String, List(NoteVote))

pub fn encode_structured_notes(note: #(String, List(Note))) {
  json.object([
    #("note_id", json.string(note.0)),
    #("thread_notes", json.array(note.1, encode_note)),
  ])
}

pub fn decode_structured_notes(notes: dynamic.Dynamic) {
  use notes <- result.try(decode.run(notes, decode.string))

  json.parse(notes, decode.list(structured_note_decoder()))
  |> result.replace_error([
    decode.DecodeError("json-encoded note", string.inspect(notes), []),
  ])
}

fn structured_note_decoder() {
  use note_id <- decode.field("note_id", decode.string)
  use thread_notes <- decode.field("thread_notes", decode.list(note_decoder()))

  #(note_id, thread_notes)
  |> decode.success
}

pub fn encode_note(note: Note) {
  json.object([
    #("n", json.string(note.note_id)),
    #("p", json.string(note.parent_id)),
    #("s", json.int(note.significance |> note_significance_to_int)),
    #("u", json.string(note.user_name)),
    #("m", json.string(note.message)),
    #("x", json.nullable(note.expanded_message, json.string)),
    #("t", json.int(note.time |> datetime.to_unix_milli)),
    #("d", json.bool(note.deleted)),
  ])
}

pub fn note_decoder() {
  use note_id <- decode.field("n", decode.string)
  use parent_id <- decode.field("p", decode.string)
  use significance <- decode.field("s", decode.int)
  use user_name <- decode.field("u", decode.string)
  use message <- decode.field("m", decode.string)
  use expanded_message <- decode.field("x", decode.optional(decode.string))
  use time <- decode.field("t", decode.int)
  use deleted <- decode.field("d", decode.bool)

  Note(
    note_id:,
    parent_id:,
    significance: note_significance_from_int(significance),
    user_name:,
    message:,
    expanded_message:,
    time: datetime.from_unix_milli(time),
    deleted:,
  )
  |> decode.success
}

pub fn example_note() {
  Note(
    note_id: "user02110000",
    parent_id: "Example",
    significance: Comment,
    user_name: "system",
    message: "Wow bro great finding that is really cool",
    expanded_message: option.None,
    time: datetime.literal("2021-01-01T00:00:00Z"),
    deleted: False,
  )
}

pub fn example_note_thread() {
  [
    #("L1", [
      Note(
        note_id: "L2",
        parent_id: "L1",
        significance: Comment,
        user_name: "system",
        message: "world",
        expanded_message: option.None,
        time: example_note().time,
        deleted: False,
      ),
      Note(
        note_id: "L3",
        parent_id: "L1",
        significance: Comment,
        user_name: "system",
        message: "hello2",
        expanded_message: option.None,
        time: example_note().time,
        deleted: False,
      ),
    ]),
    #("L50", [
      Note(
        note_id: "L1",
        parent_id: "L50",
        significance: Comment,
        user_name: "system",
        message: "hello",
        expanded_message: option.None,
        time: example_note().time,
        deleted: False,
      ),
    ]),
    #("L3", [
      Note(
        note_id: "L4",
        parent_id: "L3",
        significance: Comment,
        user_name: "system",
        message: "world2",
        expanded_message: option.None,
        time: example_note().time,
        deleted: False,
      ),
    ]),
  ]
}

pub fn example_note_vote() {
  NoteVote(note_id: "Example", user_name: "system", sigficance: UpVote)
}
