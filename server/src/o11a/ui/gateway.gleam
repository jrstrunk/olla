import concurrent_dict
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import lib/snagx
import lustre
import o11a/config
import o11a/server/audit_data
import o11a/server/discussion
import o11a/ui/discussion_component
import snag

pub type Gateway {
  Gateway(
    discussion_component_gateway: DiscussionComponentGateway,
    discussion_gateway: concurrent_dict.ConcurrentDict(
      String,
      discussion.Discussion,
    ),
    audit_data: audit_data.AuditData,
  )
}

pub type DiscussionComponentGateway =
  concurrent_dict.ConcurrentDict(
    String,
    lustre.Runtime(discussion_component.Msg),
  )

pub fn start_gateway() -> Result(Gateway, snag.Snag) {
  let discussion_gateway = concurrent_dict.new()

  let discussion_component_gateway = concurrent_dict.new()

  use audit_data <- result.try(
    audit_data.build()
    |> snag.context("Failed to build audit data"),
  )

  let page_paths = config.get_all_audit_page_paths()

  use _ <- result.map(
    dict.keys(page_paths)
    |> list.map(fn(audit_name) {
      use discussion <- result.try(discussion.build_audit_discussion(audit_name))

      concurrent_dict.insert(discussion_gateway, audit_name, discussion)

      use discussion_component_actor <- result.map(
        lustre.start_server_component(discussion_component.app(), #(
          discussion,
          audit_data,
        ))
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

  Gateway(discussion_gateway:, discussion_component_gateway:, audit_data:)
}

pub fn get_discussion_component_actor(
  discussion_component_gateway: DiscussionComponentGateway,
  for audit_name,
) {
  concurrent_dict.get(discussion_component_gateway, audit_name)
}

pub fn get_discussion(discussion_gateway, for audit_name) {
  concurrent_dict.get(discussion_gateway, audit_name)
}
