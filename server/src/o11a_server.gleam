import argv
import concurrent_dict
import filepath
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string_tree
import lib/server_componentx
import lustre/attribute
import lustre/element
import lustre/element/html
import mist
import o11a/config
import o11a/ui/gateway
import snag
import wisp
import wisp/wisp_mist

type Context {
  Context(
    config: config.Config,
    dashboard_gateway: gateway.DashboardGateway,
    page_gateway: gateway.PageGateway,
    page_dashboard_gateway: gateway.PageDashboardGateway,
    audit_metadata_gateway: gateway.AuditMetaDataGateway,
    discussion_component_gateway: gateway.DiscussionComponentGateway,
    source_files: concurrent_dict.ConcurrentDict(String, string_tree.StringTree),
    audit_metadata: concurrent_dict.ConcurrentDict(
      String,
      string_tree.StringTree,
    ),
    skeletons: concurrent_dict.ConcurrentDict(String, String),
  )
}

pub fn main() {
  let config = case argv.load().arguments {
    [] -> config.get_prod_config()
    ["dev"] -> config.get_dev_config()
    _ -> panic as "Unrecognized argument given"
  }

  io.println("o11a is starting!")

  let skeletons = concurrent_dict.new()

  use
    gateway.Gateway(
      dashboard_gateway:,
      page_gateway:,
      page_dashboard_gateway:,
      audit_metadata_gateway:,
      discussion_component_gateway:,
      source_files:,
      audit_metadata:,
    )
  <- result.map(
    gateway.start_gateway(skeletons)
    |> echo
    |> result.map_error(fn(e) { snag.pretty_print(e) |> io.println }),
  )

  let context =
    Context(
      config:,
      dashboard_gateway:,
      page_gateway:,
      page_dashboard_gateway:,
      audit_metadata_gateway:,
      discussion_component_gateway:,
      skeletons:,
      source_files:,
      audit_metadata:,
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
    ["favicon.ico"] -> serve_favicon(context.config)

    ["styles.css" as stylesheet] | ["line_discussion.min.css" as stylesheet] ->
      serve_css(stylesheet, context.config)

    ["lustre_server_component.mjs" as script]
    | ["o11a_client.mjs" as script]
    | ["o11a_client_script.mjs" as script]
    | ["panel_resizer.mjs" as script] -> serve_js(script, context.config)

    ["component-discussion", audit_name] -> {
      let assert Ok(actor) =
        gateway.get_discussion_component_actor(
          context.discussion_component_gateway,
          audit_name,
        )

      server_componentx.get_connection(req, actor)
    }

    // |> wisp.json_response
    _ -> wisp_mist.handler(handle_wisp_request(_, context), "secret")(req)
  }
}

fn handle_wisp_request(req, context: Context) {
  case request.path_segments(req) {
    ["audit-metadata", audit_name] ->
      gateway.get_audit_metadata(context.audit_metadata, for: audit_name)
      // TODO: try_recover to gather metadata from disk
      |> result.unwrap(string_tree.from_string("<p>Metadata not found</p>"))
      |> wisp.json_response(200)

    ["source-file", ..page_path] ->
      gateway.get_source_file(
        context.source_files,
        for: page_path |> list.fold("", filepath.join),
      )
      // TODO: try_recover to get the source file from disk
      |> result.unwrap(string_tree.from_string("<p>Source not found</p>"))
      |> wisp.json_response(200)

    _ -> {
      html.html([], [
        html.head([], [
          html.link([
            attribute.rel("icon"),
            attribute.href(
              "data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🕵️</text></svg>",
            ),
          ]),
          html.script(
            [
              attribute.type_("module"),
              attribute.src("/lustre_server_component.mjs"),
            ],
            "",
          ),
          html.script(
            [attribute.type_("module"), attribute.src("/o11a_client.mjs")],
            "",
          ),
          html.script(
            [
              attribute.type_("module"),
              attribute.src("/o11a_client_script.mjs"),
            ],
            "",
          ),
          html.script(
            [attribute.type_("module"), attribute.src("/panel_resizer.mjs")],
            "",
          ),
          html.link([
            attribute.rel("stylesheet"),
            attribute.href("/line_discussion.min.css"),
          ]),
          html.link([attribute.rel("stylesheet"), attribute.href("/styles.css")]),
        ]),
        html.body([], [html.div([attribute.id("app")], [])]),
      ])
      |> element.to_document_string_builder
      |> wisp.html_response(200)
    }
  }
}

fn serve_css(style_sheet_name, config: config.Config) {
  let path = config.get_priv_path(for: "static/" <> style_sheet_name)
  let assert Ok(css) = mist.send_file(path, offset: 0, limit: None)

  response.new(200)
  |> response.prepend_header("content-type", "text/css")
  |> response.set_body(css)
  |> fn(resp) {
    case config.env {
      config.Prod ->
        resp
        |> response.set_header(
          "cache-control",
          "max-age=604800, must-revalidate",
        )
      config.Dev -> resp
    }
  }
}

fn serve_js(js_file_name, config: config.Config) {
  let path = config.get_priv_path(for: "static/" <> js_file_name)
  let assert Ok(js) = mist.send_file(path, offset: 0, limit: None)

  response.new(200)
  |> response.prepend_header("content-type", "text/javascript")
  |> response.set_body(js)
  |> fn(resp) {
    case config.env {
      config.Prod ->
        resp
        |> response.set_header(
          "cache-control",
          "max-age=604800, must-revalidate",
        )
      config.Dev -> resp
    }
  }
}

fn serve_favicon(config: config.Config) {
  let path = config.get_priv_path(for: "static/favicon.ico")
  let assert Ok(favicon) = mist.send_file(path, offset: 0, limit: None)

  response.new(200)
  |> response.prepend_header("content-type", "image/x-icon")
  |> response.set_body(favicon)
  |> response.set_header("cache-control", "max-age=604800, must-revalidate")
}
