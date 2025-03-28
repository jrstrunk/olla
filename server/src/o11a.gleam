import argv
import concurrent_dict
import filepath
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string_tree
import lib/elementx
import lib/server_componentx
import lustre/attribute
import lustre/element
import lustre/element/html
import mist
import o11a/components
import o11a/config
import o11a/ui/audit_dashboard
import o11a/ui/audit_doc
import o11a/ui/audit_page_sol
import o11a/ui/audit_tree
import o11a/ui/gateway
import o11a/ui/page_dashboard
import simplifile
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
      skeletons:,
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
    ["lustre-server-component.mjs"] -> serve_lustre_framework()

    ["favicon.ico"] -> serve_favicon(context.config)

    ["styles.css" as stylesheet]
    | ["line_discussion.min.css" as stylesheet]
    | ["page_panel.css" as stylesheet] -> serve_css(stylesheet, context.config)

    ["line_discussion.min.mjs" as script]
    | ["page_navigation.mjs" as script]
    | ["panel_resizer.mjs" as script]
    | ["client.mjs" as script]
    | ["page_panel.mjs" as script] -> serve_js(script, context.config)

    ["component-page", ..component_path_segments] -> {
      let assert Ok(actor) =
        gateway.get_page_actor(
          context.page_gateway,
          list.fold(component_path_segments, "", filepath.join),
        )

      server_componentx.get_connection(req, actor)
    }

    ["component-page-dashboard", ..component_path_segments] -> {
      let assert Ok(actor) =
        gateway.get_page_dashboard_actor(
          context.page_dashboard_gateway,
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
      audit_dashboard.get_skeleton(context.skeletons, for: audit_name)
      |> elementx.server_component_with_prerendered_skeleton(
        filepath.join("component-dashboard", audit_name),
        components.audit_dashboard,
        _,
      )
      |> audit_tree.view(
        None,
        audit_name,
        on: audit_name <> "/dashboard",
        with: gateway.get_audit_metadata(
          context.audit_metadata_gateway,
          audit_name,
        ).in_scope_files,
      )
      |> as_document
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
          |> audit_tree.view(
            None,
            audit_name,
            on: audit_name <> "/" <> readme,
            with: gateway.get_audit_metadata(
              context.audit_metadata_gateway,
              audit_name,
            ).in_scope_files,
          )
          |> as_static_document
          |> element.to_document_string_builder
          |> wisp.html_response(200)

        Error(snag) ->
          snag.pretty_print(snag)
          |> string_tree.from_string
          |> wisp.html_response(500)
      }

    [audit_name, ..] as file_path_segments -> {
      let file_path = list.fold(file_path_segments, "", filepath.join)

      elementx.server_component_with_prerendered_skeleton(
        filepath.join("component-page", file_path),
        components.audit_page_sol,
        audit_page_sol.get_skeleton(context.skeletons, for: file_path),
      )
      |> audit_tree.view(
        Some(elementx.server_component_with_prerendered_skeleton(
          filepath.join("component-page-dashboard", file_path),
          components.page_dashboard,
          page_dashboard.get_skeleton(context.skeletons, for: file_path),
        )),
        audit_name,
        on: file_path,
        with: gateway.get_audit_metadata(
          context.audit_metadata_gateway,
          audit_name,
        ).in_scope_files,
      )
      |> as_document
      |> element.to_document_string_builder
      |> wisp.html_response(200)
    }
  }
}

fn as_document(body: element.Element(msg)) {
  html.html([], [
    html.head([], [
      html.link([
        attribute.rel("icon"),
        attribute.href(
          "data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🕵️</text></svg>",
        ),
      ]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/line_discussion.min.css"),
      ]),
      html.link([attribute.rel("stylesheet"), attribute.href("/styles.css")]),
      html.script(
        [attribute.type_("module"), attribute.src("/line_discussion.min.mjs")],
        "",
      ),
      html.script(
        [attribute.type_("module"), attribute.src("/page_navigation.mjs")],
        "",
      ),
      html.script([attribute.type_("module"), attribute.src("/client.mjs")], ""),
      html.script(
        [attribute.type_("module"), attribute.src("/panel_resizer.mjs")],
        "",
      ),
      html.script(
        [attribute.type_("module"), attribute.src("/page_panel.mjs")],
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

fn serve_lustre_framework() {
  let path = config.get_priv_path(for: "static/lustre_server_component.mjs")
  let assert Ok(script) = mist.send_file(path, offset: 0, limit: None)

  response.new(200)
  |> response.prepend_header("content-type", "application/javascript")
  |> response.set_body(script)
  |> response.set_header("cache-control", "max-age=604800, must-revalidate")
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
