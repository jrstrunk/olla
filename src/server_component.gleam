import gleam/bytes_tree
import gleam/erlang
import gleam/erlang/process
import gleam/http/response
import gleam/int
import gleam/json
import gleam/option.{None}
import gleam/otp/actor
import lustre
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/server_component
import mist

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

pub fn socket_init(
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

pub fn socket_update(
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

pub fn socket_close(state: ServerComponentState(msg)) {
  process.send(
    state.server_component_actor,
    server_component.unsubscribe(state.connection_id),
  )
}

pub fn render_as_page(component name: String) {
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(
    html.html([], [
      html.head([], [
        html.link([attribute.rel("stylesheet"), attribute.href("/styles.css")]),
        html.script(
          [
            attribute.type_("module"),
            attribute.src("/lustre-server-component.mjs"),
          ],
          "",
        ),
      ]),
      html.body([], [
        server_component.component([server_component.route("/" <> name)]),
      ]),
    ])
    |> element.to_document_string_builder
    |> bytes_tree.from_string_tree
    |> mist.Bytes,
  )
}

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

pub fn serve_lustre_framework() {
  let assert Ok(priv) = erlang.priv_directory("lustre")
  let path = priv <> "/static/lustre-server-component.mjs"
  let assert Ok(script) = mist.send_file(path, offset: 0, limit: None)

  response.new(200)
  |> response.prepend_header("content-type", "application/javascript")
  |> response.set_body(script)
}

pub fn serve_css(style_sheet_name) {
  let assert Ok(priv) = erlang.priv_directory("olla")
  let path = priv <> "/static/" <> style_sheet_name
  let assert Ok(css) = mist.send_file(path, offset: 0, limit: None)

  response.new(200)
  |> response.prepend_header("content-type", "text/css")
  |> response.set_body(css)
}
