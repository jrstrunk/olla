import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import o11a/computed_note
import o11a/preprocessor
import tempo
import tempo/datetime

pub type Topic {
  AuditFile(topic_id: String, path: String, name: String)
  SourceDeclaration(
    topic_id: String,
    name: String,
    signature: List(preprocessor.PreProcessedLine),
    scope: Scope,
    kind: preprocessor.DeclarationKind,
    source_map: preprocessor.SourceMap,
    references: List(preprocessor.Reference),
    calls: List(String),
    errors: List(String),
  )
  TextDeclaration(
    topic_id: String,
    name: String,
    signature: List(preprocessor.PreProcessedLine),
    scope: Scope,
  )
  ComputedNote(
    topic_id: String,
    signature: List(preprocessor.PreProcessedLine),
    parent_topic_id: String,
    significance: computed_note.ComputedNoteSignificance,
    user_name: String,
    message: String,
    expanded_message: option.Option(String),
    time: tempo.DateTime,
    referenced_topic_ids: List(String),
    edited: Bool,
    referee_topic_id: option.Option(String),
  )
  NoteDeclaration(
    topic_id: String,
    signature: List(preprocessor.PreProcessedLine),
    parent_topic_id: String,
  )
  AttackVector(topic_id: String, name: String)
}

pub fn topic_to_json(topic: Topic) -> json.Json {
  case topic {
    AuditFile(topic_id:, path:, name:) ->
      json.object([
        #("v", json.string("f")),
        #("t", json.string(topic_id)),
        #("p", json.string(path)),
        #("n", json.string(name)),
      ])
    SourceDeclaration(
      topic_id:,
      name:,
      signature:,
      scope:,
      kind:,
      source_map:,
      references:,
      calls:,
      errors:,
    ) ->
      json.object([
        #("v", json.string("s")),
        #("t", json.string(topic_id)),
        #("n", json.string(name)),
        #("g", json.array(signature, preprocessor.encode_pre_processed_line)),
        #("s", scope_to_json(scope)),
        #("k", preprocessor.encode_declaration_kind(kind)),
        #("m", preprocessor.encode_source_map(source_map)),
        #("r", json.array(references, preprocessor.encode_reference)),
        #("c", json.array(calls, json.string)),
        #("e", json.array(errors, json.string)),
      ])
    TextDeclaration(topic_id:, name:, signature:, scope:) ->
      json.object([
        #("v", json.string("t")),
        #("t", json.string(topic_id)),
        #("n", json.string(name)),
        #("g", json.array(signature, preprocessor.encode_pre_processed_line)),
        #("s", scope_to_json(scope)),
      ])
    ComputedNote(
      topic_id:,
      signature:,
      parent_topic_id:,
      significance:,
      user_name:,
      message:,
      expanded_message:,
      time:,
      referenced_topic_ids:,
      edited:,
      referee_topic_id:,
    ) ->
      json.object([
        #("v", json.string("c")),
        #("n", json.string(topic_id)),
        #("g", json.array(signature, preprocessor.encode_pre_processed_line)),
        #("p", json.string(parent_topic_id)),
        #("s", json.int(computed_note.significance_to_int(significance))),
        #("u", json.string(user_name)),
        #("m", json.string(message)),
        #("x", case expanded_message {
          option.None -> json.null()
          option.Some(value) -> json.string(value)
        }),
        #("t", json.int(datetime.to_unix_milli(time))),
        #("e", json.bool(edited)),
        #("r", json.array(referenced_topic_ids, json.string)),
        #("f", json.nullable(referee_topic_id, json.string)),
      ])
    NoteDeclaration(topic_id:, signature:, parent_topic_id:) ->
      json.object([
        #("v", json.string("n")),
        #("t", json.string(topic_id)),
        #("g", json.array(signature, preprocessor.encode_pre_processed_line)),
        #("p", json.string(parent_topic_id)),
      ])
    AttackVector(topic_id:, name:) ->
      json.object([
        #("v", json.string("a")),
        #("t", json.string(topic_id)),
        #("n", json.string(name)),
      ])
  }
}

pub fn topic_decoder() -> decode.Decoder(Topic) {
  use variant <- decode.field("v", decode.string)
  case variant {
    "f" -> {
      use topic_id <- decode.field("t", decode.string)
      use path <- decode.field("p", decode.string)
      use name <- decode.field("n", decode.string)
      decode.success(AuditFile(topic_id:, path:, name:))
    }
    "s" -> {
      use topic_id <- decode.field("t", decode.string)
      use name <- decode.field("n", decode.string)
      use signature <- decode.field(
        "g",
        decode.list(preprocessor.pre_processed_line_decoder()),
      )
      use scope <- decode.field("s", scope_decoder())
      use kind <- decode.field("k", preprocessor.declaration_kind_decoder())
      use source_map <- decode.field("m", preprocessor.source_map_decoder())
      use references <- decode.field(
        "r",
        decode.list(preprocessor.reference_decoder()),
      )
      use calls <- decode.field("c", decode.list(decode.string))
      use errors <- decode.field("e", decode.list(decode.string))
      decode.success(SourceDeclaration(
        topic_id:,
        name:,
        signature:,
        scope:,
        kind:,
        source_map:,
        references:,
        calls:,
        errors:,
      ))
    }
    "t" -> {
      use topic_id <- decode.field("t", decode.string)
      use name <- decode.field("n", decode.string)
      use signature <- decode.field(
        "g",
        decode.list(preprocessor.pre_processed_line_decoder()),
      )
      use scope <- decode.field("s", scope_decoder())
      decode.success(TextDeclaration(topic_id:, name:, signature:, scope:))
    }
    "c" -> {
      use topic_id <- decode.field("n", decode.string)
      use signature <- decode.field(
        "g",
        decode.list(preprocessor.pre_processed_line_decoder()),
      )
      use parent_topic_id <- decode.field("p", decode.string)
      use significance <- decode.field("s", decode.int)
      use user_name <- decode.field("u", decode.string)
      use message <- decode.field("m", decode.string)
      use expanded_message <- decode.field("x", decode.optional(decode.string))
      use time <- decode.field("t", decode.int)
      use edited <- decode.field("e", decode.bool)
      use referenced_topic_ids <- decode.field("r", decode.list(decode.string))
      use referee_topic_id <- decode.field("f", decode.optional(decode.string))
      decode.success(ComputedNote(
        topic_id:,
        signature:,
        parent_topic_id:,
        significance: computed_note.significance_from_int(significance),
        user_name:,
        message:,
        expanded_message:,
        time: datetime.from_unix_milli(time),
        referenced_topic_ids:,
        edited:,
        referee_topic_id:,
      ))
    }
    "n" -> {
      use topic_id <- decode.field("t", decode.string)
      use signature <- decode.field(
        "g",
        decode.list(preprocessor.pre_processed_line_decoder()),
      )
      use parent_topic_id <- decode.field("p", decode.string)
      decode.success(NoteDeclaration(topic_id:, signature:, parent_topic_id:))
    }
    "a" -> {
      use topic_id <- decode.field("t", decode.string)
      use name <- decode.field("n", decode.string)
      decode.success(AttackVector(topic_id:, name:))
    }
    _ -> decode.failure(AttackVector(topic_id: "", name: ""), "Topic")
  }
}

pub type Scope {
  Scope(
    file: String,
    contract: option.Option(String),
    member: option.Option(String),
  )
}

fn scope_to_json(scope: Scope) -> json.Json {
  let Scope(file:, contract:, member:) = scope
  json.object(
    [
      [#("f", json.string(file))],
      case contract {
        option.None -> []
        option.Some(contract) -> [#("c", json.string(contract))]
      },
      case member {
        option.None -> []
        option.Some(member) -> [#("m", json.string(member))]
      },
    ]
    |> list.flatten,
  )
}

fn scope_decoder() -> decode.Decoder(Scope) {
  use file <- decode.field("f", decode.string)
  use contract <- decode.optional_field(
    "c",
    option.None,
    decode.optional(decode.string),
  )
  use member <- decode.optional_field(
    "m",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(Scope(file:, contract:, member:))
}

pub fn contract_scope_to_string(scope: Scope) {
  scope.contract
  |> option.unwrap("")
  <> option.map(scope.member, fn(member) { "." <> member })
  |> option.unwrap("")
}
