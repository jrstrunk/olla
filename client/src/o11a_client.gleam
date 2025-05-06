import given
import gleam/dict
import gleam/dynamic/decode
import gleam/int
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
import o11a/client/storage
import o11a/computed_note
import o11a/declaration
import o11a/events
import o11a/note
import o11a/preprocessor
import o11a/ui/audit_dashboard
import o11a/ui/audit_page
import o11a/ui/audit_page_dashboard
import o11a/ui/audit_tree
import o11a/ui/discussion
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
    audit_declarations: dict.Dict(
      String,
      Result(List(declaration.Declaration), lustre_http.HttpError),
    ),
    audit_references: dict.Dict(
      String,
      Result(
        dict.Dict(String, List(declaration.Reference)),
        lustre_http.HttpError,
      ),
    ),
    discussions: dict.Dict(
      String,
      dict.Dict(String, List(computed_note.ComputedNote)),
    ),
    discussion_models: dict.Dict(DiscussionKey, discussion.Model),
    keyboard_model: page_navigation.Model,
    selected_discussion: option.Option(DiscussionKey),
    selected_node_id: option.Option(Int),
    focused_discussion: option.Option(DiscussionKey),
    clicked_discussion: option.Option(DiscussionKey),
  )
}

pub type Route {
  O11aHomeRoute
  AuditDashboardRoute(audit_name: String)
  AuditPageRoute(audit_name: String, page_path: String)
}

pub type DiscussionKey {
  DiscussionKey(page_path: String, line_number: Int, column_number: Int)
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
      audit_declarations: dict.new(),
      discussions: dict.new(),
      audit_references: dict.new(),
      discussion_models: dict.new(),
      keyboard_model: page_navigation.init(),
      selected_discussion: option.None,
      selected_node_id: option.None,
      focused_discussion: option.None,
      clicked_discussion: option.None,
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
  echo "on_url_change"
  echo uri
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

fn get_page_route_from_model(model: Model) {
  case model.route {
    AuditDashboardRoute(..) -> Error(Nil)
    AuditPageRoute(page_path:, ..) -> Ok(page_path)
    O11aHomeRoute -> Error(Nil)
  }
}

fn get_audit_name_from_model(model: Model) {
  case model.route {
    AuditDashboardRoute(audit_name:) -> Ok(audit_name)
    AuditPageRoute(audit_name:, ..) -> Ok(audit_name)
    O11aHomeRoute -> Error(Nil)
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
  ClientFetchedDeclarations(
    audit_name: String,
    declarations: Result(List(declaration.Declaration), lustre_http.HttpError),
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
  UserSelectedDiscussionEntry(
    kind: audit_page.DiscussionSelectKind,
    line_number: Int,
    column_number: Int,
    node_id: option.Option(Int),
    topic_id: String,
    topic_title: String,
    is_reference: Bool,
  )
  UserUnselectedDiscussionEntry(kind: audit_page.DiscussionSelectKind)
  UserClickedDiscussionEntry(line_number: Int, column_number: Int)
  UserCtrlClickedNode(uri: String)
  UserClickedInsideDiscussion(line_number: Int, column_number: Int)
  UserClickedOutsideDiscussion
  UserUpdatedDiscussion(
    line_number: Int,
    column_number: Int,
    update: #(discussion.Model, discussion.Effect),
  )
  UserSuccessfullySubmittedNote(updated_model: discussion.Model)
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

    ClientFetchedSourceFile(page_path, source_files) -> {
      case source_files {
        Ok(..) -> io.println("Successfully fetched source file " <> page_path)
        Error(e) ->
          io.println(
            "Failed to fetch source file "
            <> page_path
            <> ": "
            <> string.inspect(e),
          )
      }
      #(
        Model(
          ..model,
          source_files: dict.insert(model.source_files, page_path, source_files),
          keyboard_model: page_navigation.Model(
            ..model.keyboard_model,
            line_count: case source_files {
              Ok(source_files) -> list.length(source_files)
              Error(..) -> model.keyboard_model.line_count
            },
          ),
        ),
        effect.none(),
      )
    }

    ClientFetchedDeclarations(audit_name:, declarations:) -> {
      case declarations {
        Ok(..) -> io.println("Successfully fetched declarations " <> audit_name)
        Error(e) ->
          io.println("Failed to fetch declarations: " <> string.inspect(e))
      }
      #(
        Model(
          ..model,
          audit_declarations: dict.insert(
            model.audit_declarations,
            audit_name,
            declarations,
          ),
          audit_references: dict.insert(
            model.audit_references,
            audit_name,
            declarations
              |> result.map(fn(declarations) {
                // Multiple declarations can have the same topic_id, so we need
                // to group them by topic_id first, then flatten the result
                list.group(declarations, by: fn(declaration) {
                  declaration.topic_id
                })
                |> dict.map_values(fn(_k, value) {
                  list.map(value, fn(declaration) { declaration.references })
                  |> list.flatten
                })
              }),
          ),
        ),
        effect.none(),
      )
    }

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

    UserSelectedDiscussionEntry(
      kind:,
      line_number:,
      column_number:,
      node_id:,
      topic_id:,
      topic_title:,
      is_reference:,
    ) -> {
      use page_path <- given.ok(
        get_page_route_from_model(model),
        else_return: fn(_) { #(model, effect.none()) },
      )
      use audit_name <- given.ok(
        get_audit_name_from_model(model),
        else_return: fn(_) { #(model, effect.none()) },
      )
      use declarations <- given.ok(
        case dict.get(model.audit_declarations, audit_name) {
          Ok(Ok(declarations)) -> Ok(declarations)
          _ -> Error(Nil)
        },
        else_return: fn(_) { #(model, effect.none()) },
      )

      let selected_discussion =
        DiscussionKey(page_path:, line_number:, column_number:)

      let discussion_models = case
        dict.get(model.discussion_models, selected_discussion)
      {
        Ok(..) -> model.discussion_models
        Error(Nil) ->
          dict.insert(
            model.discussion_models,
            selected_discussion,
            discussion.init(
              line_number:,
              column_number:,
              topic_id:,
              topic_title:,
              is_reference:,
              declarations:,
            ),
          )
      }

      #(
        case kind {
          audit_page.EntryHover ->
            Model(
              ..model,
              selected_discussion: option.Some(selected_discussion),
              discussion_models:,
              selected_node_id: node_id,
            )
          audit_page.EntryFocus ->
            Model(
              ..model,
              focused_discussion: option.Some(selected_discussion),
              discussion_models:,
              selected_node_id: node_id,
              keyboard_model: page_navigation.Model(
                ..model.keyboard_model,
                current_line_number: line_number,
                current_column_number: column_number,
              ),
            )
        },
        effect.none(),
      )
    }

    UserUnselectedDiscussionEntry(kind:) -> {
      echo "Unselecting discussion " <> string.inspect(kind)
      #(
        case kind {
          audit_page.EntryHover ->
            Model(
              ..model,
              selected_discussion: option.None,
              selected_node_id: option.None,
            )
          audit_page.EntryFocus ->
            Model(
              ..model,
              focused_discussion: option.None,
              selected_node_id: option.None,
            )
        },
        effect.none(),
      )
    }

    UserClickedDiscussionEntry(line_number:, column_number:) -> {
      use page_path <- given.ok(
        get_page_route_from_model(model),
        else_return: fn(_) { #(model, effect.none()) },
      )

      #(
        Model(
          ..model,
          clicked_discussion: option.Some(DiscussionKey(
            page_path:,
            line_number:,
            column_number:,
          )),
        ),
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

    UserCtrlClickedNode(uri) -> {
      let #(path, fragment) = case string.split_once(uri, "#") {
        Ok(#(uri, fragment)) -> #(uri, option.Some(fragment))
        Error(..) -> #(uri, option.None)
      }
      let path = "/" <> path

      #(model, modem.push(path, option.None, fragment))
    }

    UserClickedInsideDiscussion(line_number:, column_number:) -> {
      use page_path <- given.ok(
        get_page_route_from_model(model),
        else_return: fn(_) { #(model, effect.none()) },
      )

      echo "User clicked inside discussion"
      let model = case
        model.selected_discussion
        != option.Some(DiscussionKey(page_path:, line_number:, column_number:))
      {
        True -> Model(..model, selected_discussion: option.None)
        False -> model
      }

      let model = case
        model.focused_discussion
        != option.Some(DiscussionKey(page_path:, line_number:, column_number:))
      {
        True -> Model(..model, focused_discussion: option.None)
        False -> model
      }

      let model = case
        model.clicked_discussion
        != option.Some(DiscussionKey(page_path:, line_number:, column_number:))
      {
        True -> Model(..model, clicked_discussion: option.None)
        False -> model
      }

      #(model, effect.none())
    }

    UserClickedOutsideDiscussion -> {
      echo "User clicked outside discussion"
      #(
        Model(
          ..model,
          selected_discussion: option.None,
          focused_discussion: option.None,
          clicked_discussion: option.None,
        ),
        effect.none(),
      )
    }

    UserUpdatedDiscussion(line_number:, column_number:, update:) -> {
      use page_path <- given.ok(
        get_page_route_from_model(model),
        else_return: fn(_) { #(model, effect.none()) },
      )
      let #(discussion_model, discussion_effect) = update

      case discussion_effect {
        discussion.SubmitNote(note_submission, topic_id) -> #(
          model,
          case model.route {
            AuditPageRoute(audit_name:, ..) | AuditDashboardRoute(audit_name:) -> {
              submit_note(
                audit_name,
                topic_id,
                note_submission,
                discussion_model,
              )
            }
            O11aHomeRoute -> effect.none()
          },
        )

        discussion.FocusDiscussionInput(line_number, column_number) -> {
          echo "Focusing discussion input, user is typing"
          storage.set_is_user_typing(True)
          #(
            Model(
              ..model,
              focused_discussion: option.Some(DiscussionKey(
                page_path:,
                line_number:,
                column_number:,
              )),
            ),
            effect.none(),
          )
        }

        discussion.FocusExpandedDiscussionInput(line_number, column_number) -> {
          storage.set_is_user_typing(True)
          #(
            Model(
              ..model,
              focused_discussion: option.Some(DiscussionKey(
                page_path:,
                line_number:,
                column_number:,
              )),
            ),
            effect.none(),
          )
        }

        discussion.UnfocusDiscussionInput(_line_number, _column_number) -> {
          echo "Unfocusing discussion input"
          storage.set_is_user_typing(False)
          #(model, effect.none())
        }

        discussion.MaximizeDiscussion(_line_number, _column_number)
        | discussion.None -> #(
          Model(
            ..model,
            discussion_models: dict.insert(
              model.discussion_models,
              DiscussionKey(page_path:, line_number:, column_number:),
              discussion_model,
            ),
          ),
          effect.none(),
        )
      }
    }

    UserSuccessfullySubmittedNote(updated_model) -> {
      use page_path <- given.ok(
        get_page_route_from_model(model),
        else_return: fn(_) { #(model, effect.none()) },
      )

      #(
        Model(
          ..model,
          discussion_models: dict.insert(
            model.discussion_models,
            DiscussionKey(
              page_path:,
              line_number: updated_model.line_number,
              column_number: updated_model.column_number,
            ),
            updated_model,
          ),
        ),
        effect.none(),
      )
    }

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
        fetch_declarations(audit_name),
        fetch_discussion(audit_name),
      ])
    AuditPageRoute(audit_name:, page_path:) ->
      effect.batch([
        fetch_metadata(model, audit_name),
        fetch_source_file(model, page_path),
        fetch_declarations(audit_name),
        fetch_discussion(audit_name),
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

fn fetch_declarations(audit_name) {
  lustre_http.get(
    "/audit-declarations/" <> audit_name,
    lustre_http.expect_json(
      decode.list(declaration.declaration_decoder()),
      ClientFetchedDeclarations(audit_name, _),
    ),
  )
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

fn submit_note(audit_name, topic_id, note_submission, discussion_model) {
  lustre_http.post(
    "/submit-note/" <> audit_name,
    json.object([
      #("topic_id", json.string(topic_id)),
      #("note_submission", note.encode_note_submission(note_submission)),
    ]),
    lustre_http.expect_json(
      decode.field("msg", decode.string, fn(msg) {
        case msg {
          "success" -> decode.success(Nil)
          _ -> decode.failure(Nil, msg)
        }
      }),
      fn(response) {
        case response {
          Ok(Nil) -> UserSuccessfullySubmittedNote(discussion_model)
          Error(e) -> UserFailedToSubmitNote(e)
        }
      },
    ),
  )
}

fn view(model: Model) {
  case model.route {
    AuditDashboardRoute(audit_name:) -> {
      let discussion =
        dict.get(model.discussions, audit_name)
        |> result.unwrap(dict.new())

      html.div([], [
        server_component.element(
          [server_component.route("/component-discussion/" <> audit_name)],
          [],
        ),
        audit_tree.view(
          audit_dashboard.view(discussion, audit_name),
          option.None,
          model.file_tree,
          audit_name,
          audit_tree.dashboard_path(for: audit_name),
        ),
      ])
    }

    AuditPageRoute(audit_name:, page_path:) -> {
      let selected_discussion = get_selected_discussion(model)

      let discussion =
        dict.get(model.discussions, audit_name)
        |> result.unwrap(dict.new())

      let preprocessed_source =
        dict.get(model.source_files, page_path)
        |> result.unwrap(Ok([]))
        |> result.unwrap([])

      let references =
        dict.get(model.audit_references, audit_name)
        |> result.unwrap(Ok(dict.new()))
        |> result.unwrap(dict.new())

      html.div([event.on_click(UserClickedOutsideDiscussion)], [
        selected_node_highlighter(model),
        server_component.element(
          [
            server_component.route("/component-discussion/" <> audit_name),
            on_server_updated_discussion(ServerUpdatedDiscussion),
          ],
          [],
        ),
        audit_tree.view(
          audit_page.view(
            preprocessed_source:,
            discussion:,
            references:,
            selected_discussion:,
          )
            |> element.map(map_audit_page_msg),
          audit_page_dashboard.view(discussion, page_path)
            |> option.Some,
          model.file_tree,
          audit_name,
          page_path,
        ),
      ])
    }
    O11aHomeRoute -> html.p([], [html.text("Home")])
  }
}

fn selected_node_highlighter(model: Model) {
  case model.selected_node_id {
    option.Some(selected_node_id) ->
      html.style(
        [],
        ".N"
          <> int.to_string(selected_node_id)
          <> " { background-color: var(--highlight-color); border-radius: 0.15rem; }",
      )
    option.None -> element.fragment([])
  }
}

fn get_selected_discussion(model: Model) {
  case
    model.focused_discussion,
    model.clicked_discussion,
    model.selected_discussion
  {
    option.Some(discussion), _, _
    | _, option.Some(discussion), _
    | _, _, option.Some(discussion)
    ->
      dict.get(model.discussion_models, discussion)
      |> result.map(fn(model) {
        option.Some(audit_page.DiscussionReference(
          line_number: discussion.line_number,
          column_number: discussion.column_number,
          model:,
        ))
      })
      |> result.unwrap(option.None)
    option.None, option.None, option.None -> option.None
  }
}

pub fn on_server_updated_discussion(msg) {
  event.on(events.server_updated_discussion, {
    // echo "Server updated discussion"
    use audit_name <- decode.subfield(["detail", "audit_name"], decode.string)
    decode.success(msg(audit_name))
  })
}

fn map_audit_page_msg(msg) {
  case msg {
    audit_page.UserSelectedDiscussionEntry(
      kind:,
      line_number:,
      column_number:,
      node_id:,
      topic_id:,
      topic_title:,
      is_reference:,
    ) ->
      UserSelectedDiscussionEntry(
        kind:,
        line_number:,
        column_number:,
        node_id:,
        topic_id:,
        topic_title:,
        is_reference:,
      )
    audit_page.UserUnselectedDiscussionEntry(kind:) ->
      UserUnselectedDiscussionEntry(kind:)
    audit_page.UserClickedDiscussionEntry(line_number:, column_number:) ->
      UserClickedDiscussionEntry(line_number:, column_number:)
    audit_page.UserUpdatedDiscussion(line_number:, column_number:, update:) ->
      UserUpdatedDiscussion(line_number:, column_number:, update:)
    audit_page.UserClickedInsideDiscussion(line_number:, column_number:) ->
      UserClickedInsideDiscussion(line_number:, column_number:)
    audit_page.UserCtrlClickedNode(uri:) -> UserCtrlClickedNode(uri:)
  }
}
