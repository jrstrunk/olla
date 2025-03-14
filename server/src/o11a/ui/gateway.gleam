import concurrent_dict
import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string
import lib/snagx
import lustre
import o11a/audit_metadata
import o11a/config
import o11a/server/audit_metadata as server_audit_metadata
import o11a/server/discussion
import o11a/ui/audit_dashboard
import o11a/ui/audit_page_sol
import o11a/ui/page_dashboard
import simplifile
import snag

pub type Gateway {
  Gateway(
    page_gateway: PageGateway,
    page_dashboard_gateway: PageDashboardGateway,
    dashboard_gateway: DashboardGateway,
    audit_metadata_gateway: AuditMetaDataGateway,
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

pub type AuditMetaDataGateway =
  concurrent_dict.ConcurrentDict(String, audit_metadata.AuditMetaData)

pub fn start_gateway(skeletons) -> Result(Gateway, snag.Snag) {
  let dashboard_gateway = concurrent_dict.new()
  let page_gateway = concurrent_dict.new()
  let page_dashboard_gateway = concurrent_dict.new()
  let audit_metadata_gateway = concurrent_dict.new()

  let page_paths = config.get_all_audit_page_paths()

  use _ <- result.map(
    dict.keys(page_paths)
    |> list.map(fn(audit_name) {
      use audit_metadata <- result.try(
        server_audit_metadata.gather_metadata(for: audit_name)
        |> snag.context("Failed to gather metadata for " <> audit_name),
      )

      concurrent_dict.insert(audit_metadata_gateway, audit_name, audit_metadata)

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

      dict.get(page_paths, audit_name)
      |> result.unwrap([])
      |> list.map(fn(page_path) {
        case audit_page_sol.preprocess_source(for: page_path) {
          Ok(preprocessed_source) -> {
            use actor <- result.try(
              lustre.start_actor(
                audit_page_sol.app(),
                audit_page_sol.Model(
                  page_path:,
                  preprocessed_source:,
                  discussion:,
                  skeletons:,
                ),
              )
              |> snag.map_error(string.inspect),
            )

            concurrent_dict.insert(page_gateway, page_path, actor)

            use dashboard_actor <- result.map(
              lustre.start_actor(
                page_dashboard.app(),
                page_dashboard.Model(discussion:, page_path:, skeletons:),
              )
              |> snag.map_error(string.inspect),
            )

            concurrent_dict.insert(
              page_dashboard_gateway,
              page_path,
              dashboard_actor,
            )
          }

          // If we get a non-text file, just ignore it. Eventually we could 
          // handle image files
          Error(simplifile.NotUtf8) -> Ok(Nil)

          Error(msg) ->
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

pub fn get_audit_metadata(
  audit_metadata_gateway: AuditMetaDataGateway,
  for audit_name,
) {
  concurrent_dict.get(audit_metadata_gateway, audit_name)
  |> result.unwrap(audit_metadata.AuditMetaData(
    audit_name: audit_name,
    audit_formatted_name: audit_name,
    in_scope_files: [],
    source_files: dict.new(),
  ))
}
