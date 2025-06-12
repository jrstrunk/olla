import gleam/dynamic/decode
import gleam/json
import gleam/option
import o11a/preprocessor

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

pub fn attack_vector_to_declaration(attack_vector: AttackVector, audit_name) {
  preprocessor.TextDeclaration(
    topic_id: attack_vector.topic_id,
    name: attack_vector.topic_id,
    signature: attack_vector.title,
    scope: preprocessor.Scope(
      file: audit_name <> "/dashboard",
      contract: option.None,
      member: option.None,
    ),
  )
}
