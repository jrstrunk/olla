import gleam/function
import gleam/option
import gleeunit/should
import lib/persistent_concurrent_duplicate_dict as pcd_dict
import o11a/note
import o11a/server/discussion

pub fn note_round_trip_test() {
  let note = note.example_note()
  pcd_dict.test_round_trip(
    note,
    discussion.note_persist_encoder,
    discussion.note_persist_decoder(),
  )
  |> should.equal(note)
}

pub fn note_vote_round_trip_test() {
  let ex = note.example_note_vote()
  pcd_dict.test_round_trip(
    ex,
    discussion.note_vote_persist_encoder,
    discussion.note_vote_persist_decoder(),
  )
  |> should.equal(ex)
}

pub fn structured_notes_test() {
  let assert Ok(notes) =
    pcd_dict.build(
      ":memory:",
      function.identity,
      function.identity,
      note.example_note(),
      discussion.note_persist_encoder,
      discussion.note_persist_decoder(),
    )

  let discussion =
    discussion.Discussion(
      audit_name: "test",
      notes: notes,
      votes: pcd_dict.empty(),
    )

  let first_note =
    note.Note(
      note_id: "L1",
      parent_id: "L50",
      significance: note.Regular,
      user_id: 0,
      message: "hello",
      expanded_message: option.None,
      time: note.example_note().time,
      thread_notes: [],
      edited: False,
    )

  let assert Ok(Nil) = pcd_dict.insert(notes, first_note.parent_id, first_note)

  let second_note =
    note.Note(
      note_id: "L2",
      parent_id: "L1",
      significance: note.Regular,
      user_id: 0,
      message: "world",
      expanded_message: option.None,
      time: note.example_note().time,
      thread_notes: [],
      edited: False,
    )

  let assert Ok(Nil) =
    pcd_dict.insert(notes, second_note.parent_id, second_note)

  let third_note =
    note.Note(
      note_id: "L3",
      parent_id: "L1",
      significance: note.Regular,
      user_id: 0,
      message: "hello2",
      expanded_message: option.None,
      time: note.example_note().time,
      thread_notes: [],
      edited: False,
    )

  let assert Ok(Nil) = pcd_dict.insert(notes, third_note.parent_id, third_note)

  let fourth_note =
    note.Note(
      note_id: "L4",
      parent_id: "L3",
      significance: note.Regular,
      user_id: 0,
      message: "world2",
      expanded_message: option.None,
      time: note.example_note().time,
      thread_notes: [],
      edited: False,
    )

  let assert Ok(Nil) =
    pcd_dict.insert(notes, fourth_note.parent_id, fourth_note)

  discussion.get_structured_notes(discussion, first_note.parent_id)
  |> should.equal([
    note.Note(
      note_id: "L1",
      parent_id: "L50",
      significance: note.Regular,
      user_id: 0,
      message: "hello",
      expanded_message: option.None,
      time: note.example_note().time,
      thread_notes: [
        note.Note(
          note_id: "L2",
          parent_id: "L1",
          significance: note.Regular,
          user_id: 0,
          message: "world",
          expanded_message: option.None,
          time: note.example_note().time,
          thread_notes: [],
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
          thread_notes: [
            note.Note(
              note_id: "L4",
              parent_id: "L3",
              significance: note.Regular,
              user_id: 0,
              message: "world2",
              expanded_message: option.None,
              time: note.example_note().time,
              thread_notes: [],
              edited: False,
            ),
          ],
          edited: False,
        ),
      ],
      edited: False,
    ),
  ])
}
