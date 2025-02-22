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
import o11a/user_interface/page
import snag

pub type DiscussionGateway =
  concurrent_dict.ConcurrentDict(
    String,
    process.Subject(lustre.Action(page.Msg, lustre.ServerComponent)),
  )

pub fn start_discussion_gateway() -> Result(DiscussionGateway, snag.Snag) {
  let page_paths = config.get_all_audit_page_paths()

  dict.keys(page_paths)
  |> list.map(fn(audit_name) {
    use discussion <- result.try(discussion.get_audit_discussion(audit_name))

    dict.get(page_paths, audit_name)
    |> result.unwrap([])
    |> list.map(fn(page_path) {
      use preprocessed_source <- result.try(page.preprocess_source(
        for: page_path,
      ))
      use actor <- result.map(
        lustre.start_actor(
          page.app(),
          page.Model(page_path:, preprocessed_source:, discussion:),
        )
        |> snag.map_error(string.inspect),
      )
      #(page_path, actor)
    })
    |> snagx.collect_errors
  })
  |> snagx.collect_errors
  |> result.map(list.flatten)
  |> result.map(concurrent_dict.from_list)
}

pub fn get_page_actor(discussion_gateway: DiscussionGateway, page_path) {
  concurrent_dict.get(discussion_gateway, page_path)
}
