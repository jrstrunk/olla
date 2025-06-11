import gleam/dict
import plinth/browser/clipboard
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
import rsvp

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
      Result(audit_metadata.AuditMetaData, rsvp.Error),
    ),
    source_files: dict.Dict(
      String,
      Result(List(preprocessor.PreProcessedLine), rsvp.Error),
    ),
    audit_declarations: dict.Dict(
      String,
      Result(dict.Dict(String, preprocessor.Declaration), rsvp.Error),
    ),
    audit_declaration_lists: dict.Dict(
      String,
      Result(List(preprocessor.Declaration), rsvp.Error),
    ),
    audit_interface: dict.Dict(
      String,
      Result(audit_interface.InterfaceData, rsvp.Error),
    ),
    merged_topics: dict.Dict(
      String,
      Result(dict.Dict(String, String), rsvp.Error),
    ),
    discussions: dict.Dict(
      String,
      dict.Dict(String, List(computed_note.ComputedNote)),
    ),
    discussion_models: dict.Dict(
      discussion.DiscussionId,
      discussion.DiscussionOverlayModel,
    ),
    keyboard_model: page_navigation.Model,
    selected_node_id: option.Option(Int),
    active_discussions: dict.Dict(String, discussion.DiscussionControllerModel),
    set_sticky_discussion_timer: option.Option(global.TimerID),
    unset_sticky_discussion_timer: option.Option(global.TimerID),
  )
}

pub type Route {
  O11aHomeRoute
  AuditDashboardRoute(audit_name: String)
  AuditInterfaceRoute(audit_name: String)
  AuditPageRoute(audit_name: String, page_path: String)
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
      active_discussions: dict.new(),
      selected_node_id: option.None,
      set_sticky_discussion_timer: option.None,
      unset_sticky_discussion_timer: option.None,
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
    Result(audit_metadata.AuditMetaData, rsvp.Error),
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

pub fn get_page_view_id_from_route(route) {
  case route {
    AuditDashboardRoute(..) -> "dashboard"
    AuditInterfaceRoute(..) -> audit_interface.view_id
    AuditPageRoute(..) -> audit_page.view_id
    O11aHomeRoute -> "o11a"
  }
}

pub type Msg {
  OnRouteChange(route: Route)
  ClientFetchedAuditMetadata(
    audit_name: String,
    metadata: Result(audit_metadata.AuditMetaData, rsvp.Error),
  )
  ClientFetchedSourceFile(
    page_path: String,
    source_file: Result(List(preprocessor.PreProcessedLine), rsvp.Error),
  )
  ClientFetchedDeclarations(
    audit_name: String,
    declarations: Result(List(preprocessor.Declaration), rsvp.Error),
  )
  ClientFetchedMergedTopics(
    audit_name: String,
    merged_topics: Result(List(#(String, String)), rsvp.Error),
  )
  ClientFetchedDiscussion(
    audit_name: String,
    discussion: Result(List(computed_note.ComputedNote), rsvp.Error),
  )
  ServerUpdatedMergedTopics(audit_name: String)
  ServerUpdatedDiscussion(audit_name: String)
  UserEnteredKey(
    browser_event: browser_event.Event(
      browser_event.UIEvent(browser_event.KeyboardEvent),
    ),
  )
  DiscussionControllerSentMsg(msg: discussion.DiscussionControllerMsg)
  UserSuccessfullySubmittedNote(
    updated_model: discussion.DiscussionOverlayModel,
  )
  UserFailedToSubmitNote(error: rsvp.Error)
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
            cursor_view_id: get_page_view_id_from_route(model.route) |> echo,
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

    ClientFetchedSourceFile(page_path, source_file) -> {
      case source_file {
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
          source_files: dict.insert(model.source_files, page_path, source_file),
          keyboard_model: page_navigation.Model(
            ..model.keyboard_model,
            // TODO: this seems to not be right, we don't fetch the source file
            // every time we navigate
            line_count: case source_file {
              Ok(source_file) -> list.length(source_file)
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
      let #(keyboard_model, effect) =
        page_navigation.do_page_navigation(browser_event, model.keyboard_model)
      #(Model(..model, keyboard_model:), effect)
    }

    DiscussionControllerSentMsg(msg) ->
      case msg {
        discussion.UserSelectedDiscussionEntry(
          kind:,
          discussion_id:,
          node_id:,
          topic_id:,
          is_reference:,
        ) -> {
          let discussion_models = case
            dict.get(model.discussion_models, discussion_id)
          {
            Ok(..) -> model.discussion_models
            Error(Nil) ->
              dict.insert(
                model.discussion_models,
                discussion_id,
                discussion.init(
                  view_id: discussion.nested_view_id(discussion_id),
                  discussion_id:,
                  topic_id:,
                  is_reference:,
                ),
              )
          }

          #(
            case kind {
              discussion.Hover ->
                Model(
                  ..model,
                  active_discussions: dict.upsert(
                    model.active_discussions,
                    discussion_id.view_id,
                    discussion.set_hovered_discussion(_, discussion_id),
                  ),
                  discussion_models:,
                  selected_node_id: node_id,
                  keyboard_model: page_navigation.Model(
                    ..model.keyboard_model,
                    active_view_id: discussion_id.view_id,
                    active_line_number: discussion_id.line_number,
                    active_column_number: discussion_id.column_number,
                  ),
                )
              discussion.Focus ->
                Model(
                  ..model,
                  active_discussions: dict.upsert(
                    model.active_discussions,
                    discussion_id.view_id,
                    discussion.set_focused_discussion(_, discussion_id),
                  ),
                  discussion_models:,
                  selected_node_id: node_id,
                  keyboard_model: page_navigation.Model(
                    ..model.keyboard_model,
                    active_view_id: discussion_id.view_id,
                    active_line_number: discussion_id.line_number,
                    active_column_number: discussion_id.column_number,
                    cursor_view_id: discussion_id.view_id,
                    cursor_line_number: discussion_id.line_number,
                    cursor_column_number: discussion_id.column_number,
                  ),
                )
            },
            case kind {
              discussion.Hover ->
                effect.from(fn(dispatch) {
                  let timer_id =
                    global.set_timeout(300, fn() {
                      dispatch(
                        DiscussionControllerSentMsg(
                          discussion.ClientSetStickyDiscussion(discussion_id:),
                        ),
                      )
                    })
                  dispatch(
                    DiscussionControllerSentMsg(
                      discussion.UserStartedStickyOpenTimer(timer_id),
                    ),
                  )
                })
              discussion.Focus -> effect.none()
            },
          )
        }

        discussion.UserUnselectedDiscussionEntry(kind:, discussion_id:) -> {
          #(
            case kind {
              discussion.Hover ->
                Model(
                  ..model,
                  active_discussions: dict.upsert(
                    model.active_discussions,
                    discussion_id.view_id,
                    discussion.unset_hovered_discussion,
                  ),
                  selected_node_id: option.None,
                )
              discussion.Focus ->
                Model(
                  ..model,
                  active_discussions: dict.upsert(
                    model.active_discussions,
                    discussion_id.view_id,
                    discussion.unset_focused_discussion,
                  ),
                  selected_node_id: option.None,
                )
            },
            effect.from(fn(_dispatch) {
              case model.set_sticky_discussion_timer {
                option.Some(timer_id) -> {
                  global.clear_timeout(timer_id)
                }
                option.None -> Nil
              }
            }),
          )
        }

        discussion.UserStartedStickyOpenTimer(timer_id) -> {
          #(
            Model(..model, set_sticky_discussion_timer: option.Some(timer_id)),
            effect.none(),
          )
        }

        discussion.ClientSetStickyDiscussion(discussion_id:) -> {
          #(
            Model(
              ..model,
              active_discussions: dict.upsert(
                model.active_discussions,
                discussion_id.view_id,
                discussion.set_stickied_discussion(_, discussion_id),
              ),
              set_sticky_discussion_timer: option.None,
            ),
            effect.none(),
          )
        }

        discussion.UserUnhoveredInsideDiscussion(discussion_id:) -> {
          #(
            model,
            case dict.get(model.active_discussions, discussion_id.view_id) {
              Ok(model) ->
                case model.stickied_discussion {
                  option.Some(sticky_discussion_id) ->
                    case discussion_id == sticky_discussion_id {
                      True ->
                        effect.from(fn(dispatch) {
                          let timer_id =
                            global.set_timeout(200, fn() {
                              echo "Unsticking discussion"
                              dispatch(
                                DiscussionControllerSentMsg(
                                  discussion.ClientUnsetStickyDiscussion(
                                    discussion_id:,
                                  ),
                                ),
                              )
                            })
                          dispatch(
                            DiscussionControllerSentMsg(
                              discussion.UserStartedStickyCloseTimer(timer_id:),
                            ),
                          )
                        })
                      False -> effect.none()
                    }
                  option.None -> effect.none()
                }
              Error(Nil) -> effect.none()
            },
          )
        }

        discussion.UserHoveredInsideDiscussion(discussion_id:) -> {
          echo "User hovered discussion entry "
            <> int.to_string(discussion_id.line_number)
            <> " "
            <> int.to_string(discussion_id.column_number)
            <> " "
            <> discussion_id.view_id
          // Do not clear the timer in the state generically without checking the
          // hovered line and col number here, as hovering any element will clear 
          // the timer if so
          #(
            model,
            case dict.get(model.active_discussions, discussion_id.view_id) {
              Ok(discussion_model) ->
                case discussion_model.stickied_discussion {
                  option.Some(sticky_discussion_id) ->
                    case sticky_discussion_id == discussion_id {
                      True ->
                        effect.from(fn(_dispatch) {
                          case model.unset_sticky_discussion_timer {
                            option.Some(timer_id) -> {
                              global.clear_timeout(timer_id)
                            }
                            option.None -> Nil
                          }
                        })
                      False -> effect.none()
                    }
                  option.None -> effect.none()
                }
              Error(Nil) -> effect.none()
            },
          )
        }

        discussion.UserStartedStickyCloseTimer(timer_id) -> {
          echo "User started sticky close timer"
          #(
            Model(..model, unset_sticky_discussion_timer: option.Some(timer_id)),
            effect.none(),
          )
        }

        discussion.ClientUnsetStickyDiscussion(discussion_id:) -> {
          #(
            Model(
              ..model,
              active_discussions: dict.upsert(
                model.active_discussions,
                discussion_id.view_id,
                discussion.unset_stickied_discussion,
              ),
              unset_sticky_discussion_timer: option.None,
            ),
            effect.none(),
          )
        }

        discussion.UserClickedDiscussionEntry(discussion_id:) -> {
          #(
            Model(
              ..model,
              active_discussions: dict.upsert(
                model.active_discussions,
                discussion_id.view_id,
                discussion.set_clicked_discussion(_, discussion_id),
              ),
            ),
            effect.from(fn(_dispatch) {
              let res =
                selectors.discussion_input(
                  view_id: discussion_id.view_id,
                  line_number: discussion_id.line_number,
                  column_number: discussion_id.column_number,
                )
                |> result.map(browser_element.focus)

              case res {
                Ok(Nil) -> Nil
                Error(Nil) -> io.println("Failed to focus discussion input")
              }
            }),
          )
        }

        discussion.UserCtrlClickedNode(uri) -> {
          // TODO as "set cursor to the new definition"
          let #(path, fragment) = case string.split_once(uri, "#") {
            Ok(#(uri, fragment)) -> #(uri, option.Some(fragment))
            Error(..) -> #(uri, option.None)
          }
          let path = "/" <> path

          #(model, modem.push(path, option.None, fragment))
        }

        discussion.UserClickedInsideDiscussion(discussion_id:) -> {
          echo "User clicked inside discussion"

          #(
            Model(
              ..model,
              active_discussions: model.active_discussions
                // Close any discussions that are open as a child of this view
                |> discussion.close_all_child_discussions(
                  discussion.nested_view_id(discussion_id),
                )
                // Set the current discussion as clicked so it stays open now
                |> dict.upsert(
                  discussion_id.view_id,
                  discussion.set_clicked_discussion(_, discussion_id),
                ),
            ),
            effect.none(),
          )
        }

        discussion.UserClickedOutsideDiscussion(view_id:) -> {
          echo "User clicked outside discussion"
          #(
            Model(
              ..model,
              active_discussions: discussion.close_all_child_discussions(
                model.active_discussions,
                view_id,
              ),
            ),
            effect.none(),
          )
        }

        discussion.UserUpdatedDiscussion(discussion_model, discussion_msg) -> {
          let #(discussion_model, effect) =
            discussion.update(discussion_model, discussion_msg)

          case effect {
            discussion.SubmitNote(note_submission, topic_id) -> {
              #(model, case model.route {
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
              })
            }

            discussion.FocusDiscussionInput(_discussion_id) -> {
              echo "Focusing discussion input, user is typing"
              storage.set_is_user_typing(True)
              #(
                Model(
                  ..model,
                  active_discussions: dict.upsert(
                    model.active_discussions,
                    discussion_model.discussion_id.view_id,
                    discussion.set_focused_discussion(
                      _,
                      discussion_model.discussion_id,
                    ),
                  ),
                ),
                effect.none(),
              )
            }

            discussion.FocusExpandedDiscussionInput(_discussion_id) -> {
              storage.set_is_user_typing(True)
              #(
                Model(
                  ..model,
                  active_discussions: dict.upsert(
                    model.active_discussions,
                    discussion_model.discussion_id.view_id,
                    discussion.set_focused_discussion(
                      _,
                      discussion_model.discussion_id,
                    ),
                  ),
                ),
                effect.none(),
              )
            }

            discussion.UnfocusDiscussionInput(_discussion_id) -> {
              echo "Unfocusing discussion input"
              storage.set_is_user_typing(False)
              #(model, effect.none())
            }

            discussion.MaximizeDiscussion(_discussion_id) -> {
              #(
                Model(
                  ..model,
                  discussion_models: dict.insert(
                    model.discussion_models,
                    discussion_model.discussion_id,
                    discussion_model,
                  ),
                ),
                effect.none(),
              )
            }

            discussion.CopyDeclarationId(declaration_id) -> #(
              model,
              effect.from(fn(_dispatch) {
                clipboard.write_text(declaration_id)
                Nil
              }),
            )

            discussion.None -> #(
              Model(
                ..model,
                discussion_models: dict.insert(
                  model.discussion_models,
                  discussion_model.discussion_id,
                  discussion_model,
                ),
              ),
              effect.none(),
            )
          }
        }
      }

    UserSuccessfullySubmittedNote(updated_model) -> {
      #(
        Model(
          ..model,
          discussion_models: dict.insert(
            model.discussion_models,
            updated_model.discussion_id,
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
      rsvp.get(
        "/audit-metadata/" <> audit_name,
        rsvp.expect_json(
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
      rsvp.get(
        "/source-file/" <> page_path,
        rsvp.expect_json(
          decode.list(preprocessor.pre_processed_line_decoder()),
          ClientFetchedSourceFile(page_path, _),
        ),
      )
  }
}

fn fetch_declarations(audit_name) {
  rsvp.get(
    "/audit-declarations/" <> audit_name,
    rsvp.expect_json(
      decode.list(preprocessor.declaration_decoder()),
      ClientFetchedDeclarations(audit_name, _),
    ),
  )
}

fn fetch_merged_topics(audit_name) {
  rsvp.get(
    "/audit-merged-topics/" <> audit_name,
    rsvp.expect_json(
      decode.list(discussion_topic.topic_merge_decoder()),
      ClientFetchedMergedTopics(audit_name, _),
    ),
  )
}

fn fetch_discussion(audit_name) {
  rsvp.get(
    "/audit-discussion/" <> audit_name,
    rsvp.expect_json(
      decode.list(computed_note.computed_note_decoder()),
      ClientFetchedDiscussion(audit_name, _),
    ),
  )
}

fn submit_note(audit_name, topic_id, note_submission, discussion_model) {
  rsvp.post(
    "/submit-note/" <> audit_name,
    json.object([
      #("topic_id", json.string(topic_id)),
      #("note_submission", note.encode_note_submission(note_submission)),
    ]),
    rsvp.expect_json(
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
  let discussion_context =
    discussion.DiscussionContext(
      active_discussions: model.active_discussions,
      dicsussion_models: model.discussion_models,
    )

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
            discussion_context,
          )
            |> element.map(DiscussionControllerSentMsg),
          option.None,
          model.file_tree,
          audit_name,
          audit_tree.interface_path(for: audit_name),
        ),
      ])
    }

    AuditPageRoute(audit_name:, page_path:) -> {
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

      html.div([], [
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
            discussion_context:,
          )
            |> element.map(DiscussionControllerSentMsg),
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
