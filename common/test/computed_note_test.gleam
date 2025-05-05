import gleam/dynamic
import gleam/json
import gleam/option.{None}
import o11a/computed_note
import tempo/datetime

pub fn encode_computed_notes_round_trip_test() {
  let cn =
    computed_note.ComputedNote(
      note_id: "L1",
      parent_id: "L1",
      significance: computed_note.Informational,
      user_name: "John",
      message: "This is a test",
      expanded_message: None,
      time: datetime.literal("2024-01-01T00:00:00Z"),
      edited: False,
      references: [],
      reference: option.None,
    )

  computed_note.encode_computed_notes([cn])
  |> json.to_string
  |> dynamic.from
  |> computed_note.decode_computed_notes
}
