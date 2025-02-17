import config
import filepath
import gleam/erlang
import gleam/erlang/process
import gleam/http/request
import gleam/io
import gleam/list
import gleam/string_tree
import lustre/element
import mist
import server_componentx
import simplifile
import user_interface/gateway
import wisp
import wisp/wisp_mist

type Context {
  Context(discussion_gateway: gateway.DiscussionGateway)
}

pub fn main() {
  io.println("o11a is starting!")

  let config = config.Config(port: 8400)

  let context = Context(discussion_gateway: gateway.start_discussion_gateway())

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

    ["component", ..component_path_segments] -> {
      let assert Ok(actor) =
        gateway.get_page_actor(
          context.discussion_gateway,
          list.fold(component_path_segments, "", filepath.join),
        )

      server_componentx.get_connection(req, actor)
    }
    _ -> wisp_mist.handler(handle_wisp_request(_, context), "secret")(req)
  }
}

fn handle_wisp_request(req, _context: Context) {
  case request.path_segments(req) {
    [] ->
      wisp.html_response(
        string_tree.from_string("<h1>Welcome to o11a!</h1>"),
        200,
      )

    ["dashboard"] ->
      wisp.html_response(
        string_tree.from_string("<h1>Welcome to o11a's dashboard!</h1>"),
        200,
      )

    [file_path] -> {
      let assert Ok(priv) = erlang.priv_directory("o11a")

      case
        [priv, "static", "skeleton", file_path <> ".html"]
        |> list.fold("", filepath.join)
        |> simplifile.read
      {
        Ok(skeleton) -> {
          server_componentx.render_with_prerendered_skeleton(
            filepath.join("component", file_path),
            skeleton,
          )
          |> server_componentx.as_document
          |> element.to_string_builder
          |> wisp.html_response(200)
        }

        Error(_) -> wisp.not_found()
      }
    }

    _ -> wisp.not_found()
  }
}
