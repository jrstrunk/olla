import config
import gleam/erlang/process
import gleam/http/request
import gleam/io
import gleam/result
import gleam/string_tree
import lustre
import mist
import server_component
import simplifile
import snag
import viewer
import wisp
import wisp/wisp_mist

type Context {
  Context(
    viewer_actor: process.Subject(
      lustre.Action(viewer.Msg, lustre.ServerComponent),
    ),
  )
}

pub fn main() {
  io.println("Olla is starting!")

  let config = config.Config(port: 8401)

  use viewer_actor <- result.map(
    lustre.start_actor(viewer.app(), config)
    |> result.replace_error(snag.new("Unable to start viewer actor")),
  )

  let context = Context(viewer_actor:)

  let assert Ok(_) =
    handler(_, context)
    |> mist.new
    |> mist.port(config.port)
    |> mist.bind("0.0.0.0")
    |> mist.start_http

  process.sleep_forever()
}

fn handler(req, context: Context) {
  case request.path_segments(req) {
    ["lustre-server-component.mjs"] -> server_component.serve_lustre_framework()

    ["styles.css"] -> server_component.serve_css("styles.css")

    ["viewer"] -> server_component.render_as_page("viewer-component")

    ["viewer-component"] ->
      server_component.get_connection(req, context.viewer_actor)

    _ -> wisp_mist.handler(handle_wisp_request(_, context), "secret")(req)
  }
}

fn handle_wisp_request(req, _context: Context) {
  case request.path_segments(req) {
    ["view"] ->
      simplifile.read("priv/static/audit.html")
      |> fn(body) {
        let assert Ok(body) = body
        body
      }
      |> string_tree.from_string
      |> wisp.html_response(200)
    _ -> wisp.not_found()
  }
}
