import filepath
import gleam/erlang/process
import gleam/http/request
import gleam/io
import gleam/list
import gleam/result
import gleam/string_tree
import lib/server_componentx
import lustre/element
import mist
import o11a/config
import o11a/user_interface/audit_dashboard
import o11a/user_interface/audit_doc
import o11a/user_interface/audit_page
import o11a/user_interface/audit_tree
import o11a/user_interface/gateway
import simplifile
import snag
import wisp
import wisp/wisp_mist

type Context {
  Context(
    dashboard_gateway: gateway.DashboardGateway,
    page_gateway: gateway.PageGateway,
    discussion_gateway: gateway.DiscussionGateway,
    audit_metadata_gateway: gateway.AuditMetaDataGateway,
  )
}

pub fn main() {
  io.println("o11a is starting!")

  let config = config.Config(port: 8401)

  use
    gateway.Gateway(
      dashboard_gateway:,
      page_gateway:,
      discussion_gateway:,
      audit_metadata_gateway:,
    )
  <- result.map(gateway.start_gateway())

  let context =
    Context(
      dashboard_gateway:,
      page_gateway:,
      discussion_gateway:,
      audit_metadata_gateway:,
    )

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
    ["lustre-server-component.mjs"] ->
      server_componentx.serve_lustre_framework()

    ["styles.css"] -> server_componentx.serve_css("styles.css")

    ["line_notes.mjs"] -> server_componentx.serve_js("line_notes.mjs")

    ["component-page", ..component_path_segments] -> {
      let assert Ok(actor) =
        gateway.get_page_actor(
          context.page_gateway,
          list.fold(component_path_segments, "", filepath.join),
        )

      server_componentx.get_connection(req, actor)
    }

    ["component-dashboard", audit_name] -> {
      let assert Ok(actor) =
        gateway.get_dashboard_actor(context.dashboard_gateway, audit_name)

      server_componentx.get_connection(req, actor)
    }

    _ -> wisp_mist.handler(handle_wisp_request(_, context), "secret")(req)
  }
}

fn handle_wisp_request(req, context: Context) {
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

    [audit_name, "dashboard"] ->
      gateway.get_discussion(context.discussion_gateway, for: audit_name)
      |> audit_dashboard.get_skeleton
      |> server_componentx.render_with_skeleton(
        filepath.join("component-dashboard", audit_name),
        _,
      )
      |> audit_tree.view(audit_name, with: context.audit_metadata_gateway)
      |> server_componentx.as_document
      |> element.to_document_string_builder
      |> wisp.html_response(200)

    [audit_name, readme] if readme == "readme.md" || readme == "README.md" ->
      case
        config.get_audit_path(for: audit_name)
        |> filepath.join(readme)
        |> simplifile.read
        |> snag.map_error(simplifile.describe_error)
      {
        Ok(contents) ->
          audit_doc.view(contents)
          |> audit_tree.view(audit_name, with: context.audit_metadata_gateway)
          |> server_componentx.as_static_document
          |> element.to_document_string_builder
          |> wisp.html_response(200)

        Error(snag) ->
          snag.pretty_print(snag)
          |> string_tree.from_string
          |> wisp.html_response(500)
      }

    [audit_name, ..] as file_path_segments -> {
      let file_path = list.fold(file_path_segments, "", filepath.join)

      case audit_page.get_skeleton(for: file_path) {
        Ok(skeleton) -> {
          server_componentx.render_with_prerendered_skeleton(
            filepath.join("component-page", file_path),
            skeleton,
          )
          |> audit_tree.view(audit_name, with: context.audit_metadata_gateway)
          |> server_componentx.as_document
          |> element.to_document_string_builder
          |> wisp.html_response(200)
        }

        Error(snag) ->
          snag.pretty_print(snag)
          |> string_tree.from_string
          |> wisp.html_response(500)
      }
    }
  }
}
