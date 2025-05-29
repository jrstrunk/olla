import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleeunit/should
import o11a/discussion_topic

pub fn topic_merges_round_trip_test() {
  let topic_merges = [#("hello", "world"), #("world", "hello")]

  let topic_merges_json =
    dict.from_list(topic_merges)
    |> discussion_topic.encode_topic_merges
    |> json.to_string

  let assert Ok(topic_merges2) =
    json.parse(
      topic_merges_json,
      decode.list(discussion_topic.topic_merge_decoder()),
    )

  should.equal(topic_merges, topic_merges2)
}
