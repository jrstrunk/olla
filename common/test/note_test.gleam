import gleam/dynamic
import gleam/json
import gleam/list
import gleam/option
import gleeunit/should
import o11a/note

pub fn encode_note_round_trip_test() {
  note.example_note()
  |> note.encode_note
  |> json.to_string
  |> json.parse(note.note_decoder())
  |> should.equal(Ok(note.example_note()))
}

pub fn encode_notes_round_trip_test() {
  let notes = [
    #("L50", [
      note.Note(
        note_id: "L1",
        parent_id: "L50",
        significance: note.Regular,
        user_id: 0,
        message: "hello",
        expanded_message: option.None,
        time: note.example_note().time,
        edited: False,
      ),
    ]),
    #("L1", [
      note.Note(
        note_id: "L2",
        parent_id: "L1",
        significance: note.Regular,
        user_id: 0,
        message: "world",
        expanded_message: option.None,
        time: note.example_note().time,
        edited: False,
      ),
      note.Note(
        note_id: "L3",
        parent_id: "L1",
        significance: note.Regular,
        user_id: 0,
        message: "hello2",
        expanded_message: option.None,
        time: note.example_note().time,
        edited: False,
      ),
    ]),
    #("L3", [
      note.Note(
        note_id: "L4",
        parent_id: "L3",
        significance: note.Regular,
        user_id: 0,
        message: "world2",
        expanded_message: option.None,
        time: note.example_note().time,
        edited: False,
      ),
    ]),
  ]

  list.map(notes, note.encode_structured_notes)
  |> json.preprocessed_array
  |> json.to_string
  |> dynamic.from
  |> note.decode_structured_notes
  |> should.equal(Ok(notes))
}
