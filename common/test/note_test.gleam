import gleam/dynamic
import gleam/json
import gleam/list
import gleam/option.{None}
import gleeunit/should
import o11a/note
import tempo/datetime

pub fn encode_note_round_trip_test() {
  let note =
    note.Note(
      parent_id: "parent_id",
      note_type: note.LineCommentNote,
      significance: note.Regular,
      user_id: 0,
      message: "message",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
      thread_id: None,
      last_edit_time: None,
    )

  note.encode_note(note)
  |> json.to_string
  |> dynamic.from
  |> note.decode_note
  |> should.equal(Ok(note))
}

pub fn encode_notes_round_trip_test() {
  let notes = [
    note.Note(
      parent_id: "parent_id",
      note_type: note.LineCommentNote,
      significance: note.Regular,
      user_id: 0,
      message: "message",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
      thread_id: None,
      last_edit_time: None,
    ),
    note.Note(
      parent_id: "parent_id",
      note_type: note.LineCommentNote,
      significance: note.Regular,
      user_id: 0,
      message: "message",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
      thread_id: None,
      last_edit_time: None,
    ),
  ]

  list.map(notes, note.encode_note)
  |> json.preprocessed_array
  |> json.to_string
  |> dynamic.from
  |> note.decode_notes
  |> should.equal(Ok(notes))
}

pub fn note_type_round_trip_test() {
  list.each(
    [
      note.FunctionTestNote,
      note.FunctionInvariantNote,
      note.LineCommentNote,
      note.ThreadNote,
    ],
    fn(note_type) {
      note.note_type_to_int(note_type)
      |> note.note_type_from_int
      |> should.equal(note_type)
    },
  )
}
