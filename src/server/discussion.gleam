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
    title: String,
    body: String,
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
  Question
  FindingLead
  FindingComfirmation
}

pub fn note_significance_to_int(note_significance) {
  case note_significance {
    Regular -> 1
    Question -> 2
    FindingLead -> 3
    FindingComfirmation -> 4
  }
}

pub fn note_significance_from_int(note_significance) {
  case note_significance {
    1 -> Regular
    2 -> Question
    3 -> FindingLead
    4 -> FindingComfirmation
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
  title TEXT NOT NULL,
  body TEXT NOT NULL,
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
  title, 
  body, 
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
    sqlight.text(note.title),
    sqlight.text(note.body),
    sqlight.int(datetime.to_unix_milli(note.time)),
    sqlight.nullable(sqlight.text, note.thread_id),
    sqlight.nullable(sqlight.int, note.last_edit_time |> option.map(datetime.to_unix_milli)),
  ]
}

const select_all_notes_query = "
SELECT
  parent_id,
  note_type,
  significance,
  user_id,
  title,
  body,
  time,
  thread_id,
  last_edit_time
FROM notes"

fn note_decoder() {
  use parent_id <- decode.field(0, decode.string)
  use note_type <- decode.field(1, decode.int)
  use significance <- decode.field(2, decode.int)
  use user_id <- decode.field(3, decode.int)
  use title <- decode.field(4, decode.string)
  use body <- decode.field(5, decode.string)
  use time <- decode.field(6, decode.int)
  use thread_id <- decode.field(7, decode.optional(decode.string))
  use last_edit_time <- decode.field(8, decode.optional(decode.int))

  Note(
    parent_id:,
    note_type: note_type_from_int(note_type),
    significance: note_significance_from_int(significance),
    user_id:,
    title:,
    body:,
    time: datetime.from_unix_milli(time),
    thread_id:,
    last_edit_time: last_edit_time |> option.map(datetime.from_unix_milli),
  )
  |> decode.success
}

const create_upvote_table_stmt = "
CREATE TABLE IF NOT EXISTS upvotes (
  note_user_id INTEGER NOT NULL,
  note_time INTEGER NOT NULL
  user_id INTEGER NOT NULL,
  PRIMARY KEY (note_user_id, note_time, user_id)
)"

const create_downvote_table_stmt = "
CREATE TABLE IF NOT EXISTS downvotes (
  note_user_id INTEGER NOT NULL,
  note_time INTEGER NOT NULL
  user_id INTEGER NOT NULL,
  PRIMARY KEY (note_user_id, note_time, user_id)
)"
