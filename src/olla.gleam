import config
import gleam/erlang/process
import gleam/http/request
import gleam/io
import gleam/result
import lustre
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/server_component
import mist
import server_componentx
import snag
import user_interface/discussion
import viewer
import wisp
import wisp/wisp_mist

type Context {
  Context(
    viewer_actor: process.Subject(
      lustre.Action(viewer.Msg, lustre.ServerComponent),
    ),
    discussion_actor: process.Subject(
      lustre.Action(discussion.Msg, lustre.ServerComponent),
    ),
  )
}

pub fn main() {
  io.println("O11a is starting!")

  let config =
    config.Config(port: 8401, discussion_gateway: process.new_subject())

  use viewer_actor <- result.map(
    lustre.start_actor(viewer.app(), config)
    |> result.replace_error(snag.new("Unable to start viewer actor")),
  )
  use discussion_actor <- result.map(
    lustre.start_actor(discussion.app(), #("page1", config))
    |> result.replace_error(snag.new("Unable to start discussion actor")),
  )

  let context = Context(viewer_actor:, discussion_actor:)

  let assert Ok(_) =
    handler(_, context)
    |> mist.new
    |> mist.port(config.port)
    |> mist.bind("0.0.0.0")
    |> mist.start_http

  process.sleep_forever()
}

fn handler(req, context: Context) {
  io.debug("Handling request")
  case request.path_segments(req) {
    ["lustre-server-component.mjs"] ->
      server_componentx.serve_lustre_framework()

    ["styles.css"] -> server_componentx.serve_css("styles.css")

    ["viewer"] ->
      server_componentx.as_document(
        server_component.component([server_component.route("/viewer-component")]),
      )
      |> server_componentx.html_response

    ["viewer-component"] ->
      server_componentx.get_connection(req, context.viewer_actor)

    ["discussion-component"] ->
      server_componentx.get_connection(req, context.discussion_actor)

    _ -> wisp_mist.handler(handle_wisp_request(_, context), "secret")(req)
  }
}

fn handle_wisp_request(req, _context: Context) {
  case request.path_segments(req) {
    ["view"] ->
      server_componentx.render_with_skeleton(
        "discussion-component",
        html.div([attribute.attribute("slot", "skeleton")], [
          discussion.skeleton(),
        ]),
      )
      |> server_componentx.as_document
      |> element.to_string_builder
      |> wisp.html_response(200)

    _ -> wisp.not_found()
  }
}
