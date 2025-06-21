import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import o11a/computed_note
import o11a/preprocessor
import tempo
import tempo/datetime

pub type Topic {
  AuditFile(topic_id: String, path: String, name: String)
  SourceDeclaration(
    topic_id: String,
    id: Int,
    name: String,
    signature: List(preprocessor.PreProcessedSnippetLine),
    scope: preprocessor.Scope,
    kind: preprocessor.DeclarationKind,
    source_map: preprocessor.SourceMap,
    references: List(preprocessor.Reference),
    calls: List(String),
    errors: List(String),
  )
  TextDeclaration(
    topic_id: String,
    name: String,
    signature: List(preprocessor.PreProcessedSnippetLine),
    scope: preprocessor.Scope,
  )
  ComputedNote(
    topic_id: String,
    signature: List(preprocessor.PreProcessedSnippetLine),
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
    signature: List(preprocessor.PreProcessedSnippetLine),
    parent_topic_id: String,
  )
  AttackVector(topic_id: String, name: String)
  Unknown(topic_id: String)
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
      id:,
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
        #("i", json.int(id)),
        #("n", json.string(name)),
        #(
          "g",
          json.array(signature, preprocessor.pre_processed_snippet_line_to_json),
        ),
        #("s", preprocessor.encode_scope(scope)),
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
        #(
          "g",
          json.array(signature, preprocessor.pre_processed_snippet_line_to_json),
        ),
        #("s", preprocessor.encode_scope(scope)),
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
        #(
          "g",
          json.array(signature, preprocessor.pre_processed_snippet_line_to_json),
        ),
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
        #(
          "g",
          json.array(signature, preprocessor.pre_processed_snippet_line_to_json),
        ),
        #("p", json.string(parent_topic_id)),
      ])
    AttackVector(topic_id:, name:) ->
      json.object([
        #("v", json.string("a")),
        #("t", json.string(topic_id)),
        #("n", json.string(name)),
      ])
    Unknown(topic_id:) ->
      json.object([#("v", json.string("u")), #("t", json.string(topic_id))])
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
      use id <- decode.field("i", decode.int)
      use name <- decode.field("n", decode.string)
      use signature <- decode.field(
        "g",
        decode.list(preprocessor.pre_processed_snippet_line_decoder()),
      )
      use scope <- decode.field("s", preprocessor.scope_decoder())
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
        id:,
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
        decode.list(preprocessor.pre_processed_snippet_line_decoder()),
      )
      use scope <- decode.field("s", preprocessor.scope_decoder())
      decode.success(TextDeclaration(topic_id:, name:, signature:, scope:))
    }
    "c" -> {
      use topic_id <- decode.field("n", decode.string)
      use signature <- decode.field(
        "g",
        decode.list(preprocessor.pre_processed_snippet_line_decoder()),
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
        decode.list(preprocessor.pre_processed_snippet_line_decoder()),
      )
      use parent_topic_id <- decode.field("p", decode.string)
      decode.success(NoteDeclaration(topic_id:, signature:, parent_topic_id:))
    }
    "a" -> {
      use topic_id <- decode.field("t", decode.string)
      use name <- decode.field("n", decode.string)
      decode.success(AttackVector(topic_id:, name:))
    }
    "u" -> {
      use topic_id <- decode.field("t", decode.string)
      decode.success(Unknown(topic_id:))
    }
    _ -> decode.failure(AttackVector(topic_id: "", name: ""), "Topic")
  }
}

pub fn get_topic(topics, topic_id topic_id) {
  dict.get(topics, topic_id)
  |> result.unwrap(Unknown(topic_id:))
}

pub fn topic_qualified_name(topic: Topic) {
  case topic {
    AuditFile(path:, name:, ..) -> path <> "/" <> name
    SourceDeclaration(scope:, name:, ..) | TextDeclaration(name:, scope:, ..) ->
      preprocessor.declaration_to_qualified_name(scope, name)
    ComputedNote(topic_id:, ..)
    | NoteDeclaration(topic_id:, ..)
    | AttackVector(topic_id:, ..)
    | Unknown(topic_id:) -> topic_id
  }
}

pub fn topic_name(topic: Topic) {
  case topic {
    AuditFile(name:, ..) -> name
    SourceDeclaration(name:, ..)
    | TextDeclaration(name:, ..)
    | AttackVector(name:, ..) -> name
    ComputedNote(topic_id:, ..)
    | NoteDeclaration(topic_id:, ..)
    | Unknown(topic_id:) -> topic_id
  }
}

pub fn topic_link(topic: Topic) {
  case topic {
    AuditFile(path:, name:, ..) -> "/" <> path <> "/" <> name
    SourceDeclaration(scope:, name:, ..) | TextDeclaration(scope:, name:, ..) ->
      "/"
      <> scope.file
      <> "#"
      <> preprocessor.declaration_to_qualified_name(scope, name)
    AttackVector(topic_id:, ..) -> "/" <> "dashboard" <> "#" <> topic_id
    ComputedNote(..) | NoteDeclaration(..) | Unknown(..) -> ""
  }
}

pub fn topic_file(topic: Topic) {
  case topic {
    AuditFile(path:, ..) -> path
    SourceDeclaration(scope:, ..) | TextDeclaration(scope:, ..) -> scope.file
    AttackVector(..) -> "dashboard"
    ComputedNote(..) | NoteDeclaration(..) | Unknown(..) -> ""
  }
}

pub fn find_reference_topic(
  for value: String,
  with topics: dict.Dict(String, Topic),
) {
  let declarations = dict.values(topics)

  list.find(declarations, fn(topic) { topic_qualified_name(topic) == value })
  |> result.try_recover(fn(_) {
    // If exactly one declaration matches the unqualified name, use it
    case list.filter(declarations, fn(topic) { topic_name(topic) == value }) {
      [unique_topic] -> Ok(unique_topic)
      _ -> Error(Nil)
    }
  })
  |> result.map(fn(topic) { topic.topic_id })
}

pub fn encode_merged_topic(topic_merge: #(String, String)) {
  json.array([topic_merge.0, topic_merge.1], json.string)
}

pub fn encode_merged_topics(topic_merges: List(#(String, String))) {
  topic_merges
  |> json.array(fn(topic_merge) {
    json.array([topic_merge.0, topic_merge.1], json.string)
  })
}

pub fn merged_topic_decoder() {
  use old_topic <- decode.field(0, decode.string)
  use new_topic <- decode.field(1, decode.string)
  decode.success(#(old_topic, new_topic))
}

pub fn build_merged_topics(
  data data: dict.Dict(String, a),
  topic_merges topic_merges: dict.Dict(String, String),
  get_combined_topics get_combined_topics,
) {
  let topic_merge_list =
    dict.to_list(topic_merges)
    |> list.map(fn(topic_merge) { TopicMerge(topic_merge.0, topic_merge.1) })

  find_topic_merge_chain_parents(topic_merge_list)
  |> list.fold(data, fn(declarations, parent_topic_id) {
    case get_combined_topics(parent_topic_id, data, topic_merges) {
      Ok(#(combined_decl, updated_topic_ids)) ->
        list.fold(updated_topic_ids, declarations, fn(declarations, topic_id) {
          dict.insert(declarations, topic_id, combined_decl)
        })
      Error(Nil) -> declarations
    }
  })
}

pub type TopicMerge {
  TopicMerge(old_topic_id: String, new_topic_id: String)
}

fn find_topic_merge_chain_parents(topic_merges topic_merges: List(TopicMerge)) {
  list.map(topic_merges, fn(topic_merge) {
    do_find_topic_merge_chain_parents(topic_merge.old_topic_id, topic_merges)
  })
  |> list.unique
}

fn do_find_topic_merge_chain_parents(
  old_topic_id old_topic_id,
  topic_merges topic_merges: List(TopicMerge),
) {
  case
    list.find(topic_merges, fn(topic_merge) {
      topic_merge.new_topic_id == old_topic_id
    })
  {
    Ok(topic_merge) ->
      do_find_topic_merge_chain_parents(topic_merge.old_topic_id, topic_merges)
    Error(Nil) -> old_topic_id
  }
}

fn get_topic_chain(
  parent_topic_id parent_topic_id,
  data data: dict.Dict(String, a),
  topic_merges topic_merges,
  combined_declarations combined_declarations,
) {
  case dict.get(topic_merges, parent_topic_id) {
    Ok(new_topic_id) ->
      case dict.get(data, new_topic_id) {
        Ok(new_declaration) ->
          get_topic_chain(new_topic_id, data, topic_merges, [
            #(new_topic_id, new_declaration),
            ..combined_declarations
          ])
        Error(Nil) -> combined_declarations
      }
    Error(Nil) -> combined_declarations
  }
}

pub fn get_combined_discussion(
  parent_topic_id parent_topic_id,
  discussion discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  topic_merges topic_merges,
) {
  case dict.get(discussion, parent_topic_id) {
    Ok(notes) -> {
      get_topic_chain(parent_topic_id, discussion, topic_merges, [])
      |> list.fold(#(notes, [parent_topic_id]), fn(notes_acc, next_notes) {
        let #(existing_notes, updated_topic_ids) = notes_acc
        let #(next_topic_id, next_notes) = next_notes

        #(list.append(next_notes, existing_notes), [
          next_topic_id,
          ..updated_topic_ids
        ])
      })
      |> Ok
    }
    Error(Nil) -> Error(Nil)
  }
}
