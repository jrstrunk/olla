import gleam/bytes_tree
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
import o11a/config

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

pub fn render_with_skeleton(name: String, skeleton: element.Element(msg)) {
  element.element(
    "lustre-server-component",
    [server_component.route("/" <> name)],
    [html.div([attribute.attribute("slot", "skeleton")], [skeleton])],
  )
}

pub fn render_with_prerendered_skeleton(name: String, skeleton: String) {
  element.element(
    "lustre-server-component",
    [server_component.route("/" <> name)],
    [
      html.div(
        [
          attribute.attribute("slot", "skeleton"),
          attribute.attribute("dangerous-unescaped-html", skeleton),
        ],
        [],
      ),
    ],
  )
}

pub fn hide_skeleton() {
  html.slot([
    attribute.name("skeleton"),
    attribute.style([#("display", "none")]),
  ])
}

pub fn as_document(body: element.Element(msg)) {
  html.html([], [
    html.head([], [
      html.link([attribute.rel("stylesheet"), attribute.href("/styles.css")]),
      html.script(
        [attribute.type_("module"), attribute.src("/line_discussion.mjs")],
        "",
      ),
      html.script(
        [
          attribute.type_("module"),
          attribute.src("/lustre-server-component.mjs"),
        ],
        "",
      ),
    ]),
    html.body([], [body]),
  ])
}

/// Returns the given element as a document, but without the lustre server
/// component script tag
pub fn as_static_document(body: element.Element(msg)) {
  html.html([], [
    html.head([], [
      html.link([attribute.rel("stylesheet"), attribute.href("/styles.css")]),
    ]),
    html.body([], [body]),
  ])
}

pub fn html_response(html: element.Element(msg)) {
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(
    html
    |> element.to_document_string_builder
    |> bytes_tree.from_string_tree
    |> mist.Bytes,
  )
}

pub fn render_as_page(component name: String) {
  as_document(server_component.component([server_component.route("/" <> name)]))
  |> html_response
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
  let path = config.get_priv_path(for: "static/lustre_server_component.mjs")
  let assert Ok(script) = mist.send_file(path, offset: 0, limit: None)

  process.sleep(1000)

  response.new(200)
  |> response.prepend_header("content-type", "application/javascript")
  |> response.set_body(script)
}

pub fn serve_css(style_sheet_name) {
  let path = config.get_priv_path(for: "static/" <> style_sheet_name)
  let assert Ok(css) = mist.send_file(path, offset: 0, limit: None)

  response.new(200)
  |> response.prepend_header("content-type", "text/css")
  |> response.set_body(css)
}

pub fn serve_js(js_file_name) {
  let path = config.get_priv_path(for: "static/" <> js_file_name)
  let assert Ok(js) = mist.send_file(path, offset: 0, limit: None)

  response.new(200)
  |> response.prepend_header("content-type", "text/javascript")
  |> response.set_body(js)
}
