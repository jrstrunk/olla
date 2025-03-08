import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/option
import gleam/otp/actor
import lustre
import lustre/server_component
import mist

pub fn get_connection(
  request,
  actor: process.Subject(lustre.Action(msg, lustre.ServerComponent)),
) {
  mist.websocket(
    request:,
    on_init: socket_init(_, actor),
    on_close: socket_close,
    handler: socket_update,
  )
}

pub type ServerComponentState(msg) {
  ServerComponentState(
    server_component_actor: process.Subject(
      lustre.Action(msg, lustre.ServerComponent),
    ),
    connection_id: String,
  )
}

pub type ServerComponentActor(msg) =
  process.Subject(lustre.Action(msg, lustre.ServerComponent))

fn socket_init(
  _conn: mist.WebsocketConnection,
  server_component_actor: ServerComponentActor(msg),
) -> #(
  ServerComponentState(msg),
  option.Option(process.Selector(lustre.Patch(msg))),
) {
  let self = process.new_subject()
  let selector = process.selecting(process.new_selector(), self, fn(a) { a })

  let connection_id = int.random(1_000_000) |> int.to_string

  process.send(
    server_component_actor,
    server_component.subscribe(connection_id, process.send(self, _)),
  )

  #(
    ServerComponentState(server_component_actor:, connection_id:),
    option.Some(selector),
  )
}

fn socket_update(
  state: ServerComponentState(msg),
  conn: mist.WebsocketConnection,
  msg: mist.WebsocketMessage(lustre.Patch(msg)),
) {
  case msg {
    mist.Text(json) -> {
      // we attempt to decode the incoming text as an action to send to our
      // server component runtime.
      let action = json.decode(json, server_component.decode_action)

      case action {
        Ok(action) -> process.send(state.server_component_actor, action)
        Error(_) -> Nil
      }

      actor.continue(state)
    }

    mist.Binary(_) -> actor.continue(state)
    mist.Custom(patch) -> {
      let assert Ok(_) =
        patch
        |> server_component.encode_patch
        |> json.to_string
        |> mist.send_text_frame(conn, _)

      actor.continue(state)
    }
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
  }
}

fn socket_close(state: ServerComponentState(msg)) {
  process.send(
    state.server_component_actor,
    server_component.unsubscribe(state.connection_id),
  )
}
