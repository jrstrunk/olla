import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/uri.{type Uri}
import lustre
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html
import lustre/event
import lustre/server_component
import lustre_http
import modem
import o11a/audit_metadata
import o11a/client/page_navigation
import o11a/client/selectors
import o11a/computed_note
import o11a/events
import o11a/note
import o11a/preprocessor
import o11a/ui/audit_page
import o11a/ui/audit_tree
import o11a/ui/discussion_overlay
import plinth/browser/element as browser_element
import plinth/browser/event as browser_event
import plinth/browser/window

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
    discussion_overlay_models: dict.Dict(#(Int, Int), discussion_overlay.Model),
    keyboard_model: page_navigation.Model,
    selected_discussion: option.Option(#(Int, Int)),
    selected_node_id: option.Option(Int),
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
      discussion_overlay_models: dict.new(),
      keyboard_model: page_navigation.init(),
      selected_discussion: option.None,
      selected_node_id: option.None,
    )

  #(
    init_model,
    effect.batch([
      modem.init(on_url_change),
      effect.from(fn(dispatch) {
        window.add_event_listener("keydown", fn(event) {
          page_navigation.prevent_default(event)
          dispatch(UserEnteredKey(event))
        })
      }),
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
  ClientFetchedDiscussion(
    audit_name: String,
    discussion: Result(List(computed_note.ComputedNote), lustre_http.HttpError),
  )
  ServerUpdatedDiscussion(audit_name: String)
  UserEnteredKey(
    browser_event: browser_event.Event(
      browser_event.UIEvent(browser_event.KeyboardEvent),
    ),
  )
  UserHoveredDiscussionEntry(
    line_number: Int,
    column_number: Int,
    node_id: option.Option(Int),
    topic_id: String,
    topic_title: String,
    is_reference: Bool,
  )
  UserUnhoveredDiscussionEntry
  UserClickedDiscussionEntry(line_number: Int, column_number: Int)
  UserFocusedDiscussionEntry(line_number: Int, column_number: Int)
  UserUpdatedDiscussion(
    line_number: Int,
    column_number: Int,
    update: #(discussion_overlay.Model, discussion_overlay.Effect),
  )
  UserSuccessfullySubmittedNote(updated_model: discussion_overlay.Model)
  UserFailedToSubmitNote(error: lustre_http.HttpError)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
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

    ClientFetchedDiscussion(audit_name:, discussion:) ->
      case discussion {
        Ok(discussion) -> #(
          Model(
            ..model,
            discussions: dict.insert(
              model.discussions,
              audit_name,
              discussion
                |> list.group(by: fn(note) { note.parent_id }),
            ),
          ),
          effect.none(),
        )
        Error(e) -> {
          io.println("Failed to fetch discussion: " <> string.inspect(e))
          #(model, effect.none())
        }
      }

    ServerUpdatedDiscussion(audit_name:) -> #(
      model,
      fetch_discussion(audit_name),
    )

    UserEnteredKey(browser_event:) -> {
      let #(keyboard_model, effect) =
        page_navigation.do_page_navigation(browser_event, model.keyboard_model)
      #(Model(..model, keyboard_model:), effect)
    }

    UserFocusedDiscussionEntry(line_number:, column_number:) -> #(
      Model(
        ..model,
        keyboard_model: page_navigation.Model(
          ..model.keyboard_model,
          current_line_number: line_number,
          current_column_number: column_number,
        ),
      ),
      effect.none(),
    )

    UserHoveredDiscussionEntry(
      line_number:,
      column_number:,
      node_id:,
      topic_id:,
      topic_title:,
      is_reference:,
    ) -> {
      let selected_discussion = #(line_number, column_number)

      let discussion_overlay_models = case
        dict.get(model.discussion_overlay_models, selected_discussion)
      {
        Ok(..) -> model.discussion_overlay_models
        Error(Nil) ->
          dict.insert(
            model.discussion_overlay_models,
            selected_discussion,
            discussion_overlay.init(
              line_number:,
              column_number:,
              topic_id:,
              topic_title:,
              is_reference:,
            ),
          )
      }

      #(
        Model(
          ..model,
          selected_discussion: option.Some(selected_discussion),
          discussion_overlay_models:,
          selected_node_id: node_id,
        ),
        effect.none(),
      )
    }

    UserUnhoveredDiscussionEntry -> {
      #(
        Model(
          ..model,
          selected_discussion: option.None,
          selected_node_id: option.None,
        ),
        effect.none(),
      )
    }

    UserClickedDiscussionEntry(line_number:, column_number:) -> {
      #(
        model,
        effect.from(fn(_dispatch) {
          let res =
            selectors.discussion_input(line_number:, column_number:)
            |> result.map(browser_element.focus)

          case res {
            Ok(Nil) -> Nil
            Error(Nil) -> io.println("Failed to focus discussion input")
          }
        }),
      )
    }

    UserUpdatedDiscussion(line_number:, column_number:, update:) -> {
      let #(discussion_model, discussion_effect) = update

      case discussion_effect {
        discussion_overlay.SubmitNote(note_submission, topic_id) -> #(
          model,
          case model.route {
            AuditPageRoute(audit_name:, ..) | AuditDashboardRoute(audit_name:) -> {
              lustre_http.post(
                "/submit-note/" <> audit_name,
                json.object([
                  #("topic_id", json.string(topic_id)),
                  #(
                    "note_submission",
                    note.encode_note_submission(note_submission),
                  ),
                ]),
                lustre_http.expect_json(
                  decode.field("msg", decode.string, fn(msg) {
                    case msg {
                      "success" -> decode.success(Nil)
                      _ -> decode.failure(Nil, msg)
                    }
                    |> echo
                  }),
                  fn(response) {
                    case response {
                      Ok(Nil) -> UserSuccessfullySubmittedNote(discussion_model)
                      Error(e) -> UserFailedToSubmitNote(e)
                    }
                    |> echo
                  },
                ),
              )
            }
            O11aHomeRoute -> effect.none()
          },
        )

        discussion_overlay.FocusDiscussionInput(_line_number, _column_number)
        | discussion_overlay.FocusExpandedDiscussionInput(
            _line_number,
            _column_number,
          )
        | discussion_overlay.UnfocusDiscussionInput(
            _line_number,
            _column_number,
          )
        | discussion_overlay.MaximizeDiscussion(_line_number, _column_number)
        | discussion_overlay.None -> #(
          Model(
            ..model,
            discussion_overlay_models: dict.insert(
              model.discussion_overlay_models,
              #(line_number, column_number),
              discussion_model,
            ),
          ),
          effect.none(),
        )
      }
    }
    UserSuccessfullySubmittedNote(updated_model) -> #(
      Model(
        ..model,
        discussion_overlay_models: dict.insert(
          model.discussion_overlay_models,
          #(updated_model.line_number, updated_model.column_number),
          updated_model,
        ),
      ),
      effect.none(),
    )
    UserFailedToSubmitNote(error) -> {
      io.print("Failed to submit note: " <> string.inspect(error))
      #(model, effect.none())
    }
  }
}

fn route_change_effect(model, new_route route: Route) {
  case route {
    AuditDashboardRoute(audit_name:) ->
      effect.batch([
        fetch_metadata(model, audit_name),
        fetch_discussion(audit_name),
      ])
    AuditPageRoute(audit_name:, page_path:) ->
      effect.batch([
        fetch_discussion(audit_name),
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

fn fetch_discussion(audit_name) {
  lustre_http.get(
    "/audit-discussion/" <> audit_name,
    lustre_http.expect_json(
      decode.list(computed_note.computed_note_decoder()),
      ClientFetchedDiscussion(audit_name, _),
    ),
  )
}

fn view(model: Model) {
  case model.route {
    AuditDashboardRoute(audit_name:) ->
      html.div([], [
        server_component.component([
          server_component.route("/component-discussion/" <> audit_name),
        ]),
        audit_tree.view(
          html.p([], [html.text("Dashboard")]),
          option.None,
          model.file_tree,
          audit_name,
          audit_tree.dashboard_path(for: audit_name),
        ),
      ])

    AuditPageRoute(audit_name:, page_path:) ->
      html.div([], [
        server_component.component([
          server_component.route("/component-discussion/" <> audit_name),
          on_server_updated_discussion(ServerUpdatedDiscussion),
        ]),
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
            discussion: dict.get(model.discussions, audit_name)
              |> result.unwrap(dict.new()),
            selected_discussion: case model.selected_discussion {
              option.Some(selected_discussion) ->
                dict.get(model.discussion_overlay_models, selected_discussion)
                |> result.map(fn(model) {
                  option.Some(audit_page.DiscussionReference(
                    line_number: selected_discussion.0,
                    column_number: selected_discussion.1,
                    model:,
                  ))
                })
                |> result.unwrap(option.None)
              option.None -> option.None
            },
          )
            |> element.map(map_audit_page_msg),
          option.None,
          model.file_tree,
          audit_name,
          page_path,
        ),
      ])

    O11aHomeRoute -> html.p([], [html.text("Home")])
  }
}

pub fn on_server_updated_discussion(msg) {
  use event <- event.on(events.server_updated_discussion)

  let empty_error = [dynamic.DecodeError("", "", [])]

  use audit_name <- result.try(
    decode.run(event, decode.at(["detail", "audit_name"], decode.string))
    |> result.replace_error(empty_error),
  )

  msg(audit_name)
  |> Ok
}

fn map_audit_page_msg(msg) {
  case msg {
    audit_page.UserHoveredDiscussionEntry(
      line_number:,
      column_number:,
      node_id:,
      topic_id:,
      topic_title:,
      is_reference:,
    ) ->
      UserHoveredDiscussionEntry(
        line_number:,
        column_number:,
        node_id:,
        topic_id:,
        topic_title:,
        is_reference:,
      )
    audit_page.UserUnhoveredDiscussionEntry -> UserUnhoveredDiscussionEntry
    audit_page.UserClickedDiscussionEntry(line_number:, column_number:) ->
      UserClickedDiscussionEntry(line_number:, column_number:)
    audit_page.UserUpdatedDiscussion(line_number:, column_number:, update:) ->
      UserUpdatedDiscussion(line_number:, column_number:, update:)
    audit_page.UserFocusedDiscussionEntry(line_number:, column_number:) ->
      UserFocusedDiscussionEntry(line_number:, column_number:)
  }
}
