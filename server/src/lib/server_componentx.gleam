import gleam/erlang/process
import gleam/function
import gleam/json
import gleam/option
import gleam/otp/actor
import lustre
import lustre/server_component
import mist

pub fn serve_component_connection(request, component) {
  mist.websocket(
    request:,
    on_init: init_whiteboard_socket(_, component),
    handler: loop_whiteboard_socket,
    on_close: close_whiteboard_socket,
  )
}

type ComponentSocket(msg) {
  ComponentSocket(
    component: lustre.Runtime(msg),
    self: process.Subject(server_component.ClientMessage(msg)),
  )
}

fn init_whiteboard_socket(_, component) {
  let self = process.new_subject()
  let selector =
    process.new_selector()
    |> process.selecting(self, function.identity)

  server_component.register_subject(self)
  |> lustre.send(to: component)

  #(ComponentSocket(component:, self:), option.Some(selector))
}

fn loop_whiteboard_socket(
  state: ComponentSocket(msg),
  connection: mist.WebsocketConnection,
  message,
) {
  case message {
    mist.Text(json) -> {
      case json.parse(json, server_component.runtime_message_decoder()) {
        Ok(runtime_message) -> lustre.send(state.component, runtime_message)
        Error(_) -> Nil
      }

      actor.continue(state)
    }

    mist.Binary(_) -> {
      actor.continue(state)
    }

    mist.Custom(client_message) -> {
      let json = server_component.client_message_to_json(client_message)
      let assert Ok(_) = mist.send_text_frame(connection, json.to_string(json))

      actor.continue(state)
    }

    mist.Closed | mist.Shutdown -> {
      server_component.deregister_subject(state.self)
      |> lustre.send(to: state.component)

      actor.Stop(process.Normal)
    }
  }
}

fn close_whiteboard_socket(state: ComponentSocket(msg)) -> Nil {
  server_component.deregister_subject(state.self)
  |> lustre.send(to: state.component)
}
