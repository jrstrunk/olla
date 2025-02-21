import gleam/dynamic
import gleam/json
import gleam/list
import gleam/option.{None}
import gleeunit/should
import o11a/server/discussion
import tempo/datetime

pub fn encode_note_round_trip_test() {
  let note =
    discussion.Note(
      parent_id: "parent_id",
      note_type: discussion.LineCommentNote,
      significance: discussion.Regular,
      user_id: 0,
      message: "message",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
      thread_id: None,
      last_edit_time: None,
    )

  discussion.encode_note(note)
  |> json.to_string
  |> dynamic.from
  |> discussion.decode_note
  |> should.equal(Ok(note))
}

pub fn encode_notes_round_trip_test() {
  let notes = [
    discussion.Note(
      parent_id: "parent_id",
      note_type: discussion.LineCommentNote,
      significance: discussion.Regular,
      user_id: 0,
      message: "message",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
      thread_id: None,
      last_edit_time: None,
    ),
    discussion.Note(
      parent_id: "parent_id",
      note_type: discussion.LineCommentNote,
      significance: discussion.Regular,
      user_id: 0,
      message: "message",
      expanded_message: None,
      time: datetime.literal("2021-01-01T00:00:00Z"),
      thread_id: None,
      last_edit_time: None,
    ),
  ]

  list.map(notes, discussion.encode_note)
  |> json.preprocessed_array
  |> json.to_string
  |> dynamic.from
  |> discussion.decode_notes
  |> should.equal(Ok(notes))
}

pub fn note_type_round_trip_test() {
  list.each(
    [
      discussion.FunctionTestNote,
      discussion.FunctionInvariantNote,
      discussion.LineCommentNote,
      discussion.ThreadNote,
    ],
    fn(note_type) {
      discussion.note_type_to_int(note_type)
      |> discussion.note_type_from_int
      |> should.equal(note_type)
    },
  )
}
