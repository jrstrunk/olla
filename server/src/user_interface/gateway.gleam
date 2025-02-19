import gleam/erlang/process
import gleam/list
import gleam/result
import gleam/string
import lib/concurrent_dict
import lib/snagx
import lustre
import o11a/config
import server/discussion
import snag
import user_interface/page

pub type DiscussionGateway =
  concurrent_dict.ConcurrentDict(
    String,
    process.Subject(lustre.Action(page.Msg, lustre.ServerComponent)),
  )

pub fn start_discussion_gateway() -> Result(DiscussionGateway, snag.Snag) {
  config.get_all_audit_file_paths()
  |> list.map(fn(page_path) {
    use preprocessed_source <- result.try(page.preprocess_source(for: page_path))
    use page_notes <- result.try(discussion.get_page_notes(page_path))
    use actor <- result.map(
      lustre.start_actor(
        page.app(),
        page.Model(preprocessed_source:, page_notes:),
      )
      |> snag.map_error(string.inspect),
    )

    #(page_path, actor)
  })
  |> snagx.collect_errors
  |> result.map(concurrent_dict.from_list)
}

pub fn get_page_actor(discussion_gateway: DiscussionGateway, page_path) {
  concurrent_dict.get(discussion_gateway, page_path)
}
