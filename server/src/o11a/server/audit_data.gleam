import filepath
import gleam/dict
import gleam/dynamic/decode
import gleam/function
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/string_tree
import o11a/audit_metadata
import o11a/config
import o11a/discussion_topic
import o11a/preprocessor
import o11a/server/preprocessor_sol
import o11a/server/preprocessor_text
import persistent_concurrent_dict as pcd
import simplifile
import snag

// AuditData -------------------------------------------------------------------

pub opaque type AuditData {
  AuditData(
    source_file_provider: AuditSourceFileProvider,
    metadata_provider: AuditMetadataProvider,
    declarations_provider: AuditDeclarationsProvider,
    topic_merges_provider: AuditTopicMergesProvider,
  )
}

pub fn build() {
  use source_file_provider <- result.try(build_source_file_provider())
  use metadata_provider <- result.try(build_audit_metadata_provider())
  use declarations_provider <- result.try(build_declarations_provider())
  use topic_merges_provider <- result.try(build_topic_merges_provider())

  Ok(AuditData(
    source_file_provider:,
    metadata_provider:,
    declarations_provider:,
    topic_merges_provider:,
  ))
}

/// Returns the source file for the given page path. If the source file is not
/// available in the in-memory cache, it will try to gather it from disk. If the
/// source file is still not available, it will return an error.
pub fn get_source_file(audit_data: AuditData, for page_path) {
  case pcd.get(audit_data.source_file_provider.pcd, page_path) {
    Ok(source_file) -> Ok(source_file)

    Error(Nil) -> {
      let audit_name = config.get_audit_name_from_page_path(page_path)

      gather_audit_data(audit_data, for: audit_name)

      pcd.get(audit_data.source_file_provider.pcd, page_path)
    }
  }
}

/// Returns the metadata for the given audit name. If the metadata is not
/// available in the in-memory cache, it will try to gather it from disk.
/// If the metadata is still not available, it will return an error.
pub fn get_metadata(audit_data: AuditData, for audit_name) {
  case pcd.get(audit_data.metadata_provider.pcd, audit_name) {
    Ok(metadata) -> Ok(metadata)

    Error(Nil) -> {
      gather_audit_data(audit_data, for: audit_name)

      pcd.get(audit_data.metadata_provider.pcd, audit_name)
    }
  }
}

/// Returns the declarations for the given audit name. If the declarations are
/// not available in the in-memory cache, it will try to gather them from disk.
/// If the declarations are still not available, it will return an error.
pub fn get_declarations(audit_data: AuditData, for audit_name) {
  case pcd.get(audit_data.declarations_provider.pcd, audit_name) {
    Ok(declarations) -> Ok(declarations)

    Error(Nil) -> {
      gather_audit_data(audit_data, for: audit_name)

      pcd.get(audit_data.declarations_provider.pcd, audit_name)
    }
  }
}

pub fn get_topic_merges(audit_data: AuditData, for audit_name) {
  case pcd.get(audit_data.topic_merges_provider.pcd, audit_name) {
    Ok(topic_merges) -> Ok(topic_merges)

    Error(Nil) -> {
      gather_audit_data(audit_data, for: audit_name)

      pcd.get(audit_data.topic_merges_provider.pcd, audit_name)
    }
  }
}

fn gather_audit_data(audit_data: AuditData, for audit_name) {
  case
    do_gather_audit_data(audit_data, for: audit_name)
    |> snag.context("Failed to gather audit data for " <> audit_name)
  {
    Ok(Nil) -> Nil
    Error(e) -> io.println(e |> snag.line_print)
  }
}

fn do_gather_audit_data(audit_data: AuditData, for audit_name) {
  use #(source_files, declarations, addressable_lines, topic_merges) <- result.try(
    preprocess_audit_source(for: audit_name),
  )

  use metadata <- result.try(gather_metadata(for: audit_name))

  use Nil <- result.try(pcd.insert(
    audit_data.metadata_provider.pcd,
    audit_name,
    audit_metadata.encode_audit_metadata(metadata)
      |> json.to_string_tree,
  ))

  use _nils <- result.try(
    list.map(source_files, fn(source_file) {
      pcd.insert(
        audit_data.source_file_provider.pcd,
        source_file.0,
        json.array(source_file.1, preprocessor.encode_pre_processed_line)
          |> json.to_string_tree,
      )
    })
    |> result.all,
  )

  use Nil <- result.try(pcd.insert(
    audit_data.declarations_provider.pcd,
    audit_name,
    json.array(
      list.append(declarations, addressable_lines),
      preprocessor.encode_declaration,
    )
      |> json.to_string_tree,
  ))

  use Nil <- result.try(pcd.insert(
    audit_data.topic_merges_provider.pcd,
    audit_name,
    topic_merges,
  ))

  Ok(Nil)
}

// AuditSourceFileProvider -----------------------------------------------------

type AuditSourceFileProvider {
  AuditSourceFileProvider(
    pcd: pcd.PersistentConcurrentDict(String, string_tree.StringTree),
  )
}

fn build_source_file_provider() {
  use pcd <- result.map(
    pcd.build(
      config.get_persist_path(for: "audit_preprocessed_source_files"),
      key_encoder: function.identity,
      key_decoder: function.identity,
      val_encoder: fn(val) {
        val |> string_tree.to_string |> string.replace("'", "''")
      },
      val_decoder: fn(val) {
        val |> string.replace("''", "'") |> string_tree.from_string
      },
    ),
  )

  AuditSourceFileProvider(pcd:)
}

fn preprocess_audit_source(for audit_name) {
  use sol_asts <- result.try(
    preprocessor_sol.read_asts(audit_name)
    |> snag.context("Unable to read sol asts for " <> audit_name),
  )
  use text_asts <- result.try(
    preprocessor_text.read_asts(audit_name)
    |> snag.context("Unable to read text asts for " <> audit_name),
  )

  let page_paths = config.get_all_audit_page_paths()

  let file_to_sol_ast =
    list.map(sol_asts, fn(ast) { #(ast.absolute_path, ast) })
    |> dict.from_list

  let file_to_text_ast =
    list.map(text_asts, fn(ast) { #(ast.absolute_path, ast) })
    |> dict.from_list

  let #(max_topic_id, sol_declarations) =
    #(1, dict.new())
    |> list.fold(sol_asts, _, fn(declarations, ast) {
      preprocessor_sol.enumerate_declarations(declarations, ast)
    })

  let sol_declarations =
    sol_declarations
    |> list.fold(sol_asts, _, fn(declarations, ast) {
      preprocessor_sol.count_references(declarations, ast)
    })

  let #(max_topic_id, _text_declarations) =
    #(max_topic_id, dict.new())
    |> list.fold(text_asts, _, fn(declarations, ast) {
      preprocessor_text.enumerate_declarations(declarations, ast)
    })

  use #(_max_topic_id, source_files, addressable_lines, topic_merges) <- result.map(
    dict.get(page_paths, audit_name)
    |> result.unwrap([])
    |> list.fold(Ok(#(max_topic_id, [], [], dict.new())), fn(acc, page_path) {
      use #(max_topic_id, source_files, addressable_lines, topic_merges) <- result.try(
        acc,
      )

      use #(new_max_topic_id, source_file, addressable_lines, topic_merges) <- result.map(
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
                  topic_merges,
                ) =
                  preprocessor_sol.preprocess_source(
                    source:,
                    nodes:,
                    max_topic_id:,
                    topic_merges:,
                    page_path:,
                    audit_name:,
                  )

                Ok(#(
                  max_topic_id,
                  option.Some(#(page_path, preprocessed_source)),
                  list.append(new_addressable_lines, addressable_lines),
                  topic_merges,
                ))
              }
              // Solidity source file without an AST (unused project dependencies)
              Ok(_source), Error(Nil) -> {
                Ok(#(max_topic_id, option.None, addressable_lines, topic_merges))
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
                let nodes = preprocessor_text.linearize_nodes(ast)

                // A text file will never increase the max topic id at this stage
                let preprocessed_source =
                  preprocessor_text.preprocess_source(nodes:)

                Ok(#(
                  max_topic_id,
                  option.Some(#(page_path, preprocessed_source)),
                  addressable_lines,
                  topic_merges,
                ))
              }

              // Text file without an AST (unsupported text file)
              Error(Nil) ->
                Ok(#(max_topic_id, option.None, addressable_lines, topic_merges))
            }

          // If we get a unsupported file type, just ignore it. (Eventually we could 
          // handle image files, etc.)
          Error(Nil) ->
            Ok(#(max_topic_id, option.None, addressable_lines, topic_merges))
        },
      )

      #(
        new_max_topic_id,
        [source_file, ..source_files],
        addressable_lines,
        topic_merges,
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

  let declarations = dict.values(sol_declarations)

  #(source_files, declarations, addressable_lines, topic_merges)
}

// AuditMetadataProvider -------------------------------------------------------

type AuditMetadataProvider {
  AuditMetadataProvider(
    pcd: pcd.PersistentConcurrentDict(String, string_tree.StringTree),
  )
}

fn build_audit_metadata_provider() {
  use pcd <- result.map(
    pcd.build(
      config.get_persist_path(for: "audit_metadata"),
      key_encoder: function.identity,
      key_decoder: function.identity,
      val_encoder: fn(val) {
        val |> string_tree.to_string |> string.replace("'", "''")
      },
      val_decoder: fn(val) {
        val |> string.replace("''", "'") |> string_tree.from_string
      },
    ),
  )

  AuditMetadataProvider(pcd:)
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

// AuditDeclarationsProvider ---------------------------------------------------

type AuditDeclarationsProvider {
  AuditDeclarationsProvider(
    pcd: pcd.PersistentConcurrentDict(String, string_tree.StringTree),
  )
}

fn build_declarations_provider() {
  use pcd <- result.map(
    pcd.build(
      config.get_persist_path(for: "audit_declarations"),
      key_encoder: function.identity,
      key_decoder: function.identity,
      val_encoder: fn(val) {
        val |> string_tree.to_string |> string.replace("'", "''")
      },
      val_decoder: fn(val) {
        val |> string.replace("''", "'") |> string_tree.from_string
      },
    ),
  )

  AuditDeclarationsProvider(pcd:)
}

// AuditTopicMergesProvider ----------------------------------------------------

type AuditTopicMergesProvider {
  AuditTopicMergesProvider(
    pcd: pcd.PersistentConcurrentDict(String, dict.Dict(String, String)),
  )
}

fn build_topic_merges_provider() {
  use pcd <- result.map(
    pcd.build(
      config.get_persist_path(for: "audit_topic_merges"),
      key_encoder: function.identity,
      key_decoder: function.identity,
      val_encoder: fn(val) {
        val
        |> discussion_topic.encode_topic_merges
        |> json.to_string
      },
      val_decoder: fn(val) {
        let assert Ok(topic_merges) =
          json.parse(val, decode.list(discussion_topic.topic_merge_decoder()))
        dict.from_list(topic_merges)
      },
    ),
  )

  AuditTopicMergesProvider(pcd:)
}

pub fn add_topic_merge(
  audit_data: AuditData,
  audit_name audit_name,
  current_topic_id current_topic_id,
  new_topic_id new_topic_id,
) {
  pcd.get(audit_data.topic_merges_provider.pcd, audit_name)
  |> result.unwrap(dict.new())
  |> dict.insert(current_topic_id, new_topic_id)
  |> pcd.insert(audit_data.topic_merges_provider.pcd, audit_name, _)
}

pub fn subscribe_to_topic_merge_updates(
  audit_data: AuditData,
  audit_name audit_name,
  effect effect,
) {
  pcd.subscribe_to_key(audit_data.topic_merges_provider.pcd, audit_name, effect)
}
