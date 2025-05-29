import gleam/dict
import gleam/dynamic/decode
import gleam/json

pub fn encode_topic_merges(topic_merges: dict.Dict(String, String)) {
  dict.to_list(topic_merges)
  |> json.array(fn(topic_merge) {
    json.array([topic_merge.0, topic_merge.1], json.string)
  })
}

pub fn topic_merge_decoder() {
  use old_topic <- decode.field(0, decode.string)
  use new_topic <- decode.field(1, decode.string)
  decode.success(#(old_topic, new_topic))
}
