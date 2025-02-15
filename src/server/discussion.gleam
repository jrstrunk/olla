import gleam/dict
import gleam/erlang/process
import gleam/option.{type Option}
import gleam/otp/actor
import tempo

pub type Discussion {
  Discussion(
    id: String,
    comments: List(Note),
    invariants: List(Note),
    tests: List(Note),
  )
}

pub type DiscussionMsg {
  AddComment(discussion_id: String, comment: Note)
  AddInvariant(discussion_id: String, invariant: Note)
  AddTest(discussion_id: String, new_test: Note)
  GetDiscussion(reply: process.Subject(Discussion))
}

pub fn add_discussion_comment(discussion: Discussion, comment: Note) {
  Discussion(..discussion, comments: [comment, ..discussion.comments])
}

pub fn add_discussion_invariant(discussion: Discussion, invariant: Note) {
  Discussion(..discussion, invariants: [invariant, ..discussion.invariants])
}

pub fn add_discussion_test(discussion: Discussion, new_test: Note) {
  Discussion(..discussion, tests: [new_test, ..discussion.tests])
}

pub type Thread {
  Thread(id: String, comments: List(Note))
}

pub fn add_thread_comment(thread: Thread, comment: Note) {
  Thread(..thread, comments: [comment, ..thread.comments])
}

pub type Note {
  Note(
    user_id: String,
    title: String,
    body: String,
    votes: Int,
    time: tempo.DateTime,
    thread_id: Option(String),
  )
}

// Each page has a separate actor that contains all the discussions on that page
pub type DiscussionGateway =
  process.Subject(DiscussionGatewayMsg)

pub type DiscussionGatewayState {
  DiscussionGatewayState(discussions: PageDiscussions)
}

pub type PageDiscussions =
  dict.Dict(String, Discussion)

pub type DiscussionGatewayMsg {
  GetDiscussions(page_id: String, reply: process.Subject(PageDiscussions))
}
