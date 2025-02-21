import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lib/sqlightx
import o11a/config
import snag
import sqlight
import tempo
import tempo/datetime

pub type Note {
  Note(
    parent_id: String,
    note_type: NoteType,
    significance: NoteSignificance,
    user_id: Int,
    message: String,
    expanded_message: Option(String),
    time: tempo.DateTime,
    thread_id: Option(String),
    last_edit_time: Option(tempo.DateTime),
  )
}

pub type NoteId =
  #(Int, Int)

pub type NoteCollection =
  dict.Dict(String, List(Note))

pub type NoteType {
  FunctionTestNote
  FunctionInvariantNote
  LineCommentNote
  ThreadNote
}

pub fn note_type_to_int(note_type) {
  case note_type {
    FunctionTestNote -> 1
    FunctionInvariantNote -> 2
    LineCommentNote -> 3
    ThreadNote -> 4
  }
}

pub fn note_type_from_int(note_type) {
  case note_type {
    1 -> FunctionTestNote
    2 -> FunctionInvariantNote
    3 -> LineCommentNote
    4 -> ThreadNote
    _ -> panic as "Invalid note type found"
  }
}

pub type NoteSignificance {
  Regular
  UnansweredQuestion
  AnsweredQuestion
  FindingLead
  FindingComfirmation
  FindingLeadInvalid
}

pub fn note_significance_to_int(note_significance) {
  case note_significance {
    Regular -> 1
    UnansweredQuestion -> 2
    AnsweredQuestion -> 3
    FindingLead -> 4
    FindingComfirmation -> 5
    FindingLeadInvalid -> 6
  }
}

pub fn note_significance_from_int(note_significance) {
  case note_significance {
    1 -> Regular
    2 -> UnansweredQuestion
    3 -> AnsweredQuestion
    4 -> FindingLead
    5 -> FindingComfirmation
    6 -> FindingLeadInvalid
    _ -> panic as "Invalid note significance found"
  }
}

pub type NoteVote {
  UpVote(user_id: Int)
  DownVote(user_id: Int)
}

/// A dictionary mapping each note id to a list of votes for it. The data is
/// stored here instead of in the notes data so it can easily and quickly be
/// updated.
pub type NoteVoteCollection =
  dict.Dict(NoteId, List(NoteVote))

pub type PageNotes {
  PageNotes(
    page_path: String,
    conn: option.Option(sqlight.Connection),
    function_test_notes: NoteCollection,
    function_invariant_notes: NoteCollection,
    line_comment_notes: NoteCollection,
    thread_notes: NoteCollection,
    votes: NoteVoteCollection,
  )
}

pub fn example_page_notes() {
  let example_note = fn(id) {
    Note(
      parent_id: id,
      note_type: LineCommentNote,
      significance: Regular,
      user_id: 0,
      message: "This is a comment that keeps on going on and on and on and on and on and on and it just keeps on going and it wont stop ever at all forever and ever and on and ever and on and ever and on",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
      thread_id: None,
      last_edit_time: None,
    )
  }

  let example_note2 = fn(id) {
    Note(
      parent_id: id,
      note_type: LineCommentNote,
      significance: Regular,
      user_id: 0,
      message: "Wow bro great finding that is really cool",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
      thread_id: None,
      last_edit_time: None,
    )
  }

  PageNotes(
    page_path: "example",
    conn: None,
    function_test_notes: dict.new(),
    function_invariant_notes: dict.new(),
    line_comment_notes: [
      #("L1", [example_note("L1"), example_note2("L1")]),
      #("L2", [example_note("L2"), example_note2("L2")]),
      #("L3", [example_note("L3"), example_note2("L3")]),
      #("L4", [example_note("L4"), example_note2("L4")]),
      #("L5", [example_note("L5"), example_note2("L5")]),
      #("L6", [example_note("L6"), example_note2("L6")]),
      #("L7", [example_note("L7"), example_note2("L7")]),
      #("L8", [example_note("L8"), example_note2("L8")]),
      #("L9", [example_note("L9"), example_note2("L9")]),
      #("L10", [example_note("L10"), example_note2("L10")]),
      #("L11", [example_note("L11"), example_note2("L11")]),
      #("L12", [example_note("L12"), example_note2("L12")]),
      #("L13", [example_note("L13"), example_note2("L13")]),
      #("L14", [example_note("L14"), example_note2("L14")]),
      #("L15", [example_note("L15"), example_note2("L15")]),
      #("L16", [example_note("L16"), example_note2("L16")]),
      #("L17", [example_note("L17"), example_note2("L17")]),
      #("L18", [example_note("L18"), example_note2("L18")]),
      #("L19", [example_note("L19"), example_note2("L19")]),
      #("L20", [example_note("L20"), example_note2("L20")]),
      #("L21", [example_note("L21"), example_note2("L21")]),
      #("L22", [example_note("L22"), example_note2("L22")]),
      #("L23", [example_note("L23"), example_note2("L23")]),
      #("L24", [example_note("L24"), example_note2("L24")]),
      #("L25", [example_note("L25"), example_note2("L25")]),
      #("L26", [example_note("L26"), example_note2("L26")]),
      #("L27", [example_note("L27"), example_note2("L27")]),
      #("L28", [example_note("L28"), example_note2("L28")]),
      #("L29", [example_note("L29"), example_note2("L29")]),
      #("L30", [example_note("L30"), example_note2("L30")]),
      #("L31", [example_note("L31"), example_note2("L31")]),
      #("L32", [example_note("L32"), example_note2("L32")]),
      #("L33", [example_note("L33"), example_note2("L33")]),
      #("L34", [example_note("L34"), example_note2("L34")]),
      #("L35", [example_note("L35"), example_note2("L35")]),
      #("L36", [example_note("L36"), example_note2("L36")]),
      #("L37", [example_note("L37"), example_note2("L37")]),
      #("L38", [example_note("L38"), example_note2("L38")]),
      #("L39", [example_note("L39"), example_note2("L39")]),
      #("L40", [example_note("L40"), example_note2("L40")]),
      #("L41", [example_note("L41"), example_note2("L41")]),
      #("L42", [example_note("L42"), example_note2("L42")]),
      #("L43", [example_note("L43"), example_note2("L43")]),
      #("L44", [example_note("L44"), example_note2("L44")]),
      #("L45", [example_note("L45"), example_note2("L45")]),
      #("L46", [example_note("L46"), example_note2("L46")]),
      #("L47", [example_note("L47"), example_note2("L47")]),
      #("L48", [example_note("L48"), example_note2("L48")]),
      #("L49", [example_note("L49"), example_note2("L49")]),
    ]
      |> dict.from_list,
    thread_notes: dict.new(),
    votes: dict.new(),
  )
}

pub fn get_page_notes(page_path) {
  use conn <- result.try(connect_to_page_db(page_path))

  use notes <- result.try(
    sqlight.query(
      select_all_notes_query,
      with: [],
      on: conn,
      expecting: note_decoder(),
    )
    |> snag.map_error(string.inspect),
  )

  let notes = list.group(notes, fn(note) { note.note_type })

  PageNotes(
    page_path:,
    conn: option.Some(conn),
    function_test_notes: dict.get(notes, FunctionTestNote)
      |> result.unwrap([])
      |> list.group(fn(note) { note.parent_id }),
    function_invariant_notes: dict.get(notes, FunctionInvariantNote)
      |> result.unwrap([])
      |> list.group(fn(note) { note.parent_id }),
    line_comment_notes: dict.get(notes, LineCommentNote)
      |> result.unwrap([])
      |> list.group(fn(note) { note.parent_id }),
    thread_notes: dict.get(notes, ThreadNote)
      |> result.unwrap([])
      |> list.group(fn(note) { note.parent_id }),
    votes: dict.new(),
  )
  |> Ok
}

pub fn empty_page_notes(page_path) {
  PageNotes(
    page_path:,
    conn: None,
    function_test_notes: dict.new(),
    function_invariant_notes: dict.new(),
    line_comment_notes: dict.new(),
    thread_notes: dict.new(),
    votes: dict.new(),
  )
}

pub fn add_note(page_notes: PageNotes, note: Note) {
  use conn <- result.try({
    case page_notes.conn {
      Some(conn) -> Ok(conn)
      None -> connect_to_page_db(page_notes.page_path)
    }
  })

  use Nil <- result.map(
    sqlightx.insert(insert_note_query, on: conn, with: insert_note_data(note))
    |> snag.map_error(string.inspect),
  )

  case note.note_type {
    FunctionTestNote ->
      PageNotes(
        ..page_notes,
        function_test_notes: add_note_to_collection(
          page_notes.function_test_notes,
          note,
        ),
      )
    FunctionInvariantNote ->
      PageNotes(
        ..page_notes,
        function_invariant_notes: add_note_to_collection(
          page_notes.function_invariant_notes,
          note,
        ),
      )
    LineCommentNote ->
      PageNotes(
        ..page_notes,
        line_comment_notes: add_note_to_collection(
          page_notes.line_comment_notes,
          note,
        ),
      )
    ThreadNote ->
      PageNotes(
        ..page_notes,
        thread_notes: add_note_to_collection(page_notes.thread_notes, note),
      )
  }
}

fn add_note_to_collection(collection, note: Note) {
  dict.upsert(collection, note.parent_id, fn(notes) {
    case notes {
      None -> [note]
      Some(notes) -> [note, ..notes]
    }
  })
}

pub fn get_note_id(note: Note) {
  #(note.user_id, note.time |> datetime.to_unix_milli)
}

fn connect_to_page_db(page_path) {
  let full_page_path = config.get_full_page_path(for: page_path)

  let db_path = full_page_path <> ".db"

  use conn <- result.try(
    sqlight.open(db_path)
    |> sqlightx.describe_connection_error(db_path),
  )

  use Nil <- result.try(
    sqlight.exec(create_note_table_stmt, on: conn)
    |> snag.map_error(string.inspect),
  )

  use Nil <- result.try(
    sqlight.exec(create_upvote_table_stmt, on: conn)
    |> snag.map_error(string.inspect),
  )

  use Nil <- result.try(
    sqlight.exec(create_downvote_table_stmt, on: conn)
    |> snag.map_error(string.inspect),
  )

  Ok(conn)
}

const create_note_table_stmt = "
CREATE TABLE IF NOT EXISTS notes (
  parent_id TEXT NOT NULL,
  note_type INTEGER NOT NULL,
  significance INTEGER NOT NULL,
  user_id TEXT NOT NULL,
  message TEXT NOT NULL,
  expanded_message TEXT,
  time INTEGER NOT NULL,
  thread_id TEXT,
  last_edit_time INTEGER,
  PRIMARY KEY (user_id, time)
)"

const insert_note_query = "
INSERT INTO notes (
  parent_id, 
  note_type, 
  significance,
  user_id, 
  message, 
  expanded_message, 
  time, 
  thread_id,
  last_edit_time
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"

fn insert_note_data(note: Note) {
  [
    sqlight.text(note.parent_id),
    sqlight.int(note_type_to_int(note.note_type)),
    sqlight.int(note_significance_to_int(note.significance)),
    sqlight.int(note.user_id),
    sqlight.text(note.message),
    sqlight.nullable(sqlight.text, note.expanded_message),
    sqlight.int(datetime.to_unix_milli(note.time)),
    sqlight.nullable(sqlight.text, note.thread_id),
    sqlight.nullable(
      sqlight.int,
      note.last_edit_time |> option.map(datetime.to_unix_milli),
    ),
  ]
}

const select_all_notes_query = "
SELECT
  parent_id,
  note_type,
  significance,
  user_id,
  message,
  expanded_message,
  time,
  thread_id,
  last_edit_time
FROM notes"

fn note_decoder() {
  use parent_id <- decode.field(0, decode.string)
  use note_type <- decode.field(1, decode.int)
  use significance <- decode.field(2, decode.int)
  use user_id <- decode.field(3, decode.int)
  use message <- decode.field(4, decode.string)
  use expanded_message <- decode.field(5, decode.optional(decode.string))
  use time <- decode.field(6, decode.int)
  use thread_id <- decode.field(7, decode.optional(decode.string))
  use last_edit_time <- decode.field(8, decode.optional(decode.int))

  Note(
    parent_id:,
    note_type: note_type_from_int(note_type),
    significance: note_significance_from_int(significance),
    user_id:,
    message:,
    expanded_message:,
    time: datetime.from_unix_milli(time),
    thread_id:,
    last_edit_time: last_edit_time |> option.map(datetime.from_unix_milli),
  )
  |> decode.success
}

const create_upvote_table_stmt = "
CREATE TABLE IF NOT EXISTS upvotes (
  note_user_id INTEGER NOT NULL,
  note_time INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  PRIMARY KEY (note_user_id, note_time, user_id)
)"

const create_downvote_table_stmt = "
CREATE TABLE IF NOT EXISTS downvotes (
  note_user_id INTEGER NOT NULL,
  note_time INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  PRIMARY KEY (note_user_id, note_time, user_id)
)"
