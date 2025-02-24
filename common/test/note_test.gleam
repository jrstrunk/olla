import gleam/dynamic
import gleam/json
import gleam/list
import gleam/option.{None}
import gleeunit/should
import o11a/note
import tempo/datetime

pub fn encode_note_round_trip_test() {
  note.example_note()
  |> note.encode_note
  |> json.to_string
  |> dynamic.from
  |> note.decode_note
  |> should.equal(Ok(note.example_note()))
}

pub fn encode_note_thread_round_trip_test() {
  note.example_note_thread()
  |> note.encode_note
  |> json.to_string
  // |> iod.
  |> dynamic.from
  |> note.decode_note
  |> should.equal(Ok(note.example_note_thread()))
}

pub fn encode_notes_round_trip_test() {
  let notes = [
    note.Note(
      note_id: "note_id",
      parent_id: "parent_id",
      significance: note.Regular,
      user_id: 0,
      message: "message",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
      thread_notes: [],
      edited: False,
    ),
    note.Note(
      note_id: "note_id",
      parent_id: "parent_id",
      significance: note.Regular,
      user_id: 0,
      message: "message",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
      thread_notes: [],
      edited: False,
    ),
  ]

  list.map(notes, note.encode_note)
  |> json.preprocessed_array
  |> json.to_string
  |> dynamic.from
  |> note.decode_notes
  |> should.equal(Ok(notes))
}
