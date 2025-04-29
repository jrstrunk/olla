import argv
import concurrent_dict
import filepath
import gleam/dynamic/decode
import gleam/erlang
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/json
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
import o11a/note
import o11a/server/discussion
import o11a/ui/gateway
import snag
import tempo/datetime
import wisp
import wisp/wisp_mist

type Context {
  Context(
    config: config.Config,
    audit_metadata_gateway: gateway.AuditMetaDataGateway,
    discussion_gateway: concurrent_dict.ConcurrentDict(
      String,
      discussion.Discussion,
    ),
    discussion_component_gateway: gateway.DiscussionComponentGateway,
    source_files: concurrent_dict.ConcurrentDict(String, string_tree.StringTree),
    audit_metadata: concurrent_dict.ConcurrentDict(
      String,
      string_tree.StringTree,
    ),
  )
}

pub fn main() {
  let config = case argv.load().arguments {
    [] -> config.get_prod_config()
    ["dev"] -> config.get_dev_config()
    _ -> panic as "Unrecognized argument given"
  }

  io.println("o11a is starting!")

  use
    gateway.Gateway(
      audit_metadata_gateway:,
      discussion_gateway:,
      discussion_component_gateway:,
      source_files:,
      audit_metadata:,
    )
  <- result.map(
    gateway.start_gateway()
    |> result.map_error(fn(e) { snag.pretty_print(e) |> io.println }),
  )

  let context =
    Context(
      config:,
      audit_metadata_gateway:,
      discussion_gateway:,
      discussion_component_gateway:,
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

    ["lustre-server-component.mjs"] ->
      serve_lustre_server_component(context.config)

    ["o11a_client.mjs" as script]
    | ["o11a_client_script.mjs" as script]
    | ["panel_resizer.mjs" as script] -> serve_js(script, context.config)

    ["component-discussion", audit_name] -> {
      let assert Ok(actor) =
        gateway.get_discussion_component_actor(
          context.discussion_component_gateway,
          audit_name,
        )

      server_componentx.serve_component_connection(req, actor)
    }

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

    ["audit-discussion", audit_name] -> {
      use <- wisp.require_method(req, http.Get)

      let result = {
        use discussion <- result.map(
          gateway.get_discussion(context.discussion_gateway, audit_name)
          |> result.replace_error(snag.new("Failed to get discussion")),
        )

        discussion.dump_computed_notes(discussion)
      }

      case result {
        Ok(discussion) ->
          wisp.json_response(discussion |> json.to_string_tree, 200)
        Error(e) ->
          wisp.json_response(
            json.object([#("error", json.string(snag.line_print(e)))])
              |> json.to_string_tree,
            500,
          )
      }
    }

    ["audit-discussion-since", audit_name, since_time] -> {
      use <- wisp.require_method(req, http.Get)

      let result = {
        use discussion <- result.try(
          gateway.get_discussion(context.discussion_gateway, audit_name)
          |> result.replace_error(snag.new("Failed to get discussion")),
        )
        use ref_time <- result.map(
          datetime.from_string(since_time)
          |> snag.map_error(datetime.describe_parse_error),
        )

        discussion.dump_computed_notes_since(discussion, ref_time)
      }

      case result {
        Ok(discussion) ->
          wisp.json_response(discussion |> json.to_string_tree, 200)
        Error(e) ->
          wisp.json_response(
            json.object([#("error", json.string(snag.line_print(e)))])
              |> json.to_string_tree,
            500,
          )
      }
    }

    ["submit-note", audit_name] -> {
      use <- wisp.require_method(req, http.Post)
      use json <- wisp.require_json(req)

      let result = {
        use discussion <- result.try(
          gateway.get_discussion(context.discussion_gateway, audit_name)
          |> result.replace_error(snag.new("Failed to get discussion")),
        )
        use #(topic_id, note_submission) <- result.try(
          decode.run(json, {
            use topic_id <- decode.field("topic_id", decode.string)
            use note_submission <- decode.field(
              "note_submission",
              note.note_submission_decoder(),
            )
            decode.success(#(topic_id, note_submission))
          })
          |> result.replace_error(snag.new("Failed to decode note")),
        )

        discussion.add_note(discussion, note_submission, topic_id)
        |> result.replace_error(snag.new("Failed to add note"))
      }

      // An appropriate response is returned depending on whether the JSON could be
      // successfully handled or not.
      case result {
        Ok(Nil) ->
          wisp.json_response(
            json.object([#("msg", json.string("success"))])
              |> json.to_string_tree,
            201,
          )

        // In a real application we would probably want to return some JSON error
        // object, but for this example we'll just return an empty response.
        Error(e) ->
          wisp.json_response(
            json.object([#("error", json.string(snag.line_print(e)))])
              |> json.to_string_tree,
            500,
          )
      }
    }

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
              attribute.src("/lustre-server-component.mjs"),
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
      |> element.to_document_string_tree
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

pub fn serve_lustre_server_component(config: config.Config) {
  let assert Ok(lustre_priv) = erlang.priv_directory("lustre")
  let file_path = lustre_priv <> "/static/lustre-server-component.mjs"
  let assert Ok(file) = mist.send_file(file_path, offset: 0, limit: None)

  response.new(200)
  |> response.prepend_header("content-type", "application/javascript")
  |> response.set_body(file)
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
