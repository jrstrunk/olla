import gleam/json
import gleeunit/should
import o11a/note

pub fn encode_note_round_trip_test() {
  note.example_note_submission
  |> note.encode_note_submission
  |> json.to_string
  |> json.parse(note.note_submission_decoder())
  |> should.equal(Ok(note.example_note_submission))
}
