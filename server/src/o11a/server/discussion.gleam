import concurrent_dict
import given
import gleam/dict
import gleam/dynamic/decode
import gleam/function
import gleam/json
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/string
import lib/persistent_concurrent_duplicate_dict as pcd_dict
import lib/persistent_concurrent_structured_dict as pcs_dict
import o11a/computed_note
import o11a/config
import o11a/note
import o11a/preprocessor
import o11a/preprocessor_text
import o11a/topic
import tempo/datetime

pub type MentionCollection {
  MentionCollection(
    mentions_by_self: List(note.NoteStub),
    mentions_to_self: List(note.NoteStub),
  )
}

/// A per-audit discussion
pub type Discussion =
  pcs_dict.PersistentConcurrentStructuredDict(
    String,
    note.NoteSubmission,
    note.Note,
    String,
    List(note.NoteStub),
  )

pub fn build_audit_discussion(
  audit_name: String,
  computed_notes computed_notes: concurrent_dict.ConcurrentDict(
    String,
    topic.Topic,
  ),
  mentions mentions: concurrent_dict.ConcurrentDict(String, MentionCollection),
) {
  use notes <- result.try(
    pcs_dict.build(
      config.get_persist_path(for: audit_name <> "/notes"),
      function.identity,
      function.identity,
      note.build_note,
      note.example_note(),
      note_persist_encoder,
      note_persist_decoder(),
      function.identity,
      function.identity,
      builder: fn(notes_dict, starting_from) {
        build_structured_notes(
          notes_dict,
          starting_from,
          computed_notes:,
          mentions:,
        )
      },
    ),
  )

  notes
  |> Ok
}

pub fn note_persist_encoder(note: note.Note) {
  [
    pcd_dict.text(note.note_id),
    pcd_dict.text(note.parent_id),
    pcd_dict.int(note.note_significance_to_int(note.significance)),
    pcd_dict.text(note.user_name),
    pcd_dict.text(note.message),
    pcd_dict.text_nullable(note.expanded_message),
    pcd_dict.int(datetime.to_unix_milli(note.time)),
    pcd_dict.text(note.modifier |> note.note_modifier_to_string),
    pcd_dict.text(
      json.array(note.referenced_topic_ids, json.string)
      |> json.to_string,
    ),
  ]
}

pub fn note_persist_decoder() {
  use note_id <- decode.field(0, decode.string)
  use parent_id <- decode.field(1, decode.string)
  use significance <- decode.field(2, decode.int)
  use user_name <- decode.field(3, decode.string)
  use message <- decode.field(4, decode.string)
  use expanded_message <- decode.field(5, decode.optional(decode.string))
  use time <- decode.field(6, decode.int)
  use modifier <- decode.field(7, note.note_modifier_decoder())
  use referenced_topic_ids <- decode.field(8, {
    use str <- decode.then(decode.string)
    case json.parse(str, decode.list(decode.string)) {
      Ok(references) -> decode.success(references)
      Error(e) -> decode.failure([], "references - " <> string.inspect(e))
    }
  })

  note.Note(
    note_id:,
    parent_id:,
    significance: note.note_significance_from_int(significance),
    user_name:,
    message:,
    expanded_message:,
    time: datetime.from_unix_milli(time),
    modifier:,
    referenced_topic_ids:,
  )
  |> decode.success
}

pub fn note_vote_persist_encoder(note_vote: note.NoteVote) {
  [
    pcd_dict.text(note_vote.note_id),
    pcd_dict.int(note.note_vote_sigficance_to_int(note_vote.sigficance)),
    pcd_dict.text(note_vote.user_name),
  ]
}

pub fn note_vote_persist_decoder() {
  use note_id <- decode.field(0, decode.string)
  use sigficance <- decode.field(1, decode.int)
  use user_name <- decode.field(2, decode.string)

  note.NoteVote(
    note_id:,
    user_name:,
    sigficance: note.note_vote_sigficance_from_int(sigficance),
  )
  |> decode.success
}

pub fn subscribe_to_note_updates(discussion: Discussion, effect: fn() -> Nil) {
  pcs_dict.subscribe(discussion, effect)
}

pub fn subscribe_to_line_updates(
  discussion: Discussion,
  line_id topic: String,
  run effect: fn() -> Nil,
) {
  pcs_dict.subscribe_to_topic(discussion, topic, effect)
}

pub fn get_notes(discussion: Discussion, line_id topic: String) {
  pcs_dict.get(discussion, topic:)
}

pub fn get_all_notes(discussion: Discussion) {
  pcs_dict.to_list(discussion)
}

fn build_structured_notes(
  notes_dict: pcd_dict.PersistentConcurrentDuplicateDict(
    String,
    note.NoteSubmission,
    note.Note,
  ),
  starting_from topic_id: String,
  computed_notes computed_notes_dict: concurrent_dict.ConcurrentDict(
    String,
    topic.Topic,
  ),
  mentions mentions: concurrent_dict.ConcurrentDict(String, MentionCollection),
) {
  let computed_notes =
    do_build_structured_notes(notes_dict, topic_id, computed_notes_dict)

  list.map(computed_notes, fn(note) {
    #(note.note_id, computed_note_to_topic(note))
  })
  |> concurrent_dict.insert_many(computed_notes_dict, _)

  let prior_mentions =
    list.map(computed_notes, fn(note) {
      {
        concurrent_dict.get(mentions, note.note_id)
        |> result.unwrap(
          MentionCollection(mentions_by_self: [], mentions_to_self: []),
        )
      }.mentions_by_self
      |> list.map(fn(stub) { stub.topic_id })
    })

  let current_mentions =
    list.map(computed_notes, fn(_note) {
      // TODO: map the references in the message and the expanded message
      // and add create a mention stub for each
      let mention_subs = []
      mention_subs
      // TODO: Add the mentions to the mentions by self properties of the 
      // mentions dict, then remove any old mentions that are no longer valid 
      // from the mentions to self properties of past mentioned topics. This
      // cannot be done with a concurrent dict, a new syncronized dict
      // will be needed.
    })

  let dependent_topics =
    list.unique(list.append(prior_mentions, current_mentions) |> list.flatten)

  let dependent_computed_notes =
    list.map(dependent_topics, fn(topic_id) {
      // We have to either do a full rebuild or get the previous computed notes
      // or stubs from somewhere, as plain notes can be deleted. If we try to
      // to a lighter version of this function where we don't recompute the
      // notes, but just build the stubs, we may end up adding back deleted
      // notes.
      do_build_structured_notes(notes_dict, topic_id, computed_notes_dict)
    })
    |> list.flatten

  list.append(computed_notes, dependent_computed_notes)
  |> list.map(fn(note) {
    [
      #(
        note.parent_id,
        note.NoteStub(
          topic_id: note.note_id,
          time: note.time,
          kind: note.CommentNoteStub,
        ),
      ),
      ..{
        concurrent_dict.get(mentions, note.note_id)
        |> result.unwrap(
          MentionCollection(mentions_by_self: [], mentions_to_self: []),
        )
      }.mentions_to_self
      |> list.map(fn(stub) { #(note.note_id, stub) })
    ]
    |> list.sort(fn(a, b) { datetime.compare({ a.1 }.time, { b.1 }.time) })
  })
  |> list.flatten
  |> list.group(by: fn(stub) { stub.0 })
  |> dict.map_values(fn(_key, stub_data) {
    list.map(stub_data, fn(stub_data) { stub_data.1 })
  })
  |> dict.to_list
}

fn do_build_structured_notes(
  notes_dict: pcd_dict.PersistentConcurrentDuplicateDict(
    String,
    note.NoteSubmission,
    note.Note,
  ),
  topic_id topic_id: String,
  topics topics: concurrent_dict.ConcurrentDict(String, topic.Topic),
) {
  let notes = pcd_dict.get(notes_dict, topic_id)

  let computed_notes =
    list.filter(notes, fn(note) {
      note.modifier != note.Edit && note.modifier != note.Delete
    })
    |> list.filter_map(fn(note) {
      computed_note_from_note(
        note,
        pcd_dict.get(notes_dict, note.note_id),
        topics,
      )
    })

  case computed_notes {
    [] -> []
    _ ->
      list.map(computed_notes, fn(computed_note) {
        do_build_structured_notes(notes_dict, computed_note.note_id, topics:)
      })
      |> list.flatten
      |> list.append(computed_notes)
  }
}

fn computed_note_to_topic(computed_note: computed_note.ComputedNote) {
  topic.ComputedNote(topic_id: computed_note.note_id, computed_note:)
}

pub fn dump_computed_notes(discussion: Discussion) {
  let notes = pcs_dict.to_list(discussion)

  json.array(notes, fn(note) {
    json.preprocessed_array([
      json.string(note.0),
      json.array(note.1, note.note_stub_to_json),
    ])
  })
}

pub fn dump_computed_notes_since(discussion: Discussion, since ref_time) {
  let notes =
    pcs_dict.to_list(discussion)
    |> list.map(pair.second)
    |> list.flatten
    |> list.filter(fn(note) {
      note.time |> datetime.is_later_or_equal(to: ref_time)
    })

  json.array(notes, note.note_stub_to_json)
}

fn computed_note_from_note(
  original_note: note.Note,
  thread_notes: List(note.Note),
  topics: concurrent_dict.ConcurrentDict(String, topic.Topic),
) {
  // When we are searching for compound values, search from the end of the
  // list first to get the most recently added note.
  let thread_notes =
    list.sort(thread_notes, fn(a, b) { datetime.compare(b.time, a.time) })

  // If the note has been deleted, return a nil error so it can be filtered out
  use Nil <- given.ok(
    list.find(thread_notes, fn(thread_note) {
      thread_note.modifier == note.Delete
    }),
    return: fn(_) { Error(Nil) },
  )

  // Find the most recent edit of the note
  let edited_note =
    list.find(thread_notes, fn(thread_note) {
      thread_note.modifier == note.Edit
    })

  // Update the note with the most recent edited messages, if any
  let #(note, edited) = case edited_note {
    Ok(edit) -> #(
      note.Note(
        ..original_note,
        message: edit.message,
        expanded_message: edit.expanded_message,
        significance: edit.significance,
        referenced_topic_ids: edit.referenced_topic_ids,
      ),
      True,
    )
    Error(Nil) -> #(original_note, False)
  }

  // If this note is a reference note, then it should have a reference to its
  // topic in its references list. If it does not, then an edit must have been
  // made to the note that removed the reference. In this case, return a
  // nil error so it can be filtered out.
  use referee_topic_id <- given.ok(
    case note.modifier {
      note.Reference(referee_topic_id:) ->
        list.find(note.referenced_topic_ids, fn(reference_topic_id) {
          reference_topic_id == note.parent_id
        })
        |> result.replace(option.Some(referee_topic_id))

      _ -> Ok(option.None)
    },
    else_return: fn(_) { Error(Nil) },
  )

  let significance = case note.significance {
    note.Comment -> computed_note.Comment
    note.Question ->
      case
        list.find(thread_notes, fn(thread_note) {
          thread_note.significance == note.Answer
        })
      {
        Ok(..) -> computed_note.AnsweredQuestion
        Error(Nil) -> computed_note.UnansweredQuestion
      }
    note.DevelperQuestion ->
      case
        list.find(thread_notes, fn(thread_note) {
          thread_note.significance == note.Answer
        })
      {
        Ok(..) -> computed_note.AnsweredDeveloperQuestion
        Error(Nil) -> computed_note.UnansweredDeveloperQuestion
      }
    note.Answer -> computed_note.Answer
    note.ToDo ->
      case
        list.find(thread_notes, fn(thread_note) {
          thread_note.significance == note.ToDoCompletion
        })
      {
        Ok(..) -> computed_note.CompleteToDo
        Error(Nil) -> computed_note.IncompleteToDo
      }
    note.ToDoCompletion -> computed_note.ToDoCompletion
    note.FindingLead ->
      case
        list.find_map(thread_notes, fn(thread_note) {
          case thread_note.significance {
            note.FindingRejection -> Ok(computed_note.FindingRejection)
            note.FindingConfirmation -> Ok(computed_note.FindingConfirmation)
            _ -> Error(Nil)
          }
        })
      {
        Ok(computed_note.FindingRejection) -> computed_note.RejectedFinding
        Ok(computed_note.FindingConfirmation) -> computed_note.ConfirmedFinding
        Ok(..) -> computed_note.UnconfirmedFinding
        Error(Nil) -> computed_note.UnconfirmedFinding
      }
    note.FindingConfirmation -> computed_note.FindingConfirmation
    note.FindingRejection -> computed_note.FindingRejection
    note.Informational ->
      case
        list.find_map(thread_notes, fn(thread_note) {
          case thread_note.significance {
            note.InformationalRejection ->
              Ok(computed_note.InformationalRejection)
            note.InformationalConfirmation ->
              Ok(computed_note.InformationalConfirmation)
            _ -> Error(Nil)
          }
        })
      {
        Ok(computed_note.InformationalRejection) ->
          computed_note.RejectedInformational
        Ok(computed_note.InformationalConfirmation) ->
          computed_note.Informational
        Ok(..) -> computed_note.Informational
        Error(Nil) -> computed_note.Informational
      }
    note.InformationalRejection -> computed_note.InformationalRejection
    note.InformationalConfirmation -> computed_note.InformationalConfirmation
  }

  let topics_list = concurrent_dict.to_list(topics) |> list.map(pair.second)

  let #(document, max_topic_id, declarations) =
    preprocessor_text.parse(
      source: note.message,
      document_id: note.note_id,
      document_parent: note.parent_id,
      max_topic_id: 0,
      topics: topics_list,
    )

  let message =
    preprocessor_text.preprocess_source(document, topics_list)
    |> list.map(fn(line) { preprocessor.TextSnippetLine(line.elements) })

  let #(expanded_message, expanded_declarations) = case note.expanded_message {
    option.Some(expanded_message) -> {
      let #(document, _max_topic_id, declarations) =
        preprocessor_text.parse(
          source: expanded_message,
          document_id: note.note_id,
          document_parent: note.parent_id,
          max_topic_id:,
          topics: topics_list,
        )

      let expanded_message =
        preprocessor_text.preprocess_source(document, topics_list)
        |> list.map(fn(line) { preprocessor.TextSnippetLine(line.elements) })
        |> option.Some

      #(expanded_message, declarations)
    }
    option.None -> #(option.None, dict.new())
  }

  let _all_declarations =
    dict.merge(declarations, expanded_declarations)
    |> dict.to_list
    |> concurrent_dict.insert_many(topics, _)

  Ok(computed_note.ComputedNote(
    note_id: note.note_id,
    parent_id: note.parent_id,
    significance:,
    user_name: note.user_name,
    message:,
    message_text: note.message,
    expanded_message: expanded_message,
    expanded_message_text: note.expanded_message,
    time: note.time,
    edited:,
    referenced_topic_ids: note.referenced_topic_ids,
    referee_topic_id:,
  ))
}
