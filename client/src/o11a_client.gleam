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
import gleam/uri
import lustre
import lustre/effect
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
import o11a/discussion_topic
import o11a/events
import o11a/note
import o11a/preprocessor
import o11a/ui/audit_dashboard
import o11a/ui/audit_interface
import o11a/ui/audit_page
import o11a/ui/audit_page_dashboard
import o11a/ui/audit_tree
import o11a/ui/discussion
import plinth/browser/element as browser_element
import plinth/browser/event as browser_event
import plinth/browser/window
import plinth/javascript/global

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
      Result(dict.Dict(String, preprocessor.Declaration), lustre_http.HttpError),
    ),
    audit_declaration_lists: dict.Dict(
      String,
      Result(List(preprocessor.Declaration), lustre_http.HttpError),
    ),
    audit_interface: dict.Dict(
      String,
      Result(audit_interface.InterfaceData, lustre_http.HttpError),
    ),
    merged_topics: dict.Dict(
      String,
      Result(dict.Dict(String, String), lustre_http.HttpError),
    ),
    discussions: dict.Dict(
      String,
      dict.Dict(String, List(computed_note.ComputedNote)),
    ),
    discussion_models: dict.Dict(
      DiscussionKey,
      discussion.DiscussionOverlayModel,
    ),
    keyboard_model: page_navigation.Model,
    selected_discussion: option.Option(DiscussionKey),
    selected_node_id: option.Option(Int),
    focused_discussion: option.Option(DiscussionKey),
    clicked_discussion: option.Option(DiscussionKey),
    stickied_discussion: option.Option(DiscussionKey),
    selected_discussion_set_sticky_timer: option.Option(global.TimerID),
    stickied_discussion_unset_sticky_timer: option.Option(global.TimerID),
  )
}

pub type Route {
  O11aHomeRoute
  AuditDashboardRoute(audit_name: String)
  AuditInterfaceRoute(audit_name: String)
  AuditPageRoute(audit_name: String, page_path: String)
}

pub type DiscussionKey {
  DiscussionKey(view_id: String, line_number: Int, column_number: Int)
}

fn init(_) -> #(Model, effect.Effect(Msg)) {
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
      audit_declaration_lists: dict.new(),
      merged_topics: dict.new(),
      discussions: dict.new(),
      discussion_models: dict.new(),
      audit_interface: dict.new(),
      keyboard_model: page_navigation.init(get_page_view_id_from_route(route)),
      selected_discussion: option.None,
      selected_node_id: option.None,
      focused_discussion: option.None,
      clicked_discussion: option.None,
      stickied_discussion: option.None,
      selected_discussion_set_sticky_timer: option.None,
      stickied_discussion_unset_sticky_timer: option.None,
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

fn on_url_change(uri: uri.Uri) -> Msg {
  echo "on_url_change"
  echo uri
  parse_route(uri) |> OnRouteChange
}

fn parse_route(uri: uri.Uri) -> Route {
  case uri.path_segments(uri.path) {
    [] | ["dashboard"] -> O11aHomeRoute

    [audit_name] | [audit_name, "dashboard"] -> AuditDashboardRoute(audit_name:)

    [audit_name, "interface"] -> AuditInterfaceRoute(audit_name:)

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
      let in_scope_files = case dict.get(audit_metadata, audit_name) {
        Ok(Ok(audit_metadata)) -> audit_metadata.in_scope_files
        _ -> []
      }

      audit_tree.group_files_by_parent(
        in_scope_files:,
        current_file_path: audit_tree.dashboard_path(for: audit_name),
        audit_name:,
      )
    }

    AuditInterfaceRoute(audit_name:) -> {
      let in_scope_files = case dict.get(audit_metadata, audit_name) {
        Ok(Ok(audit_metadata)) -> audit_metadata.in_scope_files
        _ -> []
      }

      audit_tree.group_files_by_parent(
        in_scope_files:,
        current_file_path: audit_tree.interface_path(for: audit_name),
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

fn get_audit_name_from_model(model: Model) {
  case model.route {
    AuditDashboardRoute(audit_name:) -> Ok(audit_name)
    AuditInterfaceRoute(audit_name:) -> Ok(audit_name)
    AuditPageRoute(audit_name:, ..) -> Ok(audit_name)
    O11aHomeRoute -> Error(Nil)
  }
}

pub fn get_page_view_id_from_route(route) {
  case route {
    AuditDashboardRoute(..) -> "dashboard"
    AuditInterfaceRoute(..) -> "interface"
    AuditPageRoute(..) -> audit_page.view_id
    O11aHomeRoute -> "o11a"
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
    declarations: Result(List(preprocessor.Declaration), lustre_http.HttpError),
  )
  ClientFetchedMergedTopics(
    audit_name: String,
    merged_topics: Result(List(#(String, String)), lustre_http.HttpError),
  )
  ClientFetchedDiscussion(
    audit_name: String,
    discussion: Result(List(computed_note.ComputedNote), lustre_http.HttpError),
  )
  ServerUpdatedMergedTopics(audit_name: String)
  ServerUpdatedDiscussion(audit_name: String)
  UserEnteredKey(
    browser_event: browser_event.Event(
      browser_event.UIEvent(browser_event.KeyboardEvent),
    ),
  )
  UserSelectedDiscussionEntry(
    kind: discussion.DiscussionSelectKind,
    view_id: String,
    line_number: Int,
    column_number: Int,
    node_id: option.Option(Int),
    topic_id: String,
    is_reference: Bool,
  )
  UserUnselectedDiscussionEntry(kind: discussion.DiscussionSelectKind)
  UserStartedStickyOpenTimer(timer_id: global.TimerID)
  UserStartedStickyCloseTimer(timer_id: global.TimerID)
  UserHoveredInsideDiscussion(
    view_id: String,
    line_number: Int,
    column_number: Int,
  )
  UserUnhoveredInsideDiscussion(
    view_id: String,
    line_number: Int,
    column_number: Int,
  )
  ClientSetStickyDiscussion(
    view_id: String,
    line_number: Int,
    column_number: Int,
  )
  ClientUnsetStickyDiscussion
  UserClickedDiscussionEntry(
    view_id: String,
    line_number: Int,
    column_number: Int,
  )
  UserCtrlClickedNode(uri: String)
  UserClickedInsideDiscussion(
    view_id: String,
    line_number: Int,
    column_number: Int,
  )
  UserClickedOutsideDiscussion
  UserUpdatedDiscussion(
    view_id: String,
    line_number: Int,
    column_number: Int,
    update: #(
      discussion.DiscussionOverlayModel,
      discussion.DiscussionOverlayEffect,
    ),
  )
  UserSuccessfullySubmittedNote(
    updated_model: discussion.DiscussionOverlayModel,
  )
  UserFailedToSubmitNote(error: lustre_http.HttpError)
}

fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    OnRouteChange(route:) -> #(
      Model(
        ..model,
        route:,
        file_tree: file_tree_from_route(route, model.audit_metadata),
        keyboard_model: page_navigation.Model(
            ..model.keyboard_model,
            current_view_id: get_page_view_id_from_route(model.route) |> echo,
          )
          |> echo,
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
          audit_interface: dict.insert(
            model.audit_interface,
            audit_name,
            result.map(metadata, fn(metadata) {
              audit_interface.gather_interface_data(
                case dict.get(model.audit_declaration_lists, audit_name) {
                  Ok(Ok(declarations)) -> declarations
                  _ -> []
                },
                metadata.in_scope_files,
              )
            }),
          ),
          file_tree: file_tree_from_route(model.route, updated_audit_metadata),
        ),
        effect.none(),
      )
    }

    ClientFetchedSourceFile(page_path, source_files) -> {
      case source_files {
        Ok(..) -> io.println("Successfully fetched source file " <> page_path)
        Error(e) ->
          io.println_error(
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
          io.println_error(
            "Failed to fetch declarations: " <> string.inspect(e),
          )
      }

      let merged_declaration_dict = case declarations {
        Ok(declarations) -> {
          list.group(declarations, by: fn(declaration) { declaration.topic_id })
          |> dict.map_values(fn(_k, value) {
            case value {
              [first, ..] -> first
              _ -> panic
            }
          })
          |> discussion_topic.build_merged_topics(
            case dict.get(model.merged_topics, audit_name) {
              Ok(Ok(merged_topics)) -> merged_topics
              _ -> dict.new()
            },
            get_combined_topics: discussion_topic.get_combined_declaration,
          )
          |> Ok
        }
        Error(e) -> Error(e)
      }

      #(
        Model(
          ..model,
          audit_declarations: dict.insert(
            model.audit_declarations,
            audit_name,
            merged_declaration_dict,
          ),
          audit_declaration_lists: dict.insert(
            model.audit_declaration_lists,
            audit_name,
            declarations,
          ),
          audit_interface: dict.insert(
            model.audit_interface,
            audit_name,
            result.map(declarations, fn(declarations) {
              audit_interface.gather_interface_data(
                declarations,
                case dict.get(model.audit_metadata, audit_name) {
                  Ok(Ok(metadata)) -> metadata.in_scope_files
                  _ -> []
                },
              )
            }),
          ),
        ),
        effect.none(),
      )
    }

    ClientFetchedMergedTopics(audit_name:, merged_topics:) -> {
      case merged_topics {
        Ok(..) -> io.println("Successfully fetched merged topics")
        Error(e) -> {
          io.println_error(
            "Failed to fetch merged topics: " <> string.inspect(e),
          )
        }
      }

      let merged_topics = merged_topics |> result.map(dict.from_list)

      #(
        Model(
          ..model,
          merged_topics: dict.insert(
            model.merged_topics,
            audit_name,
            merged_topics,
          ),
          discussions: dict.upsert(
            model.discussions,
            audit_name,
            fn(discussions) {
              let discussions = option.unwrap(discussions, dict.new())
              case merged_topics {
                Ok(merged_topics) ->
                  discussion_topic.build_merged_topics(
                    discussions,
                    merged_topics,
                    get_combined_topics: discussion_topic.get_combined_discussion,
                  )
                Error(..) -> discussions
              }
            },
          ),
          audit_declarations: dict.upsert(
            model.audit_declarations,
            audit_name,
            fn(audit_declarations) {
              audit_declarations
              |> option.unwrap(Ok(dict.new()))
              |> result.map(fn(audit_declarations) {
                case merged_topics {
                  Ok(merged_topics) ->
                    discussion_topic.build_merged_topics(
                      audit_declarations,
                      merged_topics,
                      get_combined_topics: discussion_topic.get_combined_declaration,
                    )
                  Error(..) -> audit_declarations
                }
              })
            },
          ),
        ),
        effect.none(),
      )
    }

    ServerUpdatedMergedTopics(audit_name) -> #(
      model,
      fetch_merged_topics(audit_name),
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
                |> list.group(by: fn(note) { note.parent_id })
                |> discussion_topic.build_merged_topics(
                  case dict.get(model.merged_topics, audit_name) {
                    Ok(Ok(merged_topics)) -> merged_topics
                    _ -> dict.new()
                  },
                  get_combined_topics: discussion_topic.get_combined_discussion,
                ),
            ),
          ),
          effect.none(),
        )
        Error(e) -> {
          io.println_error("Failed to fetch discussion: " <> string.inspect(e))
          #(model, effect.none())
        }
      }

    ServerUpdatedDiscussion(audit_name:) -> #(
      model,
      fetch_discussion(audit_name),
    )

    UserEnteredKey(browser_event:) -> {
      // If we have a selected discussion, use that as the active line and
      // column numbers so we can activate it with keyboard shortcuts
      let #(active_line_number, active_column_number) = case
        get_selected_discussion_key(model)
      {
        option.Some(discussion_key) -> #(
          discussion_key.line_number,
          discussion_key.column_number,
        )
        option.None -> #(
          model.keyboard_model.cursor_line_number,
          model.keyboard_model.cursor_column_number,
        )
      }

      let #(keyboard_model, effect) =
        page_navigation.do_page_navigation(
          browser_event,
          page_navigation.Model(
            ..model.keyboard_model,
            active_line_number:,
            active_column_number:,
          ),
        )
      #(Model(..model, keyboard_model:), effect)
    }

    UserSelectedDiscussionEntry(
      kind:,
      view_id:,
      line_number:,
      column_number:,
      node_id:,
      topic_id:,
      is_reference:,
    ) -> {
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

      let selected_discussion_key =
        DiscussionKey(view_id:, line_number:, column_number:)

      let discussion_models = case
        dict.get(model.discussion_models, selected_discussion_key)
      {
        Ok(..) -> model.discussion_models
        Error(Nil) ->
          dict.insert(
            model.discussion_models,
            selected_discussion_key,
            discussion.init(
              view_id:,
              line_number:,
              column_number:,
              topic_id:,
              is_reference:,
              declarations:,
            ),
          )
      }

      #(
        case kind {
          discussion.Hover ->
            Model(
              ..model,
              selected_discussion: option.Some(selected_discussion_key),
              discussion_models:,
              selected_node_id: node_id,
            )
          discussion.Focus ->
            Model(
              ..model,
              focused_discussion: option.Some(selected_discussion_key),
              discussion_models:,
              selected_node_id: node_id,
              keyboard_model: page_navigation.Model(
                ..model.keyboard_model,
                cursor_line_number: line_number,
                cursor_column_number: column_number,
              ),
              stickied_discussion: option.None,
            )
        },
        case kind {
          discussion.Hover ->
            effect.from(fn(dispatch) {
              let timer_id =
                global.set_timeout(300, fn() {
                  dispatch(ClientSetStickyDiscussion(
                    view_id:,
                    line_number:,
                    column_number:,
                  ))
                })
              dispatch(UserStartedStickyOpenTimer(timer_id))
            })
          discussion.Focus -> effect.none()
        },
      )
    }

    UserUnselectedDiscussionEntry(kind:) -> {
      #(
        case kind {
          discussion.Hover ->
            Model(
              ..model,
              selected_discussion: option.None,
              selected_node_id: option.None,
            )
          discussion.Focus ->
            Model(
              ..model,
              focused_discussion: option.None,
              clicked_discussion: option.None,
              selected_node_id: option.None,
            )
        },
        effect.from(fn(_dispatch) {
          case model.selected_discussion_set_sticky_timer {
            option.Some(timer_id) -> {
              global.clear_timeout(timer_id)
            }
            option.None -> Nil
          }
        }),
      )
    }

    UserStartedStickyOpenTimer(timer_id) -> {
      #(
        Model(
          ..model,
          selected_discussion_set_sticky_timer: option.Some(timer_id),
        ),
        effect.none(),
      )
    }

    ClientSetStickyDiscussion(view_id:, line_number:, column_number:) -> {
      #(
        Model(
          ..model,
          stickied_discussion: option.Some(DiscussionKey(
            view_id:,
            line_number:,
            column_number:,
          )),
          selected_discussion_set_sticky_timer: option.None,
        ),
        effect.none(),
      )
    }

    UserUnhoveredInsideDiscussion(view_id:, line_number:, column_number:) -> {
      echo "User unhovered discussion entry " <> int.to_string(line_number)
      #(model, case model.stickied_discussion {
        option.Some(discussion_key) ->
          case
            line_number == discussion_key.line_number
            && column_number == discussion_key.column_number
            && view_id == discussion_key.view_id
          {
            True ->
              effect.from(fn(dispatch) {
                let timer_id =
                  global.set_timeout(200, fn() {
                    echo "Unsticking discussion"
                    dispatch(ClientUnsetStickyDiscussion)
                  })
                dispatch(UserStartedStickyCloseTimer(timer_id))
              })
            False -> effect.none()
          }
        option.None -> effect.none()
      })
    }

    UserHoveredInsideDiscussion(view_id:, line_number:, column_number:) -> {
      echo "User hovered discussion entry " <> int.to_string(line_number)
      // Do not clear the timer in the state generically without checking the
      // hovered line and col number here, as hovering any element will clear 
      // the timer if so
      #(model, case model.stickied_discussion {
        option.Some(discussion_key) ->
          case
            line_number == discussion_key.line_number
            && column_number == discussion_key.column_number
            && view_id == discussion_key.view_id
          {
            True ->
              effect.from(fn(_dispatch) {
                case model.stickied_discussion_unset_sticky_timer {
                  option.Some(timer_id) -> {
                    global.clear_timeout(timer_id)
                  }
                  option.None -> Nil
                }
              })
            False -> effect.none()
          }
        option.None -> effect.none()
      })
    }

    UserStartedStickyCloseTimer(timer_id) -> {
      echo "User started sticky close timer"
      #(
        Model(
          ..model,
          stickied_discussion_unset_sticky_timer: option.Some(timer_id),
        ),
        effect.none(),
      )
    }

    ClientUnsetStickyDiscussion -> {
      #(
        Model(
          ..model,
          stickied_discussion: option.None,
          stickied_discussion_unset_sticky_timer: option.None,
        ),
        effect.none(),
      )
    }

    UserClickedDiscussionEntry(view_id:, line_number:, column_number:) -> {
      #(
        Model(
          ..model,
          clicked_discussion: option.Some(DiscussionKey(
            view_id:,
            line_number:,
            column_number:,
          )),
          stickied_discussion: option.None,
        ),
        effect.from(fn(_dispatch) {
          let res =
            selectors.discussion_input(view_id:, line_number:, column_number:)
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

    UserClickedInsideDiscussion(view_id:, line_number:, column_number:) -> {
      echo "User clicked inside discussion"
      let model = case
        model.selected_discussion
        != option.Some(DiscussionKey(view_id:, line_number:, column_number:))
      {
        True -> Model(..model, selected_discussion: option.None)
        False -> model
      }

      let model = case
        model.focused_discussion
        != option.Some(DiscussionKey(view_id:, line_number:, column_number:))
      {
        True -> Model(..model, focused_discussion: option.None)
        False -> model
      }

      let model = case
        model.clicked_discussion
        != option.Some(DiscussionKey(view_id:, line_number:, column_number:))
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

    UserUpdatedDiscussion(view_id:, line_number:, column_number:, update:) -> {
      let #(discussion_model, discussion_effect) = update

      case discussion_effect {
        discussion.SubmitNote(note_submission, topic_id) -> #(
          model,
          case model.route {
            AuditPageRoute(audit_name:, ..)
            | AuditDashboardRoute(audit_name:)
            | AuditInterfaceRoute(audit_name:) -> {
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

        discussion.FocusDiscussionInput(view_id:, line_number:, column_number:) -> {
          echo "Focusing discussion input, user is typing"
          storage.set_is_user_typing(True)
          #(
            Model(
              ..model,
              focused_discussion: option.Some(DiscussionKey(
                view_id:,
                line_number:,
                column_number:,
              )),
            ),
            effect.none(),
          )
        }

        discussion.FocusExpandedDiscussionInput(
          view_id:,
          line_number:,
          column_number:,
        ) -> {
          storage.set_is_user_typing(True)
          #(
            Model(
              ..model,
              focused_discussion: option.Some(DiscussionKey(
                view_id:,
                line_number:,
                column_number:,
              )),
            ),
            effect.none(),
          )
        }

        discussion.UnfocusDiscussionInput(
          _view_id,
          _line_number,
          _column_number,
        ) -> {
          echo "Unfocusing discussion input"
          storage.set_is_user_typing(False)
          #(model, effect.none())
        }

        discussion.MaximizeDiscussion(_view_id, _line_number, _column_number)
        | discussion.None -> #(
          Model(
            ..model,
            discussion_models: dict.insert(
              model.discussion_models,
              DiscussionKey(view_id:, line_number:, column_number:),
              discussion_model,
            ),
          ),
          effect.none(),
        )
      }
    }

    UserSuccessfullySubmittedNote(updated_model) -> {
      #(
        Model(
          ..model,
          discussion_models: dict.insert(
            model.discussion_models,
            DiscussionKey(
              view_id: updated_model.view_id,
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
    AuditDashboardRoute(audit_name:) | AuditInterfaceRoute(audit_name:) ->
      effect.batch([
        fetch_metadata(model, audit_name),
        fetch_declarations(audit_name),
        fetch_discussion(audit_name),
        fetch_merged_topics(audit_name),
      ])
    AuditPageRoute(audit_name:, page_path:) ->
      effect.batch([
        fetch_metadata(model, audit_name),
        fetch_source_file(model, page_path),
        fetch_declarations(audit_name),
        fetch_discussion(audit_name),
        fetch_merged_topics(audit_name),
      ])
    O11aHomeRoute -> effect.none()
  }
}

fn fetch_metadata(model: Model, audit_name: String) {
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

fn fetch_source_file(model: Model, page_path: String) {
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
      decode.list(preprocessor.declaration_decoder()),
      ClientFetchedDeclarations(audit_name, _),
    ),
  )
}

fn fetch_merged_topics(audit_name) {
  lustre_http.get(
    "/audit-merged-topics/" <> audit_name,
    lustre_http.expect_json(
      decode.list(discussion_topic.topic_merge_decoder()),
      ClientFetchedMergedTopics(audit_name, _),
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

    AuditInterfaceRoute(audit_name:) -> {
      let interface_data = case dict.get(model.audit_interface, audit_name) {
        Ok(Ok(data)) -> data
        _ -> audit_interface.empty_interface_data
      }

      let declarations = case dict.get(model.audit_declarations, audit_name) {
        Ok(Ok(declarations)) -> declarations
        _ -> dict.new()
      }

      let discussion =
        dict.get(model.discussions, audit_name)
        |> result.unwrap(dict.new())

      html.div([], [
        server_component.element(
          [server_component.route("/component-discussion/" <> audit_name)],
          [],
        ),
        audit_tree.view(
          audit_interface.view(
            interface_data,
            audit_name,
            declarations,
            discussion,
          ),
          option.None,
          model.file_tree,
          audit_name,
          audit_tree.interface_path(for: audit_name),
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

      let declarations = case dict.get(model.audit_declarations, audit_name) {
        Ok(Ok(declarations)) -> declarations
        _ -> dict.new()
      }

      html.div([event.on_click(UserClickedOutsideDiscussion)], [
        selected_node_highlighter(model),
        server_component.element(
          [
            server_component.route("/component-discussion/" <> audit_name),
            on_server_updated_discussion(ServerUpdatedDiscussion),
            on_server_updated_topics(ServerUpdatedMergedTopics),
          ],
          [],
        ),
        audit_tree.view(
          audit_page.view(
            preprocessed_source:,
            discussion:,
            declarations:,
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

fn get_selected_discussion_key(model: Model) {
  case
    model.focused_discussion,
    model.clicked_discussion,
    model.stickied_discussion,
    model.selected_discussion
  {
    option.Some(discussion), _, _, _
    | _, option.Some(discussion), _, _
    | _, _, option.Some(discussion), _
    | _, _, _, option.Some(discussion)
    -> option.Some(discussion)
    option.None, option.None, option.None, option.None -> option.None
  }
}

fn get_selected_discussion(model: Model) {
  case get_selected_discussion_key(model) {
    option.Some(discussion) ->
      dict.get(model.discussion_models, discussion)
      |> result.map(fn(model) {
        option.Some(discussion.DiscussionReference(
          view_id: discussion.view_id,
          line_number: discussion.line_number,
          column_number: discussion.column_number,
          model:,
        ))
      })
      |> result.unwrap(option.None)
    option.None -> option.None
  }
}

fn on_server_updated_discussion(msg) {
  event.on(events.server_updated_discussion, {
    use audit_name <- decode.subfield(["detail", "audit_name"], decode.string)
    decode.success(msg(audit_name))
  })
}

fn on_server_updated_topics(msg) {
  event.on(events.server_updated_topics, {
    use audit_name <- decode.subfield(["detail", "audit_name"], decode.string)
    decode.success(msg(audit_name))
  })
}

fn map_audit_page_msg(msg) {
  case msg {
    discussion.UserSelectedDiscussionEntry(
      view_id:,
      kind:,
      line_number:,
      column_number:,
      node_id:,
      topic_id:,
      is_reference:,
    ) ->
      UserSelectedDiscussionEntry(
        kind:,
        view_id:,
        line_number:,
        column_number:,
        node_id:,
        topic_id:,
        is_reference:,
      )
    discussion.UserUnselectedDiscussionEntry(kind:) ->
      UserUnselectedDiscussionEntry(kind:)
    discussion.UserClickedDiscussionEntry(
      view_id:,
      line_number:,
      column_number:,
    ) -> UserClickedDiscussionEntry(view_id:, line_number:, column_number:)
    discussion.UserUpdatedDiscussion(
      view_id:,
      line_number:,
      column_number:,
      update:,
    ) -> UserUpdatedDiscussion(view_id:, line_number:, column_number:, update:)
    discussion.UserClickedInsideDiscussion(
      view_id:,
      line_number:,
      column_number:,
    ) -> UserClickedInsideDiscussion(view_id:, line_number:, column_number:)
    discussion.UserCtrlClickedNode(uri:) -> UserCtrlClickedNode(uri:)
    discussion.UserHoveredInsideDiscussion(
      view_id:,
      line_number:,
      column_number:,
    ) -> UserHoveredInsideDiscussion(view_id:, line_number:, column_number:)
    discussion.UserUnhoveredInsideDiscussion(
      view_id:,
      line_number:,
      column_number:,
    ) -> UserUnhoveredInsideDiscussion(view_id:, line_number:, column_number:)
  }
}
