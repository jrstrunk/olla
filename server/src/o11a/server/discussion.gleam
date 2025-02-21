import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import lib/sqlightx
import o11a/config
import o11a/note
import snag
import sqlight
import tempo/datetime
import tempo/instant

pub type PageNotes {
  PageNotes(
    page_path: String,
    conn: option.Option(sqlight.Connection),
    function_test_notes: note.NoteCollection,
    function_invariant_notes: note.NoteCollection,
    line_comment_notes: note.NoteCollection,
    thread_notes: note.NoteCollection,
    votes: note.NoteVoteCollection,
  )
}

pub fn add_example_page_notes(page_notes: PageNotes) -> PageNotes {
  io.debug("Adding example page notes")
  let example_note = fn(id) {
    process.sleep(1)
    note.Note(
      parent_id: id,
      note_type: note.LineCommentNote,
      significance: note.Regular,
      user_id: 0,
      message: "This is a comment that keeps on going on and on and on and on and on and on and it just keeps on going and it wont stop ever at all forever and ever and on and ever and on and ever and on",
      expanded_message: None,
      time: instant.now() |> instant.as_local_datetime,
      thread_id: None,
      last_edit_time: None,
    )
  }

  let example_note2 = fn(id) {
    process.sleep(1)
    note.Note(
      parent_id: id,
      note_type: note.LineCommentNote,
      significance: note.Regular,
      user_id: 0,
      message: "Wow bro great finding that is really cool",
      expanded_message: None,
      time: instant.now() |> instant.as_local_datetime,
      thread_id: None,
      last_edit_time: None,
    )
  }

  [
    example_note("L1"),
    example_note2("L1"),
    example_note("L2"),
    example_note2("L2"),
    example_note("L3"),
    example_note2("L3"),
    example_note("L4"),
    example_note2("L4"),
    example_note("L5"),
    example_note2("L5"),
    example_note("L6"),
    example_note2("L6"),
    example_note("L7"),
    example_note2("L7"),
    example_note("L8"),
    example_note2("L8"),
    example_note("L9"),
    example_note2("L9"),
    example_note("L10"),
    example_note2("L10"),
    example_note("L11"),
    example_note2("L11"),
    example_note("L12"),
    example_note2("L12"),
    example_note("L13"),
    example_note2("L13"),
    example_note("L14"),
    example_note2("L14"),
    example_note("L15"),
    example_note2("L15"),
    example_note("L16"),
    example_note2("L16"),
    example_note("L17"),
    example_note2("L17"),
    example_note("L18"),
    example_note2("L18"),
    example_note("L19"),
    example_note2("L19"),
    example_note("L20"),
    example_note2("L20"),
    example_note("L21"),
    example_note2("L21"),
    example_note("L22"),
    example_note2("L22"),
    example_note("L23"),
    example_note2("L23"),
    example_note("L24"),
    example_note2("L24"),
    example_note("L25"),
    example_note2("L25"),
    example_note("L26"),
    example_note2("L26"),
    example_note("L27"),
    example_note2("L27"),
    example_note("L28"),
    example_note2("L28"),
    example_note("L29"),
    example_note2("L29"),
    example_note("L30"),
    example_note2("L30"),
    example_note("L31"),
    example_note2("L31"),
    example_note("L32"),
    example_note2("L32"),
    example_note("L33"),
    example_note2("L33"),
    example_note("L34"),
    example_note2("L34"),
    example_note("L35"),
    example_note2("L35"),
    example_note("L36"),
    example_note2("L36"),
    example_note("L37"),
    example_note2("L37"),
    example_note("L38"),
    example_note2("L38"),
    example_note("L39"),
    example_note2("L39"),
    example_note("L40"),
    example_note2("L40"),
    example_note("L41"),
    example_note2("L41"),
    example_note("L42"),
    example_note2("L42"),
    example_note("L43"),
    example_note2("L43"),
    example_note("L44"),
    example_note2("L44"),
    example_note("L45"),
    example_note2("L45"),
    example_note("L46"),
    example_note2("L46"),
    example_note("L47"),
    example_note2("L47"),
    example_note("L48"),
    example_note2("L48"),
    example_note("L49"),
    example_note2("L49"),
  ]
  |> list.fold(page_notes, fn(page_notes, note) {
    let assert Ok(pn) = add_note(page_notes, note)
    pn
  })
}

pub fn get_page_notes(page_path) {
  use conn <- result.try(connect_to_page_db(page_path))

  use notes <- result.try(
    sqlight.query(
      select_all_notes_query,
      with: [],
      on: conn,
      expecting: db_note_decoder(),
    )
    |> snag.map_error(string.inspect),
  )

  let notes = list.group(notes, fn(note) { note.note_type })

  PageNotes(
    page_path:,
    conn: option.Some(conn),
    function_test_notes: dict.get(notes, note.FunctionTestNote)
      |> result.unwrap([])
      |> list.group(fn(note) { note.parent_id }),
    function_invariant_notes: dict.get(notes, note.FunctionInvariantNote)
      |> result.unwrap([])
      |> list.group(fn(note) { note.parent_id }),
    line_comment_notes: dict.get(notes, note.LineCommentNote)
      |> result.unwrap([])
      |> list.group(fn(note) { note.parent_id }),
    thread_notes: dict.get(notes, note.ThreadNote)
      |> result.unwrap([])
      |> list.group(fn(note) { note.parent_id }),
    votes: dict.new(),
  )
  // |> add_example_page_notes()
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

pub fn add_note(page_notes: PageNotes, note: note.Note) {
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
    note.FunctionTestNote ->
      PageNotes(
        ..page_notes,
        function_test_notes: add_note_to_collection(
          page_notes.function_test_notes,
          note,
        ),
      )
    note.FunctionInvariantNote ->
      PageNotes(
        ..page_notes,
        function_invariant_notes: add_note_to_collection(
          page_notes.function_invariant_notes,
          note,
        ),
      )
    note.LineCommentNote ->
      PageNotes(
        ..page_notes,
        line_comment_notes: add_note_to_collection(
          page_notes.line_comment_notes,
          note,
        ),
      )
    note.ThreadNote ->
      PageNotes(
        ..page_notes,
        thread_notes: add_note_to_collection(page_notes.thread_notes, note),
      )
  }
}

fn add_note_to_collection(collection, note: note.Note) {
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

pub fn test_db() {
  use conn <- result.try(
    sqlight.open(":memory:")
    |> sqlightx.describe_connection_error(":memory:"),
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
  user_id INTEGER NOT NULL,
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

fn insert_note_data(note: note.Note) {
  [
    sqlight.text(note.parent_id),
    sqlight.int(note.note_type_to_int(note.note_type)),
    sqlight.int(note.note_significance_to_int(note.significance)),
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

fn db_note_decoder() {
  use parent_id <- decode.field(0, decode.string)
  use note_type <- decode.field(1, decode.int)
  use significance <- decode.field(2, decode.int)
  use user_id <- decode.field(3, decode.int)
  use message <- decode.field(4, decode.string)
  use expanded_message <- decode.field(5, decode.optional(decode.string))
  use time <- decode.field(6, decode.int)
  use thread_id <- decode.field(7, decode.optional(decode.string))
  use last_edit_time <- decode.field(8, decode.optional(decode.int))

  note.Note(
    parent_id:,
    note_type: note.note_type_from_int(note_type),
    significance: note.note_significance_from_int(significance),
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
