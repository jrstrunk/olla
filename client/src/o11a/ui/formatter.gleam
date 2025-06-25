import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/string
import o11a/computed_note
import o11a/note
import o11a/topic

pub fn get_notes(
  discussion: dict.Dict(String, List(note.NoteStub)),
  leading_spaces leading_spaces,
  topic_id topic_id,
  topics topics,
) {
  let parent_notes =
    dict.get(discussion, topic_id)
    |> result.unwrap([])
  // todo as "why what this filtering notes that had a parent id of the topic?"

  let info_notes =
    parent_notes
    |> list.filter_map(fn(note) {
      case note.kind {
        note.InformationalNoteStub ->
          topic.get_computed_note(topics, note.topic_id)
        _ -> Error(Nil)
      }
    })
    |> list.map(split_info_note(_, leading_spaces))
    |> list.flatten

  #(parent_notes, info_notes)
}

fn split_info_note(note: computed_note.ComputedNote, leading_spaces) {
  note.message_text
  |> split_info_comment(note.expanded_message != option.None, leading_spaces)
  |> list.index_map(fn(comment, index) {
    #(note.note_id <> int.to_string(index), comment)
  })
}

fn split_info_comment(
  comment: String,
  contains_expanded_message: Bool,
  leading_spaces,
) {
  let comment_length = string.length(comment)
  let columns_remaining = 80 - leading_spaces

  case comment_length <= columns_remaining {
    True -> [
      comment
      <> case contains_expanded_message {
        True -> "^"
        False -> ""
      },
    ]
    False -> {
      let backwards =
        string.slice(comment, 0, columns_remaining)
        |> string.reverse

      let in_limit_comment_length =
        backwards
        |> string.split_once(" ")
        |> result.unwrap(#("", backwards))
        |> pair.second
        |> string.length

      let rest =
        string.slice(
          comment,
          in_limit_comment_length + 1,
          length: comment_length,
        )

      [
        string.slice(comment, 0, in_limit_comment_length),
        ..split_info_comment(rest, contains_expanded_message, leading_spaces)
      ]
    }
  }
}
