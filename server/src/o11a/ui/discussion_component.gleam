//// This component allows the client to receive the full discussion data over
//// a websocket connection as a server component. The client can then parse
//// the JSON encoded discussion. Eventually this should be replaced with a  
//// direct websocket connection to the server instead of going through this
//// server component, where only updates are streamed instead of the whole
//// discussion every time there is an update.

import concurrent_dict
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/result
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/server_component
import o11a/events
import o11a/note
import o11a/server/discussion
import snag

pub fn app() -> lustre.App(Model, Model, Msg) {
  lustre.component(
    init,
    update,
    view,
    dict.from_list([
      #("note-submission", fn(dy) {
        use note_data <- result.try(
          decode.run(dy, decode.string)
          |> result.replace_error([
            dynamic.DecodeError(
              "json-encoded computed note",
              string.inspect(dy),
              [],
            ),
          ]),
        )

        use #(note, topic_id) <- result.map(
          json.parse(note_data, {
            use topic_id <- decode.field("topic_id", decode.string)
            use note_submission <- decode.field(
              "note_submission",
              note.note_submission_decoder(),
            )

            decode.success(#(note_submission, topic_id))
          })
          |> result.replace_error([
            dynamic.DecodeError(
              "json-encoded note submission",
              string.inspect(note_data),
              [],
            ),
          ]),
        )

        UserSubmittedNote(note, topic_id)
      }),
    ]),
  )
}

pub type Msg {
  ServerUpdatedDiscussion
  UserSubmittedNote(note_submission: note.NoteSubmission, topic_id: String)
}

pub type Model {
  Model(
    discussion: discussion.Discussion,
    skeletons: concurrent_dict.ConcurrentDict(String, String),
  )
}

pub fn init(init_model: Model) -> #(Model, effect.Effect(Msg)) {
  let subscribe_to_note_updates_effect =
    effect.from(fn(dispatch) {
      discussion.subscribe_to_note_updates(init_model.discussion, fn() {
        dispatch(ServerUpdatedDiscussion)
      })
    })

  #(init_model, subscribe_to_note_updates_effect)
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserSubmittedNote(note_submission:, topic_id:) -> {
      case discussion.add_note(model.discussion, note_submission, topic_id:) {
        Ok(Nil) -> Nil
        Error(e) ->
          io.print(
            "Error adding note "
            <> note_submission |> note.encode_note_submission |> json.to_string
            <> " of "
            <> topic_id
            <> ": "
            <> snag.pretty_print(e),
          )
      }
      #(model, effect.none())
    }
    ServerUpdatedDiscussion -> #(
      model,
      server_component.emit(
        events.server_updated_discussion,
        discussion.dump_computed_notes(model.discussion),
      ),
    )
  }
}

fn view(model: Model) -> element.Element(Msg) {
  html.script(
    [attribute.type_("application/json"), attribute.id("discussion-data")],
    discussion.dump_computed_notes(model.discussion) |> json.to_string,
  )
}
