import gleam/erlang/process
import server/discussion

pub type Config {
  Config(
    port: Int,
    discussion_gateway: process.Subject(discussion.DiscussionGatewayMsg),
  )
}
