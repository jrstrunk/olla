import concurrent_dict
import filepath
import gleam/dict
import gleam/dynamic/decode
import gleam/function
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/string_tree
import lib/persistent_concurrent_duplicate_dict
import lib/persistent_concurrent_structured_dict
import lib/snagx
import lustre
import o11a/audit_metadata
import o11a/config
import o11a/note
import o11a/preprocessor
import o11a/preprocessor_text
import o11a/server/discussion
import o11a/server/preprocessor_sol
import o11a/server/preprocessor_text as preprocessor_text_server
import o11a/topic
import o11a/ui/discussion_component
import persistent_concurrent_dict
import simplifile
import snag

pub type Gateway {
  Gateway(
    // Do not persist audit metadata, as it is quickly gathered and gathering
    // it validates that the audit exists.
    audit_metadata: concurrent_dict.ConcurrentDict(
      String,
      string_tree.StringTree,
      // Store it as a string tree because we never read it on the server,
      // but send it to the client as a string tree in a request body.
    ),
    source_file_gateway: concurrent_dict.ConcurrentDict(
      String,
      persistent_concurrent_dict.PersistentConcurrentDict(
        String,
        string_tree.StringTree,
        // Store it as a string tree because we never read it on the server,
        // but send it to the client as a string tree in a request body.
      ),
    ),
    source_declaration_gateway: concurrent_dict.ConcurrentDict(
      String,
      persistent_concurrent_dict.PersistentConcurrentDict(String, topic.Topic),
    ),
    merged_topics_gateway: concurrent_dict.ConcurrentDict(
      String,
      persistent_concurrent_dict.PersistentConcurrentDict(String, String),
    ),
    attack_vectors_gateway: concurrent_dict.ConcurrentDict(
      String,
      persistent_concurrent_duplicate_dict.PersistentConcurrentDuplicateDict(
        Nil,
        String,
        topic.Topic,
        // Store attack vectors separately so each audit gets their own id numbering
      ),
    ),
    discussion_component_gateway: DiscussionComponentGateway,
    discussion_gateway: concurrent_dict.ConcurrentDict(
      String,
      persistent_concurrent_structured_dict.PersistentConcurrentStructuredDict(
        String,
        note.NoteSubmission,
        note.Note,
        String,
        List(note.NoteStub),
      ),
    ),
    computed_note_gateway: concurrent_dict.ConcurrentDict(
      String,
      concurrent_dict.ConcurrentDict(String, topic.Topic),
    ),
    mentions_gateway: concurrent_dict.ConcurrentDict(
      String,
      concurrent_dict.ConcurrentDict(String, discussion.MentionCollection),
    ),
    // The topic gateway is made up of a combination of all the other topic
    // gateways. This way, the other topic types can be persisted in their own
    // aways, yet still be accessed in one place.
    topic_gateway: concurrent_dict.ConcurrentDict(
      String,
      concurrent_dict.ConcurrentDict(String, topic.Topic),
    ),
  )
}

pub type DiscussionComponentGateway =
  concurrent_dict.ConcurrentDict(
    String,
    lustre.Runtime(discussion_component.Msg),
  )

pub fn start_gateway() -> Result(Gateway, snag.Snag) {
  let gateway =
    Gateway(
      audit_metadata: concurrent_dict.new(),
      source_file_gateway: concurrent_dict.new(),
      source_declaration_gateway: concurrent_dict.new(),
      merged_topics_gateway: concurrent_dict.new(),
      attack_vectors_gateway: concurrent_dict.new(),
      discussion_gateway: concurrent_dict.new(),
      discussion_component_gateway: concurrent_dict.new(),
      computed_note_gateway: concurrent_dict.new(),
      mentions_gateway: concurrent_dict.new(),
      topic_gateway: concurrent_dict.new(),
    )

  let page_paths = config.get_all_audit_page_paths()

  use _ <- result.map(
    dict.keys(page_paths)
    |> list.map(fn(audit_name) {
      let all_persist_files_exist =
        check_source_files(for: audit_name)
        && check_source_declarations(for: audit_name)
        && check_merged_topics(for: audit_name)
      let gather_from_source = !all_persist_files_exist

      // It is important to always gather metadata first, as that makes sure the
      // audit exists before allocating memory and trying to read source files
      use metadata <- result.try(gather_metadata(for: audit_name))

      concurrent_dict.insert(
        gateway.audit_metadata,
        audit_name,
        metadata
          |> audit_metadata.encode_audit_metadata
          |> json.to_string_tree,
      )

      use source_files <- result.try(build_source_files(audit_name))
      concurrent_dict.insert(
        gateway.source_file_gateway,
        audit_name,
        source_files,
      )

      use source_declarations <- result.try(build_source_declarations(
        audit_name,
      ))
      concurrent_dict.insert(
        gateway.source_declaration_gateway,
        audit_name,
        source_declarations,
      )

      use merged_topics <- result.try(build_merged_topics(audit_name))
      concurrent_dict.insert(
        gateway.merged_topics_gateway,
        audit_name,
        merged_topics,
      )

      use Nil <- result.try({
        case gather_from_source {
          True -> {
            use
              #(
                preprocessed_source_files,
                preprocessed_declarations,
                preprocessed_merged_topics,
              )
            <- result.try(preprocess_audit_source(for: audit_name))

            use _nils <- result.try(
              list.map(preprocessed_source_files, fn(source_file) {
                persistent_concurrent_dict.insert(
                  source_files,
                  source_file.0,
                  json.array(
                    source_file.1,
                    preprocessor.encode_pre_processed_line,
                  )
                    |> json.to_string_tree,
                )
              })
              |> result.all,
            )

            use _nils <- result.try(
              list.map(preprocessed_declarations, fn(declaration) {
                persistent_concurrent_dict.insert(
                  source_declarations,
                  declaration.topic_id,
                  declaration,
                )
              })
              |> result.all,
            )

            use _nils <- result.try(
              dict.to_list(preprocessed_merged_topics)
              |> list.map(fn(merged_topic) {
                persistent_concurrent_dict.insert(
                  merged_topics,
                  merged_topic.0,
                  merged_topic.1,
                )
              })
              |> result.all,
            )

            Ok(Nil)
          }
          False -> Ok(Nil)
        }
      })

      use attack_vectors <- result.try(build_attack_vectors(audit_name))
      concurrent_dict.insert(
        gateway.attack_vectors_gateway,
        audit_name,
        attack_vectors,
      )

      let computed_notes = concurrent_dict.new()
      let mentions = concurrent_dict.new()

      use discussion <- result.try(discussion.build_audit_discussion(
        audit_name,
        computed_notes,
        mentions,
      ))
      concurrent_dict.insert(gateway.discussion_gateway, audit_name, discussion)

      concurrent_dict.insert(
        gateway.computed_note_gateway,
        audit_name,
        computed_notes,
      )

      let combined_topics =
        combine_topic_sources(
          source_declarations,
          attack_vectors,
          computed_notes,
          merged_topics,
        )

      concurrent_dict.insert(gateway.topic_gateway, audit_name, combined_topics)

      use discussion_component_actor <- result.try(
        lustre.start_server_component(discussion_component.app(), #(
          audit_name,
          discussion,
          combined_topics,
        ))
        |> snag.map_error(string.inspect),
      )
      concurrent_dict.insert(
        gateway.discussion_component_gateway,
        audit_name,
        discussion_component_actor,
      )

      Ok(Nil)
    })
    |> snagx.collect_errors,
  )

  gateway
}

pub fn get_audit_metadata(gateway: Gateway, for audit_name) {
  concurrent_dict.get(gateway.audit_metadata, audit_name)
}

pub fn get_source_file(gateway: Gateway, page_path page_path) {
  let audit_name = config.get_audit_name_from_page_path(page_path)

  case concurrent_dict.get(gateway.source_file_gateway, audit_name) {
    Ok(source_files) -> {
      persistent_concurrent_dict.get(source_files, page_path)
    }
    Error(Nil) -> Error(Nil)
  }
}

pub fn get_topics(gateway: Gateway, for audit_name) {
  concurrent_dict.get(gateway.topic_gateway, audit_name)
}

pub fn get_merged_topics(gateway: Gateway, for audit_name) {
  concurrent_dict.get(gateway.merged_topics_gateway, audit_name)
}

pub fn add_merged_topic(
  gateway: Gateway,
  audit_name audit_name,
  current_topic_id current_topic_id,
  new_topic_id new_topic_id,
) {
  case
    concurrent_dict.get(gateway.merged_topics_gateway, audit_name),
    concurrent_dict.get(gateway.attack_vectors_gateway, audit_name),
    concurrent_dict.get(gateway.source_declaration_gateway, audit_name),
    concurrent_dict.get(gateway.computed_note_gateway, audit_name)
  {
    Ok(merged_topics),
      Ok(attack_vectors),
      Ok(source_declarations),
      Ok(computed_notes)
    -> {
      use Nil <- result.map(persistent_concurrent_dict.insert(
        merged_topics,
        current_topic_id,
        new_topic_id,
      ))

      let combined_topics =
        combine_topic_sources(
          source_declarations,
          attack_vectors,
          computed_notes,
          merged_topics,
        )

      concurrent_dict.insert(gateway.topic_gateway, audit_name, combined_topics)
    }
    _, _, _, _ ->
      snag.error(
        "Failed to find the current merged topics for "
        <> audit_name
        <> ", cannot add merged topic",
      )
  }
}

pub fn add_attack_vector(
  gateway: Gateway,
  audit_name audit_name,
  title title: String,
) {
  case
    concurrent_dict.get(gateway.attack_vectors_gateway, audit_name),
    concurrent_dict.get(gateway.topic_gateway, audit_name)
  {
    Ok(attack_vectors), Ok(topics) -> {
      use attack_vector <- result.map(
        persistent_concurrent_duplicate_dict.insert(attack_vectors, Nil, title),
      )
      concurrent_dict.insert(topics, attack_vector.topic_id, attack_vector)
    }
    _, _ ->
      snag.error(
        "Failed to find attack vectors for "
        <> audit_name
        <> ", cannot add attack vector",
      )
  }
}

pub fn add_note(
  gateway: Gateway,
  audit_name audit_name,
  note_submission note_submission: note.NoteSubmission,
) {
  case
    concurrent_dict.get(gateway.discussion_gateway, audit_name),
    concurrent_dict.get(gateway.computed_note_gateway, audit_name),
    concurrent_dict.get(gateway.topic_gateway, audit_name)
  {
    Ok(discussion), Ok(computed_notes), Ok(topics) -> {
      use #(note, _note_stubs) <- result.try(
        persistent_concurrent_structured_dict.insert(
          discussion,
          note_submission.parent_id,
          note_submission,
          topic: note_submission.parent_id,
        ),
      )

      use computed_note <- result.try(
        concurrent_dict.get(computed_notes, note.note_id)
        |> result.replace_error(snag.new(
          "Failed to get computed note after inserting submission",
        )),
      )

      concurrent_dict.insert(topics, computed_note.topic_id, computed_note)

      echo "added note to discussion " <> string.inspect(note)

      Ok(Nil)
    }
    _, _, _ ->
      snag.error("Failed to find discussion or topics for " <> audit_name)
  }
}

pub fn get_discussion_component_actor(
  discussion_component_gateway: DiscussionComponentGateway,
  for audit_name,
) {
  concurrent_dict.get(discussion_component_gateway, audit_name)
}

pub fn get_discussion(gateway gateway: Gateway, for audit_name) {
  concurrent_dict.get(gateway.discussion_gateway, audit_name)
}

const source_file_persist_name = "preprocessed_source_files"

/// Checks if the persist file exists
fn check_source_files(for audit_name) {
  config.get_persist_path(for: audit_name <> "/" <> source_file_persist_name)
  |> simplifile.file_info
  |> result.is_ok
}

fn build_source_files(for audit_name) {
  persistent_concurrent_dict.build(
    config.get_persist_path(for: audit_name <> "/" <> source_file_persist_name),
    key_encoder: function.identity,
    key_decoder: function.identity,
    val_encoder: fn(val) {
      val |> string_tree.to_string |> string.replace("'", "''")
    },
    val_decoder: fn(val) {
      val |> string.replace("''", "'") |> string_tree.from_string
    },
  )
}

const source_declaration_persist_name = "source_declarations"

/// Checks if the persist file exists
fn check_source_declarations(for audit_name) -> Bool {
  config.get_persist_path(
    for: audit_name <> "/" <> source_declaration_persist_name,
  )
  |> simplifile.file_info
  |> result.is_ok
}

fn build_source_declarations(for audit_name) {
  persistent_concurrent_dict.build(
    config.get_persist_path(
      for: audit_name <> "/" <> source_declaration_persist_name,
    ),
    key_encoder: function.identity,
    key_decoder: function.identity,
    val_encoder: fn(val) {
      topic.topic_to_json(val)
      |> json.to_string
    },
    val_decoder: fn(val) {
      let assert Ok(val) = json.parse(val, topic.topic_decoder())
      val
    },
  )
}

const merged_topic_persist_name = "merged_topics"

/// Checks if the persist file exists
fn check_merged_topics(for audit_name) -> Bool {
  config.get_persist_path(for: audit_name <> "/" <> merged_topic_persist_name)
  |> simplifile.file_info
  |> result.is_ok
}

fn build_merged_topics(for audit_name) {
  persistent_concurrent_dict.build(
    config.get_persist_path(for: audit_name <> "/" <> merged_topic_persist_name),
    key_encoder: function.identity,
    key_decoder: function.identity,
    val_encoder: function.identity,
    val_decoder: function.identity,
  )
}

fn build_attack_vectors(audit_name) {
  persistent_concurrent_duplicate_dict.build(
    path: config.get_persist_path(for: audit_name <> "/attack_vectors"),
    key_encoder: fn(_) { "Nil" },
    key_decoder: fn(_) { Nil },
    val_encoder: fn(val: topic.Topic) {
      [
        persistent_concurrent_duplicate_dict.text(
          topic.topic_to_json(val)
          |> json.to_string
          |> string.replace("'", "''"),
        ),
      ]
    },
    val_decoder: {
      use topic_string <- decode.field(0, decode.string)
      case
        json.parse(
          topic_string |> string.replace("''", "'"),
          topic.topic_decoder(),
        )
      {
        Ok(topic) -> decode.success(topic)
        Error(e) ->
          decode.failure(
            topic.AttackVector("", ""),
            "topic - " <> string.inspect(e),
          )
      }
    },
    build_val: fn(name, record_count) {
      topic.AttackVector(name:, topic_id: "AV" <> int.to_string(record_count))
    },
    example: topic.AttackVector(name: "Hi", topic_id: "Ex"),
  )
}

fn gather_metadata(for audit_name) {
  let in_scope_files = {
    let in_scope_sol_files =
      config.get_audit_path(for: audit_name)
      |> filepath.join("scope.txt")
      |> simplifile.read
      |> result.unwrap("")
      |> string.split("\n")
      |> list.map(fn(path) {
        case path {
          "./" <> local_path -> audit_name <> "/" <> local_path
          "/" <> local_path -> audit_name <> "/" <> local_path
          local_path -> audit_name <> "/" <> local_path
        }
      })

    let doc_files =
      config.get_audit_page_paths(audit_name)
      |> list.filter(fn(path) {
        {
          filepath.extension(path) == Ok("md")
          || filepath.extension(path) == Ok("dj")
        }
        && !string.starts_with(path, filepath.join(audit_name, "lib"))
        && !string.starts_with(path, filepath.join(audit_name, "dependencies"))
      })

    list.append(in_scope_sol_files, doc_files)
  }

  Ok(audit_metadata.AuditMetaData(
    audit_name:,
    audit_formatted_name: audit_name,
    in_scope_files:,
  ))
}

fn preprocess_audit_source(for audit_name) {
  use sol_asts <- result.try(
    preprocessor_sol.read_asts(audit_name)
    |> snag.context("Unable to read sol asts for " <> audit_name),
  )

  let page_paths = config.get_all_audit_page_paths()

  let file_to_sol_ast =
    list.map(sol_asts, fn(ast) { #(ast.absolute_path, ast) })
    |> dict.from_list

  let max_topic_id = 1
  let merged_topics = dict.new()

  let #(max_topic_id, sol_declarations, merged_topics) =
    #(max_topic_id, dict.new(), merged_topics)
    |> list.fold(sol_asts, _, fn(declarations, ast) {
      preprocessor_sol.enumerate_declarations(declarations, ast)
    })

  let sol_declarations =
    sol_declarations
    |> list.fold(sol_asts, _, fn(declarations, ast) {
      preprocessor_sol.enumerate_references(declarations, ast)
    })
    |> preprocessor_sol.enumerate_errors

  use text_data <- result.try(
    preprocessor_text_server.read_asts(
      audit_name,
      source_topics: sol_declarations |> dict.values(),
    )
    |> snag.context("Unable to read text asts for " <> audit_name),
  )

  let #(text_asts, text_declarations) =
    list.fold(text_data, #([], dict.new()), fn(acc, ast) {
      let #(text_asts, text_declarations) = acc
      let #(ast, _max_topic_id, declarations) = ast
      #([ast, ..text_asts], dict.merge(text_declarations, declarations))
    })

  let file_to_text_ast =
    list.map(text_asts, fn(ast) { #(ast.document_parent, ast) })
    |> dict.from_list

  let all_declarations =
    dict.merge(text_declarations, sol_declarations) |> dict.values

  use #(_max_topic_id, source_files, addressable_lines, merged_topics) <- result.map(
    dict.get(page_paths, audit_name)
    |> result.unwrap([])
    |> list.fold(Ok(#(max_topic_id, [], [], merged_topics)), fn(acc, page_path) {
      use #(max_topic_id, source_files, addressable_lines, merged_topics) <- result.try(
        acc,
      )

      use #(new_max_topic_id, source_file, addressable_lines, merged_topics) <- result.map(
        case preprocessor.classify_source_kind(path: page_path) {
          // Solidity source file
          Ok(preprocessor.Solidity) ->
            case
              config.get_full_page_path(for: page_path) |> simplifile.read,
              dict.get(file_to_sol_ast, page_path)
            {
              Ok(source), Ok(ast) -> {
                let nodes = preprocessor_sol.linearize_nodes(ast)

                let #(
                  max_topic_id,
                  preprocessed_source,
                  new_addressable_lines,
                  merged_topics,
                ) =
                  preprocessor_sol.preprocess_source(
                    source:,
                    nodes:,
                    max_topic_id:,
                    merged_topics:,
                    page_path:,
                    audit_name:,
                  )

                Ok(#(
                  max_topic_id,
                  option.Some(#(page_path, preprocessed_source)),
                  list.append(new_addressable_lines, addressable_lines),
                  merged_topics,
                ))
              }
              // Solidity source file without an AST (unused project dependencies)
              Ok(_source), Error(Nil) -> {
                Ok(#(
                  max_topic_id,
                  option.None,
                  addressable_lines,
                  merged_topics,
                ))
              }

              Error(msg), _ ->
                snag.error(msg |> simplifile.describe_error)
                |> snag.context(
                  "Failed to preprocess page source for " <> page_path,
                )
            }

          // Text file 
          Ok(preprocessor.Text) ->
            case dict.get(file_to_text_ast, page_path) {
              Ok(ast) -> {
                // A text file will never increase the max topic id at this stage
                let preprocessed_source =
                  preprocessor_text.preprocess_source(
                    ast:,
                    declarations: all_declarations,
                  )

                Ok(#(
                  max_topic_id,
                  option.Some(#(page_path, preprocessed_source)),
                  addressable_lines,
                  merged_topics,
                ))
              }

              // Text file without an AST (unsupported text file)
              Error(Nil) ->
                Ok(#(
                  max_topic_id,
                  option.None,
                  addressable_lines,
                  merged_topics,
                ))
            }

          // If we get a unsupported file type, just ignore it. (Eventually we could 
          // handle image files, etc.)
          Error(Nil) ->
            Ok(#(max_topic_id, option.None, addressable_lines, merged_topics))
        },
      )

      #(
        new_max_topic_id,
        [source_file, ..source_files],
        addressable_lines,
        merged_topics,
      )
    }),
  )

  let source_files =
    list.filter_map(source_files, fn(source_file) {
      case source_file {
        option.Some(source_file) -> Ok(source_file)
        option.None -> Error(Nil)
      }
    })

  let declarations =
    all_declarations
    |> list.append(addressable_lines)

  #(source_files, declarations, merged_topics)
}

fn combine_topic_sources(
  source_declarations: persistent_concurrent_dict.PersistentConcurrentDict(
    String,
    topic.Topic,
  ),
  attack_vectors: persistent_concurrent_duplicate_dict.PersistentConcurrentDuplicateDict(
    Nil,
    String,
    topic.Topic,
  ),
  computed_notes: concurrent_dict.ConcurrentDict(String, topic.Topic),
  merged_topics: persistent_concurrent_dict.PersistentConcurrentDict(
    String,
    String,
  ),
) {
  persistent_concurrent_dict.to_list(source_declarations)
  |> list.append(
    persistent_concurrent_duplicate_dict.to_list(attack_vectors)
    |> list.map(fn(attack_vector_data) {
      let #(Nil, attack_vector) = attack_vector_data
      #(attack_vector.topic_id, attack_vector)
    }),
  )
  |> list.append(concurrent_dict.to_list(computed_notes))
  |> concurrent_dict.from_list
  |> merge_topics(merged_topics, get_combined_declaration)
}

fn combine_discussions(discussions, _merged_topics) {
  discussions
}

fn merge_topics(
  data data: concurrent_dict.ConcurrentDict(String, a),
  topic_merges topic_merges: persistent_concurrent_dict.PersistentConcurrentDict(
    String,
    String,
  ),
  get_combined_topics get_combined_topics,
) {
  let topic_merge_list =
    persistent_concurrent_dict.to_list(topic_merges)
    |> list.map(fn(topic_merge) {
      topic.TopicMerge(topic_merge.0, topic_merge.1)
    })

  find_topic_merge_chain_parents(topic_merge_list)
  |> list.map(fn(parent_topic_id) {
    case get_combined_topics(parent_topic_id, data, topic_merges) {
      Ok(#(combined_decl, updated_topic_ids)) ->
        list.each(updated_topic_ids, fn(topic_id) {
          // TODO: If we wanted to not replace the entire old topic, but only 
          // replace some things (like not replacing the declaration kind),
          // this would be the place to do it.
          concurrent_dict.insert(data, topic_id, combined_decl)
        })
      Error(Nil) -> Nil
    }
  })

  data
}

fn find_topic_merge_chain_parents(
  topic_merges topic_merges: List(topic.TopicMerge),
) {
  list.map(topic_merges, fn(topic_merge) {
    do_find_topic_merge_chain_parents(topic_merge.old_topic_id, topic_merges)
  })
  |> list.unique
}

fn do_find_topic_merge_chain_parents(
  old_topic_id old_topic_id,
  topic_merges topic_merges: List(topic.TopicMerge),
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

pub fn get_combined_declaration(
  parent_topic_id parent_topic_id,
  declarations declarations,
  topic_merges topic_merges,
) {
  case concurrent_dict.get(declarations, parent_topic_id) {
    Ok(declaration) -> {
      get_topic_chain(parent_topic_id, declarations, topic_merges, [])
      |> list.reverse
      |> list.fold(
        #(declaration, [parent_topic_id]),
        fn(
          decl_acc: #(topic.Topic, List(String)),
          next_decl: #(String, topic.Topic),
        ) {
          let #(existing_decl, updated_topic_ids) = decl_acc
          let #(next_topic_id, next_declaration) = next_decl

          // Combining source declarations is a spceial case because we want
          // to preserve the references of the original declaration
          case existing_decl, next_declaration {
            topic.SourceDeclaration(..), topic.SourceDeclaration(..) -> #(
              topic.SourceDeclaration(
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

fn get_topic_chain(
  parent_topic_id parent_topic_id,
  data data: concurrent_dict.ConcurrentDict(String, a),
  topic_merges topic_merges,
  combined_declarations combined_declarations,
) {
  case persistent_concurrent_dict.get(topic_merges, parent_topic_id) {
    Ok(new_topic_id) ->
      case concurrent_dict.get(data, new_topic_id) {
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
