import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{type Option}
import gleam/string
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
    referenced_topic_ids: List(String),
    prior_referenced_topic_ids: option.Option(List(String)),
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
    referenced_topic_ids: submission.referenced_topic_ids,
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
    referenced_topic_ids: List(String),
  )
}

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
  Referer
  Reference(referee_topic_id: String)
}

pub fn note_modifier_to_string(note_modifier: NoteModifier) {
  case note_modifier {
    None -> "n"
    Edit -> "e"
    Delete -> "d"
    Referer -> "r"
    Reference(referee_topic_id:) -> "r-" <> referee_topic_id
  }
}

pub fn note_modifier_decoder() -> decode.Decoder(NoteModifier) {
  use char <- decode.then(decode.string)
  case char {
    "n" -> decode.success(None)
    "e" -> decode.success(Edit)
    "d" -> decode.success(Delete)
    "r" -> decode.success(Referer)
    "r-" <> referee_topic_id -> decode.success(Reference(referee_topic_id))
    _ -> decode.failure(None, "NoteModifier")
  }
}

/// Represents a note in the discussion list, but does not contain the actual
/// note data.
pub type NoteStub {
  NoteStub(topic_id: String, time: tempo.DateTime, kind: NoteStubKind)
}

pub fn note_stub_to_json(note_stub: NoteStub) -> json.Json {
  let NoteStub(topic_id:, time:, kind:) = note_stub
  json.object([
    #("i", json.string(topic_id)),
    #("t", json.int(datetime.to_unix_seconds(time))),
    #("k", json.string(note_stub_kind_to_string(kind))),
  ])
}

pub fn note_stub_decoder() -> decode.Decoder(NoteStub) {
  use topic_id <- decode.field("i", decode.string)
  use time <- decode.field(
    "t",
    decode.int |> decode.map(datetime.from_unix_seconds),
  )
  use kind <- decode.field(
    "k",
    decode.string |> decode.map(note_stub_kind_from_string),
  )
  decode.success(NoteStub(topic_id:, time:, kind:))
}

pub type NoteStubKind {
  CommentNoteStub
  InformationalNoteStub
  MentionNoteStub
}

fn note_stub_kind_to_string(note_stub_kind) {
  case note_stub_kind {
    CommentNoteStub -> "c"
    InformationalNoteStub -> "i"
    MentionNoteStub -> "m"
  }
}

fn note_stub_kind_from_string(note_stub_kind) {
  case note_stub_kind {
    "c" -> CommentNoteStub
    "i" -> InformationalNoteStub
    "m" -> MentionNoteStub
    _ -> panic as "Invalid note stub kind"
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
    #("d", json.string(note.modifier |> note_modifier_to_string)),
    #("r", json.array(note.referenced_topic_ids, json.string)),
    #(
      "pr",
      json.nullable(note.prior_referenced_topic_ids, json.array(_, json.string)),
    ),
  ])
}

pub fn note_submission_decoder() {
  use parent_id <- decode.field("p", decode.string)
  use significance <- decode.field("s", decode.int)
  use user_id <- decode.field("u", decode.string)
  use message <- decode.field("m", decode.string)
  use expanded_message <- decode.field("x", decode.optional(decode.string))
  use modifier <- decode.field("d", note_modifier_decoder())
  use referenced_topic_ids <- decode.field("r", decode.list(decode.string))
  use prior_referenced_topic_ids <- decode.field(
    "pr",
    decode.optional(decode.list(decode.string)),
  )

  NoteSubmission(
    parent_id:,
    significance: note_significance_from_int(significance),
    user_id:,
    message:,
    expanded_message:,
    modifier:,
    referenced_topic_ids:,
    prior_referenced_topic_ids:,
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
    referenced_topic_ids: [],
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
  referenced_topic_ids: [],
  prior_referenced_topic_ids: option.None,
)

pub fn classify_message(message, is_thread_open is_thread_open) {
  let #(sig, message) = case is_thread_open {
    // Users can only start actionalble threads in the main thread
    False ->
      case message {
        "todo:" <> rest -> #(ToDo, rest)
        "t:" <> rest -> #(ToDo, rest)
        "question:" <> rest -> #(Question, rest)
        "q:" <> rest -> #(Question, rest)
        "finding:" <> rest -> #(FindingLead, rest)
        "f:" <> rest -> #(FindingLead, rest)
        "dev:" <> rest -> #(DevelperQuestion, rest)
        "info:" <> rest -> #(Informational, rest)
        "i:" <> rest -> #(Informational, rest)
        _ -> #(Comment, message)
      }
    // Users can only resolve actionalble threads in an open thread
    True ->
      case message {
        "done" -> #(ToDoCompletion, "done")
        "done:" <> rest -> #(ToDoCompletion, rest)
        "d:" <> rest -> #(ToDoCompletion, rest)
        "answer:" <> rest -> #(Answer, rest)
        "a:" <> rest -> #(Answer, rest)
        "reject:" <> rest -> #(FindingRejection, rest)
        "confirm:" <> rest -> #(FindingConfirmation, rest)
        "incorrect:" <> rest -> #(InformationalRejection, rest)
        "correct:" <> rest -> #(InformationalConfirmation, rest)
        _ -> #(Comment, message)
      }
  }

  #(sig, message |> string.trim)
}
