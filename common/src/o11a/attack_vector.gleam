import gleam/dynamic/decode
import gleam/json

pub type AttackVector {
  AttackVector(topic_id: String, title: String)
}

pub fn attack_vector_to_json(attack_vector: AttackVector) -> json.Json {
  let AttackVector(topic_id:, title:) = attack_vector
  json.object([
    #("topic_id", json.string(topic_id)),
    #("title", json.string(title)),
  ])
}

pub fn attack_vector_decoder() -> decode.Decoder(AttackVector) {
  use topic_id <- decode.field("topic_id", decode.string)
  use title <- decode.field("title", decode.string)
  decode.success(AttackVector(topic_id:, title:))
}
