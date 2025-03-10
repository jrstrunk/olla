import gleam/json
import gleeunit/should
import o11a/note

pub fn encode_note_round_trip_test() {
  note.example_note()
  |> note.encode_note
  |> json.to_string
  |> json.parse(note.note_decoder())
  |> should.equal(Ok(note.example_note()))
}
