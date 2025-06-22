//// This component allows the client to receive the full discussion data over
//// a websocket connection as a server component. The client can then parse
//// the JSON encoded discussion. Eventually this should be replaced with a  
//// direct websocket connection to the server instead of going through this
//// server component, where only updates are streamed instead of the whole
//// discussion every time there is an update.

import concurrent_dict
import gleam/json
import lib/persistent_concurrent_structured_dict as pcs_dict
import lustre
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/server_component
import o11a/events
import o11a/note
import o11a/server/discussion
import o11a/topic

pub fn app() -> lustre.App(
  #(
    String,
    pcs_dict.PersistentConcurrentStructuredDict(
      String,
      note.NoteSubmission,
      note.Note,
      String,
      List(note.NoteStub),
    ),
    concurrent_dict.ConcurrentDict(String, topic.Topic),
  ),
  Model,
  Msg,
) {
  lustre.component(init, update, view, [])
}

pub type Msg {
  ServerUpdatedDiscussion
  ServerUpdatedTopics
}

pub type Model {
  Model(audit_name: String)
}

pub fn init(init_flags) {
  let #(audit_name, discussion, topics) = init_flags

  let subscribe_to_note_updates_effect =
    effect.from(fn(dispatch) {
      discussion.subscribe_to_note_updates(discussion, fn() {
        dispatch(ServerUpdatedDiscussion)
      })
    })

  let subscribe_to_topic_updates_effect =
    effect.from(fn(dispatch) {
      let assert Ok(Nil) =
        concurrent_dict.subscribe(topics, fn() { dispatch(ServerUpdatedTopics) })
      Nil
    })

  #(
    Model(audit_name:),
    effect.batch([
      subscribe_to_note_updates_effect,
      subscribe_to_topic_updates_effect,
    ]),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    ServerUpdatedDiscussion -> {
      echo "Emitting server updated discussion"
      #(
        model,
        server_component.emit(
          events.server_updated_discussion,
          json.object([#("audit_name", json.string(model.audit_name))]),
        ),
      )
    }
    ServerUpdatedTopics -> {
      echo "Emitting server updated topics"
      #(
        model,
        server_component.emit(
          events.server_updated_topics,
          json.object([#("audit_name", json.string(model.audit_name))]),
        ),
      )
    }
  }
}

fn view(_model: Model) -> element.Element(msg) {
  html.div([], [])
}
