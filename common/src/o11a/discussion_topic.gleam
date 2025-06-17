import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import o11a/computed_note
import o11a/preprocessor

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

type TopicMerge {
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

pub fn get_combined_declaration(
  parent_topic_id parent_topic_id,
  declarations declarations: dict.Dict(String, preprocessor.Declaration),
  topic_merges topic_merges,
) {
  case dict.get(declarations, parent_topic_id) {
    Ok(declaration) -> {
      get_topic_chain(parent_topic_id, declarations, topic_merges, [])
      |> list.reverse
      |> list.fold(
        #(declaration, [parent_topic_id]),
        fn(
          decl_acc: #(preprocessor.Declaration, List(String)),
          next_decl: #(String, preprocessor.Declaration),
        ) {
          let #(existing_decl, updated_topic_ids) = decl_acc
          let #(next_topic_id, next_declaration) = next_decl

          case existing_decl, next_declaration {
            preprocessor.SourceDeclaration(..),
              preprocessor.SourceDeclaration(..)
            -> #(
              preprocessor.SourceDeclaration(
                ..next_declaration,
                references: list.append(
                  next_declaration.references,
                  existing_decl.references,
                ),
              ),
              [next_topic_id, ..updated_topic_ids],
            )
            _, _ -> decl_acc
          }
        },
      )
      |> Ok
    }
    Error(Nil) -> Error(Nil)
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
