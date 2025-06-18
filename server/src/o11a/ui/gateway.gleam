import concurrent_dict
import filepath
import gleam/dict
import gleam/dynamic/decode
import gleam/function
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/string_tree
import lib/persistent_concurrent_structured_dict
import o11a/computed_note
import o11a/note
import persistent_concurrent_dict

import lib/persistent_concurrent_duplicate_dict
import lib/snagx
import lustre
import o11a/attack_vector
import o11a/audit_metadata
import o11a/config
import o11a/preprocessor
import o11a/preprocessor_text
import o11a/server/discussion
import o11a/server/preprocessor_sol
import o11a/server/preprocessor_text as preprocessor_text_server
import o11a/topic
import o11a/ui/discussion_component
import simplifile
import snag

pub type Gateway {
  Gateway(
    audit_metadata: persistent_concurrent_dict.PersistentConcurrentDict(
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
    topic_gateway: concurrent_dict.ConcurrentDict(
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
        attack_vector.AttackVector,
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
        List(computed_note.ComputedNote),
      ),
    ),
  )
}

pub type DiscussionComponentGateway =
  concurrent_dict.ConcurrentDict(
    String,
    lustre.Runtime(discussion_component.Msg),
  )

pub fn start_gateway() -> Result(Gateway, snag.Snag) {
  let source_file_gateway = concurrent_dict.new()
  let topic_gateway = concurrent_dict.new()
  let merged_topics_gateway = concurrent_dict.new()
  let attack_vectors_gateway = concurrent_dict.new()
  let discussion_gateway = concurrent_dict.new()
  let discussion_component_gateway = concurrent_dict.new()

  let page_paths = config.get_all_audit_page_paths()

  use audit_metadata <- result.try(build_audit_metadata())

  use _ <- result.map(
    dict.keys(page_paths)
    |> list.map(fn(audit_name) {
      use source_files <- result.try(build_source_files(audit_name))
      concurrent_dict.insert(source_file_gateway, audit_name, source_files)

      use
        topics: persistent_concurrent_dict.PersistentConcurrentDict(
          String,
          topic.Topic,
        )
      <- result.try(build_topics(audit_name))
      concurrent_dict.insert(topic_gateway, audit_name, topics)

      use merged_topics <- result.try(build_merged_topics(audit_name))
      concurrent_dict.insert(merged_topics_gateway, audit_name, merged_topics)

      use audit_attack_vectors <- result.try(build_attack_vectors(audit_name))
      concurrent_dict.insert(
        attack_vectors_gateway,
        audit_name,
        audit_attack_vectors,
      )

      use discussion <- result.try(discussion.build_audit_discussion(audit_name))
      concurrent_dict.insert(discussion_gateway, audit_name, discussion)

      use discussion_component_actor <- result.try(
        lustre.start_server_component(discussion_component.app(), #(
          audit_name,
          discussion,
          topics,
        ))
        |> snag.map_error(string.inspect),
      )
      concurrent_dict.insert(
        discussion_component_gateway,
        audit_name,
        discussion_component_actor,
      )

      Ok(Nil)
    })
    |> snagx.collect_errors,
  )

  Gateway(
    audit_metadata:,
    source_file_gateway:,
    topic_gateway:,
    merged_topics_gateway:,
    attack_vectors_gateway:,
    discussion_gateway:,
    discussion_component_gateway:,
  )
}

pub fn get_audit_metadata(gateway: Gateway, for audit_name) {
  case persistent_concurrent_dict.get(gateway.audit_metadata, audit_name) {
    Ok(metadata) -> Ok(metadata)
    Error(Nil) -> {
      gather_audit_data(gateway, for: audit_name)
      persistent_concurrent_dict.get(gateway.audit_metadata, audit_name)
    }
  }
}

pub fn get_source_file(gateway: Gateway, page_path page_path) {
  let audit_name = config.get_audit_name_from_page_path(page_path)

  case concurrent_dict.get(gateway.source_file_gateway, audit_name) {
    Ok(source_files) -> persistent_concurrent_dict.get(source_files, page_path)
    Error(Nil) -> {
      gather_audit_data(gateway, for: audit_name)
      concurrent_dict.get(gateway.source_file_gateway, audit_name)
      |> result.try(persistent_concurrent_dict.get(_, page_path))
    }
  }
}

pub fn get_topics(gateway: Gateway, for audit_name) {
  case concurrent_dict.get(gateway.topic_gateway, audit_name) {
    Ok(topics) -> Ok(topics)
    Error(Nil) -> {
      gather_audit_data(gateway, for: audit_name)
      concurrent_dict.get(gateway.topic_gateway, audit_name)
    }
  }
}

pub fn get_merged_topics(gateway: Gateway, for audit_name) {
  case concurrent_dict.get(gateway.merged_topics_gateway, audit_name) {
    Ok(merged_topics) -> Ok(merged_topics)
    Error(Nil) -> {
      gather_audit_data(gateway, for: audit_name)
      concurrent_dict.get(gateway.merged_topics_gateway, audit_name)
    }
  }
}

pub fn merge_topics(
  gateway: Gateway,
  audit_name audit_name,
  current_topic_id current_topic_id,
  new_topic_id new_topic_id,
) {
  case concurrent_dict.get(gateway.merged_topics_gateway, audit_name) {
    Ok(merged_topics) -> {
      persistent_concurrent_dict.insert(
        merged_topics,
        current_topic_id,
        new_topic_id,
      )
    }
    Error(Nil) -> {
      gather_audit_data(gateway, for: audit_name)

      use merged_topics <- result.try(
        concurrent_dict.get(gateway.merged_topics_gateway, audit_name)
        |> result.replace_error(snag.new(
          "Failed to find the current merged topics for " <> audit_name,
        )),
      )

      persistent_concurrent_dict.insert(
        merged_topics,
        current_topic_id,
        new_topic_id,
      )
    }
  }
}

pub fn get_attack_vectors(gateway: Gateway, for audit_name) {
  case concurrent_dict.get(gateway.attack_vectors_gateway, audit_name) {
    Ok(attack_vectors) -> Ok(attack_vectors)
    Error(Nil) -> {
      gather_audit_data(gateway, for: audit_name)
      concurrent_dict.get(gateway.attack_vectors_gateway, audit_name)
    }
  }
}

pub fn add_attack_vector(
  gateway: Gateway,
  audit_name audit_name,
  title title: String,
) {
  case concurrent_dict.get(gateway.attack_vectors_gateway, audit_name) {
    Ok(attack_vectors) -> {
      persistent_concurrent_duplicate_dict.insert(attack_vectors, Nil, title)
    }
    Error(Nil) -> {
      gather_audit_data(gateway, for: audit_name)

      use attack_vectors <- result.try(
        concurrent_dict.get(gateway.attack_vectors_gateway, audit_name)
        |> result.replace_error(snag.new(
          "Failed to find the current attack vectors for " <> audit_name,
        )),
      )
      persistent_concurrent_duplicate_dict.insert(attack_vectors, Nil, title)
    }
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

fn build_audit_metadata() {
  persistent_concurrent_dict.build(
    config.get_persist_path(for: "audit_metadata"),
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

fn build_source_files(for audit_name) {
  persistent_concurrent_dict.build(
    config.get_persist_path(for: audit_name <> "/preprocessed_source_files"),
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

fn build_topics(for audit_name) {
  persistent_concurrent_dict.build(
    config.get_persist_path(for: audit_name <> "/topics"),
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

fn build_merged_topics(for audit_name) {
  persistent_concurrent_dict.build(
    config.get_persist_path(for: audit_name <> "/merged_topics"),
    key_encoder: function.identity,
    key_decoder: function.identity,
    val_encoder: function.identity,
    val_decoder: function.identity,
  )
}

fn build_attack_vectors(audit_name) {
  persistent_concurrent_duplicate_dict.build(
    path: config.get_persist_path(for: audit_name <> "/audit_attack_vectors"),
    key_encoder: fn(_) { "Nil" },
    key_decoder: fn(_) { Nil },
    val_encoder: fn(val) {
      [
        persistent_concurrent_duplicate_dict.text(val.title),
        persistent_concurrent_duplicate_dict.text(val.topic_id),
      ]
    },
    val_decoder: {
      use title <- decode.field(0, decode.string)
      use topic_id <- decode.field(1, decode.string)
      decode.success(attack_vector.AttackVector(title:, topic_id:))
    },
    build_val: fn(title, record_count) {
      attack_vector.AttackVector(
        title:,
        topic_id: "AV" <> int.to_string(record_count),
      )
    },
    example: attack_vector.AttackVector(title: "Hi", topic_id: "Ex"),
  )
}

fn gather_audit_data(gateway gateway: Gateway, for audit_name) {
  case
    do_gather_audit_data(gateway:, for: audit_name)
    |> snag.context("Failed to gather audit data for " <> audit_name)
  {
    Ok(Nil) -> Nil
    Error(e) -> io.println(e |> snag.line_print)
  }
}

fn do_gather_audit_data(gateway gateway: Gateway, for audit_name) {
  use metadata <- result.try(gather_metadata(for: audit_name))

  use Nil <- result.try(persistent_concurrent_dict.insert(
    gateway.audit_metadata,
    audit_name,
    metadata |> audit_metadata.encode_audit_metadata |> json.to_string_tree,
  ))

  use #(source_files, declarations, merged_topics) <- result.try(
    preprocess_audit_source(for: audit_name),
  )

  use source_files_dict <- result.try(build_source_files(audit_name))

  use _nils <- result.try(
    list.map(source_files, fn(source_file) {
      persistent_concurrent_dict.insert(
        source_files_dict,
        source_file.0,
        json.array(source_file.1, preprocessor.encode_pre_processed_line)
          |> json.to_string_tree,
      )
    })
    |> result.all,
  )

  concurrent_dict.insert(
    gateway.source_file_gateway,
    audit_name,
    source_files_dict,
  )

  use topics_dict <- result.try(build_topics(audit_name))

  use _nils <- result.try(
    list.map(declarations, fn(declaration) {
      persistent_concurrent_dict.insert(
        topics_dict,
        declaration.topic_id,
        declaration,
      )
    })
    |> result.all,
  )

  concurrent_dict.insert(gateway.topic_gateway, audit_name, topics_dict)

  use merged_topics_dict <- result.try(build_merged_topics(audit_name))

  use _nils <- result.try(
    dict.to_list(merged_topics)
    |> list.map(fn(merged_topic) {
      persistent_concurrent_dict.insert(
        merged_topics_dict,
        merged_topic.0,
        merged_topic.1,
      )
    })
    |> result.all,
  )

  concurrent_dict.insert(
    gateway.merged_topics_gateway,
    audit_name,
    merged_topics_dict,
  )

  Ok(Nil)
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
      source_topics: sol_declarations,
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

  let all_declarations = dict.merge(text_declarations, sol_declarations)

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
    dict.values(all_declarations)
    |> list.append(addressable_lines)

  #(source_files, declarations, merged_topics)
}
