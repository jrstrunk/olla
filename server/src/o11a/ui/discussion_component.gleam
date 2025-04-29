//// This component allows the client to receive the full discussion data over
//// a websocket connection as a server component. The client can then parse
//// the JSON encoded discussion. Eventually this should be replaced with a  
//// direct websocket connection to the server instead of going through this
//// server component, where only updates are streamed instead of the whole
//// discussion every time there is an update.

import gleam/json
import lustre
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/server_component
import o11a/events
import o11a/server/discussion

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(init, update, view, [])
}

pub type Msg {
  ServerUpdatedDiscussion
}

pub type Model {
  Model(
    discussion: discussion.Discussion,
  )
}

pub fn init(init_model: Model) -> #(Model, effect.Effect(Msg)) {
  let subscribe_to_note_updates_effect =
    effect.from(fn(dispatch) {
      discussion.subscribe_to_note_updates(init_model.discussion, fn() {
        dispatch(ServerUpdatedDiscussion)
      })
    })

  #(init_model, subscribe_to_note_updates_effect)
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    ServerUpdatedDiscussion -> {
      echo "Emitting server updated discussion"
      #(
        model,
        server_component.emit(
          events.server_updated_discussion,
          json.object([
            #("audit_name", json.string(model.discussion.audit_name)),
          ]),
        ),
      )
    }
  }
}

fn view(_model: Model) -> element.Element(msg) {
  html.div([], [])
}
