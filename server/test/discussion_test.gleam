import gleeunit/should
import lib/persistent_concurrent_duplicate_dict
import o11a/note
import o11a/server/discussion

pub fn note_round_trip_test() {
  let note = note.example_note()
  persistent_concurrent_duplicate_dict.test_round_trip(
    note,
    discussion.note_persist_encoder,
    discussion.note_persist_decoder(),
  )
  |> should.equal(note)
}

pub fn note_vote_round_trip_test() {
  let ex = note.example_note_vote()
  persistent_concurrent_duplicate_dict.test_round_trip(
    ex,
    discussion.note_vote_persist_encoder,
    discussion.note_vote_persist_decoder(),
  )
  |> should.equal(ex)
}
