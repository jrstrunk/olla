import gleam/int
import gleam/io
import gleam/result
import gleam/string
import o11a/attributes
import o11a/client/attributes as client_attributes
import o11a/client/selectors
import o11a/client/storage
import plinth/browser/document
import plinth/browser/element
import plinth/browser/event
import plinth/browser/window
import snag

pub fn main() {
  io.println("Starting page navigation")

  window.add_event_listener("keydown", fn(event) {
    echo "got event " <> string.inspect(event)

    let res = case storage.is_user_typing() {
      True -> {
        use <- handle_expanded_input_focus(event)
        use <- handle_input_escape(event)
        Ok(Nil)
      }
      False -> {
        use <- handle_keyboard_navigation(event)
        use <- handle_input_focus(event)
        use <- handle_expanded_input_focus(event)
        use <- handle_discussion_escape(event)
        Ok(Nil)
      }
    }

    case res {
      Ok(Nil) -> Nil
      Error(e) -> io.println(snag.line_print(e))
    }
  })
}

fn handle_input_escape(event, else_do) {
  case event.key(event) {
    "Escape" -> {
      event.prevent_default(event)
      focus_line_discussion(
        line_number: storage.current_line_number(),
        column_number: storage.current_column_number(),
      )
    }
    _ -> else_do()
  }
}

fn handle_expanded_input_focus(event, else_do) {
  case event.ctrl_key(event), event.key(event) {
    True, "e" -> {
      event.prevent_default(event)
      Ok(Nil)
      // let exp =
      // get_line_discussion_expanded_input(
      // storage.current_line_number(),
      // storage.current_column_number(),
      // )
    }
    _, _ -> else_do()
  }
}

fn handle_keyboard_navigation(event, else_do) {
  case event.shift_key(event), event.key(event) {
    False, "ArrowUp" -> {
      event.prevent_default(event)
      move_focus_line(by: -1)
    }
    False, "ArrowDown" -> {
      event.prevent_default(event)
      move_focus_line(by: 1)
    }
    True, "ArrowUp" -> {
      event.prevent_default(event)
      move_focus_line(by: -5)
    }
    True, "ArrowDown" -> {
      event.prevent_default(event)
      move_focus_line(by: 5)
    }
    _, "PageUp" -> {
      event.prevent_default(event)
      move_focus_line(by: -20)
    }
    _, "PageDown" -> {
      event.prevent_default(event)
      move_focus_line(by: 20)
    }
    _, "ArrowLeft" -> {
      event.prevent_default(event)
      move_focus_column(by: -1)
    }
    _, "ArrowRight" -> {
      event.prevent_default(event)
      move_focus_column(by: 1)
    }
    _, _ -> else_do()
  }
}

fn move_focus_line(by step) {
  use #(new_line, column_count) <- result.try(find_next_discussion_line(
    storage.current_line_number(),
    step,
  ))

  use Nil <- result.map(focus_line_discussion(
    line_number: new_line,
    column_number: int.min(column_count, storage.current_column_number()),
  ))

  storage.set_current_line_number(new_line)
  storage.set_current_line_column_count(column_count)
}

fn move_focus_column(by step) {
  let new_column =
    int.max(1, storage.current_column_number() + step)
    |> int.min(storage.current_line_column_count())

  use Nil <- result.map(focus_line_discussion(
    line_number: storage.current_line_number(),
    column_number: new_column,
  ))

  storage.set_current_column_number(new_column)
}

fn handle_discussion_escape(_event, _else_do) {
  Ok(Nil)
}

fn handle_input_focus(_event, _else_do) {
  Ok(Nil)
}

fn find_next_discussion_line(current_line current_line: Int, step step: Int) {
  use line_count <- result.try(
    document.query_selector("#audit-page")
    |> result.replace_error(snag.new("Failed to find audit page"))
    |> result.try(client_attributes.read_line_count_data),
  )

  case step, current_line {
    _, _ if step > 0 && current_line == line_count ->
      snag.error(
        "Line is " <> int.to_string(line_count) <> ", cannot go further down",
      )

    _, _ if step < 0 && current_line == 1 ->
      snag.error("Line is 1, cannot go further up")

    _, _ if step == 0 -> snag.error("Step is zero")

    _, _ -> {
      let next_line = int.max(1, int.min(line_count, current_line + step))

      // Not all lines have discussions, so if the current line doesn't, then
      // we need to find the next line that does
      case selectors.non_empty_line(next_line) {
        Ok(line) -> {
          use column_count <- result.map(
            client_attributes.read_column_count_data(line),
          )
          #(next_line, column_count)
        }
        Error(..) ->
          find_next_discussion_line(next_line, step: case step, current_line {
            // If we have skipped to the end of the file and have not found a
            // non-empty line, then work backwards to find the closest line 
            // with a discussion
            _, _ if step > 0 && next_line == line_count -> -1
            _, _ if step > 0 -> 1
            // If we have skipped to the beginning of the file and have not
            // found a non-empty line, then work forwards to find the closest
            // line with a discussion
            _, _ if step < 0 && next_line == 1 -> 1
            _, _ if step < 0 -> -1
            // Should never happen, but if step is zero
            _, _ -> 0
          })
      }
    }
  }
}

fn focus_line_discussion(
  line_number line_number: Int,
  column_number column_number: Int,
) {
  document.query_selector(attributes.grid_location_selector(
    line_number:,
    column_number:,
  ))
  |> result.replace_error(snag.new("Failed to find line discussion to focus"))
  |> result.map(element.focus)
}
