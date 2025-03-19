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
import o11a/server/preprocessor_sol
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
        echo "Reading page " <> page_path
        case
          config.get_full_page_path(for: page_path)
          |> simplifile.read,
          dict.get(file_to_ast, page_path)
        {
          Ok(source), Ok(nodes) -> {
            echo "Linearizing nodes for " <> page_path

            let nodes = preprocessor_sol.linearize_nodes(nodes)

            echo "Preprocessing source for " <> page_path

            let preprocessed_source =
              preprocessor_sol.preprocess_source(
                source:,
                nodes:,
                declarations:,
                page_path:,
                audit_name:,
              )

            echo "Starting page actor"

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

            echo "Started page actor"

            concurrent_dict.insert(page_gateway, page_path, actor)

            use dashboard_actor <- result.map(
              lustre.start_actor(
                page_dashboard.app(),
                page_dashboard.Model(discussion:, page_path:, skeletons:),
              )
              |> snag.map_error(string.inspect),
            )

            echo "Started dashboard actor"

            concurrent_dict.insert(
              page_dashboard_gateway,
              page_path,
              dashboard_actor,
            )
          }

          Ok(_source), Error(Nil) -> {
            echo "Failed to read ast for " <> page_path <> ", skipping"
            Ok(Nil)
          }

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
    source_files_sol: dict.new(),
  ))
}
