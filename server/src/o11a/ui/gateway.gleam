import concurrent_dict
import gleam/dict
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree
import lib/snagx
import lustre
import o11a/audit_metadata
import o11a/config
import o11a/server/audit_metadata as server_audit_metadata
import o11a/server/audit_source_files
import o11a/server/discussion
import o11a/ui/discussion_component
import snag

pub type Gateway {
  Gateway(
    audit_metadata_gateway: AuditMetaDataGateway,
    discussion_component_gateway: DiscussionComponentGateway,
    discussion_gateway: concurrent_dict.ConcurrentDict(
      String,
      discussion.Discussion,
    ),
    source_files: audit_source_files.AuditSourceFiles,
    audit_metadata: concurrent_dict.ConcurrentDict(
      String,
      string_tree.StringTree,
    ),
  )
}

pub type DiscussionComponentGateway =
  concurrent_dict.ConcurrentDict(
    String,
    lustre.Runtime(discussion_component.Msg),
  )

pub type AuditMetaDataGateway =
  concurrent_dict.ConcurrentDict(String, audit_metadata.AuditMetaData)

pub fn start_gateway() -> Result(Gateway, snag.Snag) {
  let audit_metadata_gateway = concurrent_dict.new()
  let discussion_gateway = concurrent_dict.new()

  let discussion_component_gateway = concurrent_dict.new()
  let audit_metadatas = concurrent_dict.new()

  use source_files <- result.try(
    audit_source_files.build()
    |> snag.context("Failed to build source files"),
  )

  let page_paths = config.get_all_audit_page_paths()

  use _ <- result.map(
    dict.keys(page_paths)
    |> list.map(fn(audit_name) {
      use audit_metadata <- result.try(
        server_audit_metadata.gather_metadata(for: audit_name)
        |> snag.context("Failed to gather metadata for " <> audit_name),
      )

      concurrent_dict.insert(audit_metadata_gateway, audit_name, audit_metadata)

      audit_metadata
      |> audit_metadata.encode_audit_metadata
      |> json.to_string_tree
      |> concurrent_dict.insert(audit_metadatas, audit_name, _)

      use discussion <- result.try(discussion.build_audit_discussion(audit_name))

      concurrent_dict.insert(discussion_gateway, audit_name, discussion)

      use discussion_component_actor <- result.map(
        lustre.start_server_component(
          discussion_component.app(),
          discussion_component.Model(discussion:),
        )
        |> snag.map_error(string.inspect),
      )

      concurrent_dict.insert(
        discussion_component_gateway,
        audit_name,
        discussion_component_actor,
      )
    })
    |> snagx.collect_errors,
  )

  Gateway(
    audit_metadata_gateway:,
    discussion_gateway:,
    discussion_component_gateway:,
    source_files:,
    audit_metadata: audit_metadatas,
  )
}

pub fn get_audit_metadata_gateway(
  audit_metadata_gateway: AuditMetaDataGateway,
  for audit_name,
) {
  concurrent_dict.get(audit_metadata_gateway, audit_name)
  |> result.unwrap(
    audit_metadata.AuditMetaData(
      audit_name: audit_name,
      audit_formatted_name: audit_name,
      in_scope_files: [],
    ),
  )
}

pub fn get_discussion_component_actor(
  discussion_component_gateway: DiscussionComponentGateway,
  for audit_name,
) {
  concurrent_dict.get(discussion_component_gateway, audit_name)
}

pub fn get_audit_metadata(audit_metadata, for audit_name) {
  concurrent_dict.get(audit_metadata, audit_name)
}

pub fn get_discussion(discussion_gateway, for audit_name) {
  concurrent_dict.get(discussion_gateway, audit_name)
}
