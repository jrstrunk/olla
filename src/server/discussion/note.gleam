import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import snag
import sqlight
import tempo
import tempo/datetime

pub type Note {
  Note(
    parent_id: String,
    note_type: NoteType,
    user_id: String,
    title: String,
    body: String,
    votes: Int,
    time: tempo.DateTime,
    thread_id: Option(String),
  )
}

pub type NoteCollection =
  dict.Dict(String, List(Note))

fn add_note_to_collection(collection, note: Note) {
  dict.upsert(collection, note.parent_id, fn(notes) {
    case notes {
      None -> [note]
      Some(notes) -> [note, ..notes]
    }
  })
}

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

  use notes <- result.map(
    sqlight.query(select_query, with: [], on: conn, expecting: {
      use parent_id <- decode.field(0, decode.string)
      use note_type <- decode.field(1, decode.int)
      use user_id <- decode.field(2, decode.string)
      use title <- decode.field(3, decode.string)
      use body <- decode.field(4, decode.string)
      use votes <- decode.field(5, decode.int)
      use time <- decode.field(6, decode.int)
      use thread_id <- decode.field(7, decode.optional(decode.string))

      Note(
        parent_id:,
        note_type: note_type_from_int(note_type),
        user_id:,
        title:,
        body:,
        votes:,
        time: datetime.from_unix_seconds(time),
        thread_id:,
      )
      |> decode.success
    })
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
    sqlight.exec(insert_query(note), on: conn)
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

fn connect_to_page_db(page_path) {
  use conn <- result.try(
    sqlight.open(page_path <> ".db") |> snag.map_error(string.inspect),
  )

  use Nil <- result.map(
    sqlight.exec(create_table_stmt, on: conn)
    |> snag.map_error(string.inspect),
  )

  conn
}

const create_table_stmt = "
CREATE TABLE IF NOT EXISTS notes (
  parent_id TEXT NOT NULL,
  note_type INTEGER NOT NULL,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  votes INTEGER NOT NULL,
  time INTEGER NOT NULL,
  thread_id TEXT
)"

fn insert_query(note: Note) {
  "INSERT INTO notes (parent_id, note_type, user_id, title, body, votes, time, thread_id) VALUES ('"
  <> note.parent_id
  <> "', "
  <> note_type_to_int(note.note_type) |> int.to_string
  <> ", '"
  <> note.user_id
  <> "', '"
  <> note.title
  <> "', '"
  <> note.body
  <> "', '"
  <> int.to_string(note.votes)
  <> "', '"
  <> datetime.to_unix_seconds(note.time) |> int.to_string
  <> "', "
  <> case note.thread_id {
    None -> "NULL"
    Some(thread_id) -> "'" <> thread_id <> "'"
  }
  <> ")"
}

const select_query = "
SELECT
  parent_id,
  note_type,
  user_id,
  title,
  body,
  votes,
  time,
  thread_id
FROM notes"
