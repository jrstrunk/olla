import concurrent_dict
import gleam/dict
import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/string_tree
import lib/snagx
import lustre
import o11a/audit_metadata
import o11a/config
import o11a/preprocessor
import o11a/server/audit_metadata as server_audit_metadata
import o11a/server/discussion
import o11a/server/preprocessor_sol
import o11a/ui/audit_dashboard
import o11a/ui/audit_page_sol
import o11a/ui/discussion_component
import o11a/ui/page_dashboard
import simplifile
import snag

pub type Gateway {
  Gateway(
    page_gateway: PageGateway,
    page_dashboard_gateway: PageDashboardGateway,
    dashboard_gateway: DashboardGateway,
    audit_metadata_gateway: AuditMetaDataGateway,
    discussion_component_gateway: DiscussionComponentGateway,
    source_files: concurrent_dict.ConcurrentDict(String, string_tree.StringTree),
    audit_metadata: concurrent_dict.ConcurrentDict(
      String,
      string_tree.StringTree,
    ),
  )
}

pub type PageGateway =
  concurrent_dict.ConcurrentDict(
    String,
    process.Subject(lustre.Action(audit_page_sol.Msg, lustre.ServerComponent)),
  )

pub type PageDashboardGateway =
  concurrent_dict.ConcurrentDict(
    String,
    process.Subject(lustre.Action(page_dashboard.Msg, lustre.ServerComponent)),
  )

pub type DashboardGateway =
  concurrent_dict.ConcurrentDict(
    String,
    process.Subject(lustre.Action(audit_dashboard.Msg, lustre.ServerComponent)),
  )

pub type DiscussionComponentGateway =
  concurrent_dict.ConcurrentDict(
    String,
    process.Subject(
      lustre.Action(discussion_component.Msg, lustre.ServerComponent),
    ),
  )

pub type AuditMetaDataGateway =
  concurrent_dict.ConcurrentDict(String, audit_metadata.AuditMetaData)

pub fn start_gateway(skeletons) -> Result(Gateway, snag.Snag) {
  let dashboard_gateway = concurrent_dict.new()
  let page_gateway = concurrent_dict.new()
  let page_dashboard_gateway = concurrent_dict.new()
  let audit_metadata_gateway = concurrent_dict.new()

  let discussion_component_gateway = concurrent_dict.new()
  let source_files = concurrent_dict.new()
  let audit_metadatas = concurrent_dict.new()

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

      use audit_dashboard_actor <- result.try(
        lustre.start_actor(
          audit_dashboard.app(),
          audit_dashboard.Model(discussion:, skeletons:),
        )
        |> snag.map_error(string.inspect),
      )

      concurrent_dict.insert(
        dashboard_gateway,
        audit_name,
        audit_dashboard_actor,
      )

      use discussion_component_actor <- result.try(
        lustre.start_actor(
          discussion_component.app(),
          discussion_component.Model(discussion:, skeletons:),
        )
        |> snag.map_error(string.inspect),
      )

      concurrent_dict.insert(
        discussion_component_gateway,
        audit_name,
        discussion_component_actor,
      )

      use asts <- result.try(
        preprocessor_sol.read_asts(audit_name)
        |> snag.context("Unable to read asts for " <> audit_name),
      )

      let file_to_ast = dict.from_list(asts)

      let declarations =
        dict.new()
        |> list.fold(asts, _, fn(declarations, ast) {
          preprocessor_sol.enumerate_declarations(declarations, ast.1)
        })
        |> list.fold(asts, _, fn(declarations, ast) {
          preprocessor_sol.count_references(declarations, ast.1)
        })

      dict.get(page_paths, audit_name)
      |> result.unwrap([])
      |> list.map(fn(page_path) {
        case
          config.get_full_page_path(for: page_path)
          |> simplifile.read,
          dict.get(file_to_ast, page_path)
        {
          Ok(source), Ok(nodes) -> {
            let nodes = preprocessor_sol.linearize_nodes(nodes)

            let preprocessed_source_json =
              preprocessor_sol.preprocess_source(
                source:,
                nodes:,
                declarations:,
                page_path:,
                audit_name:,
              )
              |> json.array(preprocessor.encode_pre_processed_line)
              |> json.to_string_tree

            concurrent_dict.insert(
              source_files,
              page_path,
              preprocessed_source_json,
            )

            Ok(Nil)
          }

          Ok(_source), Error(Nil) -> Ok(Nil)

          // If we get a non-text file, just ignore it. Eventually we could 
          // handle image files
          Error(simplifile.NotUtf8), _ -> Ok(Nil)

          Error(msg), _ ->
            snag.error(msg |> simplifile.describe_error)
            |> snag.context(
              "Failed to preprocess page source for " <> page_path,
            )
        }
      })
      |> snagx.collect_errors
    })
    |> snagx.collect_errors
    |> result.map(list.flatten),
  )

  Gateway(
    dashboard_gateway:,
    page_gateway:,
    page_dashboard_gateway:,
    audit_metadata_gateway:,
    discussion_component_gateway:,
    source_files:,
    audit_metadata: audit_metadatas,
  )
}

pub fn get_page_actor(discussion_gateway: PageGateway, for page_path) {
  concurrent_dict.get(discussion_gateway, page_path)
}

pub fn get_page_dashboard_actor(
  page_dashboard_gateway: PageDashboardGateway,
  for page_path,
) {
  concurrent_dict.get(page_dashboard_gateway, page_path)
}

pub fn get_dashboard_actor(discussion_gateway: DashboardGateway, for audit_name) {
  concurrent_dict.get(discussion_gateway, audit_name)
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

pub fn get_source_file(source_files, for page_path) {
  concurrent_dict.get(source_files, page_path)
}

pub fn get_audit_metadata(audit_metadata, for audit_name) {
  concurrent_dict.get(audit_metadata, audit_name)
}
