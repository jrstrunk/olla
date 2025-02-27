import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string
import lib/concurrent_dict
import lib/snagx
import lustre
import o11a/config
import o11a/server/discussion
import o11a/user_interface/audit_dashboard
import o11a/user_interface/audit_page
import snag

pub type PageGateway =
  concurrent_dict.ConcurrentDict(
    String,
    process.Subject(lustre.Action(audit_page.Msg, lustre.ServerComponent)),
  )

pub type DashboardGateway =
  concurrent_dict.ConcurrentDict(
    String,
    process.Subject(lustre.Action(audit_dashboard.Msg, lustre.ServerComponent)),
  )

pub fn start_discussion_gateway() -> Result(
  #(DashboardGateway, PageGateway),
  snag.Snag,
) {
  let dashboard_actors = concurrent_dict.new()
  let page_actors = concurrent_dict.new()

  let page_paths = config.get_all_audit_page_paths()

  use _ <- result.map(
    dict.keys(page_paths)
    |> list.map(fn(audit_name) {
      use discussion <- result.try(discussion.get_audit_discussion(audit_name))

      use audit_dashboard_actor <- result.try(
        lustre.start_actor(
          audit_dashboard.app(),
          audit_dashboard.Model(discussion:),
        )
        |> snag.map_error(string.inspect),
      )

      concurrent_dict.insert(
        dashboard_actors,
        audit_name,
        audit_dashboard_actor,
      )

      dict.get(page_paths, audit_name)
      |> result.unwrap([])
      |> list.map(fn(page_path) {
        use preprocessed_source <- result.try(audit_page.preprocess_source(
          for: page_path,
        ))
        use actor <- result.map(
          lustre.start_actor(
            audit_page.app(),
            audit_page.Model(page_path:, preprocessed_source:, discussion:),
          )
          |> snag.map_error(string.inspect),
        )

        concurrent_dict.insert(page_actors, page_path, actor)
      })
      |> snagx.collect_errors
    })
    |> snagx.collect_errors
    |> result.map(list.flatten),
  )

  #(dashboard_actors, page_actors)
}

pub fn get_page_actor(discussion_gateway: PageGateway, page_path) {
  concurrent_dict.get(discussion_gateway, page_path)
}

pub fn get_dashboard_actor(discussion_gateway: DashboardGateway, audit_name) {
  concurrent_dict.get(discussion_gateway, audit_name)
}
