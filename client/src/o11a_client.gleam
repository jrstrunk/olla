import gleam/dict
import gleam/dynamic/decode
import gleam/io
import gleam/option
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre_http
import modem
import o11a/audit_metadata
import o11a/computed_note
import o11a/preprocessor
import o11a/ui/audit_page
import o11a/ui/audit_tree

pub fn main() {
  io.println("Starting client controller")
  lustre.application(init, update, view)
  |> lustre.start("#app", Nil)
}

pub type Model {
  Model(
    route: Route,
    file_tree: dict.Dict(String, #(List(String), List(String))),
    audit_metadata: dict.Dict(
      String,
      Result(audit_metadata.AuditMetaData, lustre_http.HttpError),
    ),
    source_files: dict.Dict(
      String,
      Result(List(preprocessor.PreProcessedLine), lustre_http.HttpError),
    ),
    discussions: dict.Dict(
      String,
      dict.Dict(String, List(computed_note.ComputedNote)),
    ),
  )
}

pub type Route {
  O11aHomeRoute
  AuditDashboardRoute(audit_name: String)
  AuditPageRoute(audit_name: String, page_path: String)
}

fn init(_) -> #(Model, Effect(Msg)) {
  let route = case modem.initial_uri() {
    Ok(uri) -> parse_route(uri)
    Error(Nil) -> O11aHomeRoute
  }

  let init_model =
    Model(
      route:,
      file_tree: dict.new(),
      audit_metadata: dict.new(),
      source_files: dict.new(),
      discussions: dict.new(),
    )

  #(
    init_model,
    effect.batch([
      modem.init(on_url_change),
      route_change_effect(init_model, new_route: init_model.route),
    ]),
  )
}

fn on_url_change(uri: Uri) -> Msg {
  parse_route(uri) |> OnRouteChange
}

fn parse_route(uri: Uri) -> Route {
  case uri.path_segments(uri.path) {
    [] | ["dashboard"] -> O11aHomeRoute

    [audit_name] | [audit_name, "dashboard"] -> AuditDashboardRoute(audit_name:)

    [audit_name, _, ..] ->
      AuditPageRoute(
        audit_name:,
        // Drop the leading slash
        page_path: uri.path |> string.drop_start(1),
      )
  }
}

fn file_tree_from_route(
  route: Route,
  audit_metadata: dict.Dict(
    String,
    Result(audit_metadata.AuditMetaData, lustre_http.HttpError),
  ),
) {
  case route {
    O11aHomeRoute -> dict.new()

    AuditDashboardRoute(audit_name:) -> {
      let in_scope_files =
        dict.get(audit_metadata, audit_name)
        |> result.map(fn(audit_metadata) {
          case audit_metadata {
            Ok(audit_metadata) -> audit_metadata.in_scope_files
            Error(..) -> []
          }
        })
        |> result.unwrap([])

      audit_tree.group_files_by_parent(
        in_scope_files:,
        current_file_path: audit_tree.dashboard_path(for: audit_name),
        audit_name:,
      )
    }

    AuditPageRoute(audit_name:, page_path: current_file_path) -> {
      let in_scope_files =
        dict.get(audit_metadata, audit_name)
        |> result.map(fn(audit_metadata) {
          case audit_metadata {
            Ok(audit_metadata) -> audit_metadata.in_scope_files
            Error(..) -> []
          }
        })
        |> result.unwrap([])

      audit_tree.group_files_by_parent(
        in_scope_files:,
        current_file_path:,
        audit_name:,
      )
    }
  }
}

pub type Msg {
  OnRouteChange(route: Route)
  ClientFetchedAuditMetadata(
    audit_name: String,
    metadata: Result(audit_metadata.AuditMetaData, lustre_http.HttpError),
  )
  ClientFetchedSourceFile(
    page_path: String,
    source_file: Result(
      List(preprocessor.PreProcessedLine),
      lustre_http.HttpError,
    ),
  )
}

fn update(model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    OnRouteChange(route:) -> #(
      Model(
        ..model,
        route:,
        file_tree: file_tree_from_route(route, model.audit_metadata),
      ),
      route_change_effect(model, new_route: route),
    )

    ClientFetchedAuditMetadata(audit_name, metadata) -> {
      let updated_audit_metadata =
        dict.insert(model.audit_metadata, audit_name, metadata)
      #(
        Model(
          ..model,
          audit_metadata: updated_audit_metadata,
          file_tree: file_tree_from_route(model.route, updated_audit_metadata),
        ),
        effect.none(),
      )
    }

    ClientFetchedSourceFile(page_path, source_files) -> #(
      Model(
        ..model,
        source_files: dict.insert(model.source_files, page_path, source_files),
      ),
      effect.none(),
    )
  }
}

fn route_change_effect(model, new_route route: Route) {
  case route {
    AuditDashboardRoute(audit_name:) -> fetch_metadata(model, audit_name)
    AuditPageRoute(audit_name:, page_path:) ->
      effect.batch([
        fetch_metadata(model, audit_name),
        fetch_source_file(model, page_path),
      ])
    O11aHomeRoute -> effect.none()
  }
}

fn fetch_metadata(model: Model, audit_name: String) -> Effect(Msg) {
  case dict.get(model.audit_metadata, audit_name) {
    Ok(Ok(..)) -> effect.none()
    _ ->
      lustre_http.get(
        "/audit-metadata/" <> audit_name,
        lustre_http.expect_json(
          audit_metadata.audit_metadata_decoder(),
          ClientFetchedAuditMetadata(audit_name, _),
        ),
      )
  }
}

fn fetch_source_file(model: Model, page_path: String) -> Effect(Msg) {
  case dict.get(model.source_files, page_path) {
    Ok(Ok(..)) -> effect.none()
    _ ->
      lustre_http.get(
        "/source-file/" <> page_path,
        lustre_http.expect_json(
          decode.list(preprocessor.pre_processed_line_decoder()),
          ClientFetchedSourceFile(page_path, _),
        ),
      )
  }
}

fn view(model: Model) -> Element(Msg) {
  case model.route {
    AuditDashboardRoute(audit_name:) ->
      audit_tree.view(
        html.p([], [html.text("Dashboard")]),
        option.None,
        model.file_tree,
        audit_name,
        audit_tree.dashboard_path(for: audit_name),
      )

    AuditPageRoute(audit_name:, page_path:) ->
      audit_tree.view(
        audit_page.view(
          preprocessed_source: dict.get(model.source_files, page_path)
            |> result.map(fn(source_files) {
              case source_files {
                Ok(source_files) -> source_files
                Error(..) -> []
              }
            })
            |> result.unwrap([]),
          discussion: dict.new(),
        ),
        option.Some(html.p([], [html.text("Side Panel")])),
        model.file_tree,
        audit_name,
        page_path,
      )

    O11aHomeRoute -> html.p([], [html.text("Home")])
  }
}
