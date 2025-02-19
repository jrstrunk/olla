import gleam/dict
import gleam/dynamic/decode
import gleam/int
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
    note_id: String,
    parent_id: String,
    note_type: NoteType,
    significance: NoteSignificance,
    user_id: String,
    title: String,
    body: String,
    upvotes: List(String),
    downvotes: List(String),
    time: tempo.DateTime,
    thread_id: Option(String),
  )
}

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

pub type PageNotes {
  PageNotes(
    page_path: String,
    conn: option.Option(sqlight.Connection),
    function_test_notes: NoteCollection,
    function_invariant_notes: NoteCollection,
    line_comment_notes: NoteCollection,
    thread_notes: NoteCollection,
  )
}

pub fn get_page_notes(page_path) {
  use conn <- result.try(connect_to_page_db(page_path))

  use unweighted_notes <- result.try(
    sqlight.query(
      select_all_notes_query,
      with: [],
      on: conn,
      expecting: note_decoder(),
    )
    |> snag.map_error(string.inspect),
  )

  use notes <- result.try(
    list.map(unweighted_notes, fn(note) {
      use upvotes <- result.try(
        sqlight.query(
          select_upvotes_query,
          with: select_upvotes_data(note),
          on: conn,
          expecting: select_votes_decoder,
        )
        |> snag.map_error(string.inspect),
      )

      use downvotes <- result.try(
        sqlight.query(
          select_downvotes_query,
          with: select_downvotes_data(note),
          on: conn,
          expecting: select_votes_decoder,
        )
        |> snag.map_error(string.inspect),
      )

      Note(..note, upvotes:, downvotes:)
      |> Ok
    })
    |> result.all,
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
  note_id TEXT PRIMARY KEY,
  parent_id TEXT NOT NULL,
  note_type INTEGER NOT NULL,
  significance INTEGER NOT NULL,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  time INTEGER NOT NULL,
  thread_id TEXT
)"

const insert_note_query = "
INSERT INTO notes (
  note_id, 
  parent_id, 
  note_type, 
  significance,
  user_id, 
  title, 
  body, 
  time, 
  thread_id
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"

fn insert_note_data(note: Note) {
  [
    sqlight.text(note.note_id),
    sqlight.text(note.parent_id),
    sqlight.int(note_type_to_int(note.note_type)),
    sqlight.int(note_significance_to_int(note.significance)),
    sqlight.text(note.user_id),
    sqlight.text(note.title),
    sqlight.text(note.body),
    sqlight.int(datetime.to_unix_milli(note.time)),
    sqlight.nullable(sqlight.text, note.thread_id),
  ]
}

const select_all_notes_query = "
SELECT
  note_id,
  parent_id,
  note_type,
  significance,
  user_id,
  title,
  body,
  time,
  thread_id
FROM notes"

fn note_decoder() {
  use note_id <- decode.field(0, decode.string)
  use parent_id <- decode.field(1, decode.string)
  use note_type <- decode.field(2, decode.int)
  use significance <- decode.field(3, decode.int)
  use user_id <- decode.field(4, decode.string)
  use title <- decode.field(5, decode.string)
  use body <- decode.field(6, decode.string)
  use time <- decode.field(7, decode.int)
  use thread_id <- decode.field(8, decode.optional(decode.string))

  Note(
    note_id:,
    parent_id:,
    note_type: note_type_from_int(note_type),
    significance: note_significance_from_int(significance),
    user_id:,
    title:,
    body:,
    upvotes: [],
    downvotes: [],
    time: datetime.from_unix_milli(time),
    thread_id:,
  )
  |> decode.success
}

const create_upvote_table_stmt = "
CREATE TABLE IF NOT EXISTS upvotes (
  note_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  PRIMARY KEY (note_id, user_id)
)"

const create_downvote_table_stmt = "
CREATE TABLE IF NOT EXISTS downvotes (
  note_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  PRIMARY KEY (note_id, user_id)
)"

const insert_upvote_query = "
INSERT INTO upvotes (note_id, user_id) VALUES (?, ?)"

const insert_downvote_query = "
INSERT INTO downvotes (note_id, user_id) VALUES (?, ?)"

fn insert_upvote_data(note_id, user_id) {
  [sqlight.text(note_id), sqlight.text(user_id)]
}

fn insert_downvote_data(note_id, user_id) {
  [sqlight.text(note_id), sqlight.text(user_id)]
}

const select_upvotes_query = "
SELECT
  user_id
FROM upvotes
WHERE note_id = ?"

const select_downvotes_query = "
SELECT
  user_id
FROM downvotes
WHERE note_id = ?"

fn select_upvotes_data(note: Note) {
  [sqlight.text(note.note_id)]
}

fn select_downvotes_data(note: Note) {
  [sqlight.text(note.note_id)]
}

const select_votes_decoder = decode.string
