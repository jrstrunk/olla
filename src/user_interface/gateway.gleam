import config
import gleam/erlang/process
import gleam/list
import lib/concurrent_dict
import lustre
import server/discussion
import user_interface/page

pub type DiscussionGateway =
  concurrent_dict.ConcurrentDict(
    String,
    process.Subject(lustre.Action(page.Msg, lustre.ServerComponent)),
  )

pub fn start_discussion_gateway() -> DiscussionGateway {
  config.get_all_audit_file_paths()
  |> list.map(fn(page_path) {
    let assert Ok(page_notes) = discussion.get_page_notes(page_path)
    let assert Ok(actor) =
      lustre.start_actor(page.app(), page.Model(page_notes:))

    #(page_path, actor)
  })
  |> concurrent_dict.from_list
}

pub fn get_page_actor(discussion_gateway: DiscussionGateway, page_path) {
  concurrent_dict.get(discussion_gateway, page_path)
}
