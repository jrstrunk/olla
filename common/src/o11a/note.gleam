import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/result
import gleam/string
import tempo
import tempo/datetime

pub type Note {
  Note(
    note_id: String,
    parent_id: String,
    significance: NoteSignificance,
    user_id: Int,
    message: String,
    expanded_message: Option(String),
    time: tempo.DateTime,
    thread_notes: List(Note),
    edited: Bool,
  )
}

pub type NoteId =
  #(Int, Int)

pub type NoteCollection =
  dict.Dict(String, List(Note))

pub type NoteSignificance {
  Regular
  Question
  Answer
  ToDo
  ToDoDone
  FindingLead
  FindingComfirmation
  FindingRejection
  DevelperQuestion
}

pub fn note_significance_to_int(note_significance) {
  case note_significance {
    Regular -> 1
    Question -> 2
    Answer -> 3
    ToDo -> 4
    ToDoDone -> 5
    FindingLead -> 6
    FindingComfirmation -> 7
    FindingRejection -> 8
    DevelperQuestion -> 9
  }
}

pub fn note_significance_from_int(note_significance) {
  case note_significance {
    1 -> Regular
    2 -> Question
    3 -> Answer
    4 -> ToDo
    5 -> ToDoDone
    6 -> FindingLead
    7 -> FindingComfirmation
    8 -> FindingRejection
    9 -> DevelperQuestion
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
  NoteVote(note_id: String, user_id: Int, sigficance: NoteVoteSigficance)
}

/// A dictionary mapping each note id to a list of votes for it. The data is
/// stored here instead of in the notes data so it can easily and quickly be
/// updated.
pub type NoteVoteCollection =
  dict.Dict(NoteId, List(NoteVote))

pub fn encode_note(note: Note) {
  json.object([
    #("note_id", json.string(note.note_id)),
    #("parent_id", json.string(note.parent_id)),
    #("significance", json.int(note.significance |> note_significance_to_int)),
    #("user_id", json.int(note.user_id)),
    #("message", json.string(note.message)),
    #("expanded_message", json.nullable(note.expanded_message, json.string)),
    #("time", json.int(note.time |> datetime.to_unix_milli)),
    #("thread_notes", json.array(note.thread_notes, encode_note)),
    #("edited", json.bool(note.edited)),
  ])
}

pub fn decode_note(note: dynamic.Dynamic) {
  use note <- result.try(decode.run(note, decode.string))
  parse_note(note)
}

pub fn parse_note(note: String) {
  json.parse(note, json_note_decoder())
  |> result.replace_error([
    decode.DecodeError("json-encoded note", string.inspect(note), []),
  ])
}

pub fn decode_notes(notes: dynamic.Dynamic) {
  use notes <- result.try(decode.run(notes, decode.string))

  json.parse(notes, decode.list(json_note_decoder()))
  |> result.replace_error([
    decode.DecodeError("json-encoded note", string.inspect(notes), []),
  ])
}

pub fn json_note_decoder() {
  use note_id <- decode.field("note_id", decode.string)
  use parent_id <- decode.field("parent_id", decode.string)
  use significance <- decode.field("significance", decode.int)
  use user_id <- decode.field("user_id", decode.int)
  use message <- decode.field("message", decode.string)
  use expanded_message <- decode.field(
    "expanded_message",
    decode.optional(decode.string),
  )
  use time <- decode.field("time", decode.int)
  use thread_notes <- decode.field(
    "thread_notes",
    decode.list(json_note_decoder()),
  )
  use edited <- decode.field("edited", decode.bool)

  Note(
    note_id:,
    parent_id:,
    significance: note_significance_from_int(significance),
    user_id:,
    message:,
    expanded_message:,
    time: datetime.from_unix_milli(time),
    thread_notes:,
    edited:,
  )
  |> decode.success
}

pub fn example_note() {
  Note(
    note_id: "1-10000",
    parent_id: "Example",
    significance: Regular,
    user_id: 0,
    message: "Wow bro great finding that is really cool",
    expanded_message: option.None,
    time: datetime.literal("2021-01-01T00:00:00Z"),
    thread_notes: [],
    edited: False,
  )
}

pub fn example_note_thread() {
  Note(
    note_id: "1-10000",
    parent_id: "Example",
    significance: Regular,
    user_id: 0,
    message: "Wow bro great finding that is really cool",
    expanded_message: option.None,
    time: datetime.literal("2021-01-01T00:00:00Z"),
    thread_notes: [
      Note(
        note_id: "1-10001",
        parent_id: "1-10000",
        significance: Regular,
        user_id: 0,
        message: "Wow bro great finding that is really cool",
        expanded_message: option.None,
        time: datetime.literal("2021-01-01T00:00:00Z"),
        thread_notes: [
          Note(
            note_id: "1-10003",
            parent_id: "1-10001",
            significance: Regular,
            user_id: 0,
            message: "Wow bro great finding that is really cool",
            expanded_message: option.None,
            time: datetime.literal("2021-01-01T00:00:00Z"),
            thread_notes: [],
            edited: False,
          ),
        ],
        edited: False,
      ),
      Note(
        note_id: "1-10002",
        parent_id: "1-10000",
        significance: Regular,
        user_id: 0,
        message: "Wow bro great finding that is really cool",
        expanded_message: option.None,
        time: datetime.literal("2021-01-01T00:00:00Z"),
        thread_notes: [],
        edited: True,
      ),
    ],
    edited: False,
  )
}

pub fn example_note_vote() {
  NoteVote(note_id: "Example", user_id: 0, sigficance: UpVote)
}
