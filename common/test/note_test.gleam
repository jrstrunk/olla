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
      note_id: "note_id",
      parent_id: "parent_id",
      significance: note.Regular,
      user_id: 0,
      message: "message",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
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
      note_id: "note_id",
      parent_id: "parent_id",
      significance: note.Regular,
      user_id: 0,
      message: "message",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
    ),
    note.Note(
      note_id: "note_id",
      parent_id: "parent_id",
      significance: note.Regular,
      user_id: 0,
      message: "message",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
    ),
  ]

  list.map(notes, note.encode_note)
  |> json.preprocessed_array
  |> json.to_string
  |> dynamic.from
  |> note.decode_notes
  |> should.equal(Ok(notes))
}
