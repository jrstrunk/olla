import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{type Option}
import tempo
import tempo/datetime
import tempo/instant

// Represents the way clients should submit data to the server
pub type NoteSubmission {
  NoteSubmission(
    parent_id: String,
    significance: NoteSignificance,
    user_id: String,
    message: String,
    expanded_message: Option(String),
    modifier: NoteModifier,
  )
}

pub fn build_note(from submission: NoteSubmission, with id: Int) {
  Note(
    note_id: "C" <> int.to_string(id),
    parent_id: submission.parent_id,
    significance: submission.significance,
    user_name: submission.user_id,
    message: submission.message,
    expanded_message: submission.expanded_message,
    time: instant.now() |> instant.as_utc_datetime,
    modifier: submission.modifier,
  )
}

/// Represents the way data is stored in the database
pub type Note {
  Note(
    note_id: String,
    parent_id: String,
    significance: NoteSignificance,
    user_name: String,
    message: String,
    expanded_message: Option(String),
    time: tempo.DateTime,
    modifier: NoteModifier,
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
    _ -> panic as "Invalid note significance given"
  }
}

pub type NoteModifier {
  None
  Edit
  Delete
}

pub fn note_modifier_to_int(note_modifier) {
  case note_modifier {
    None -> 0
    Edit -> 1
    Delete -> 2
  }
}

pub fn note_modifier_from_int(note_modifier) {
  case note_modifier {
    0 -> None
    1 -> Edit
    2 -> Delete
    _ -> panic as "Invalid note modifier given"
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

pub fn encode_note_submission(note: NoteSubmission) {
  json.object([
    #("p", json.string(note.parent_id)),
    #("s", json.int(note.significance |> note_significance_to_int)),
    #("u", json.string(note.user_id)),
    #("m", json.string(note.message)),
    #("x", json.nullable(note.expanded_message, json.string)),
    #("d", json.int(note.modifier |> note_modifier_to_int)),
  ])
}

pub fn note_submission_decoder() {
  use parent_id <- decode.field("p", decode.string)
  use significance <- decode.field("s", decode.int)
  use user_id <- decode.field("u", decode.string)
  use message <- decode.field("m", decode.string)
  use expanded_message <- decode.field("x", decode.optional(decode.string))
  use modifier <- decode.field("d", decode.int)

  NoteSubmission(
    parent_id:,
    significance: note_significance_from_int(significance),
    user_id:,
    message:,
    expanded_message:,
    modifier: note_modifier_from_int(modifier),
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
    modifier: None,
  )
}

pub fn example_note_vote() {
  NoteVote(note_id: "Example", user_name: "system", sigficance: UpVote)
}

pub const example_note_submission = NoteSubmission(
  parent_id: "Example",
  significance: Comment,
  user_id: "system",
  message: "Wow bro great finding that is really cool",
  expanded_message: option.None,
  modifier: None,
)
