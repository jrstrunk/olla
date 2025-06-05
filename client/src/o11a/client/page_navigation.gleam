import gleam/int
import gleam/io
import gleam/result
import lustre/effect
import o11a/client/attributes as client_attributes
import o11a/client/selectors
import o11a/client/storage
import plinth/browser/element
import plinth/browser/event
import snag

pub type Model {
  Model(
    cursor_view_id: String,
    cursor_line_number: Int,
    cursor_column_number: Int,
    active_view_id: String,
    active_line_number: Int,
    active_column_number: Int,
    current_line_column_count: Int,
    line_count: Int,
  )
}

pub fn init(cursor_view_id) {
  Model(
    cursor_view_id:,
    cursor_line_number: 16,
    cursor_column_number: 1,
    active_view_id: cursor_view_id,
    active_line_number: 16,
    active_column_number: 1,
    current_line_column_count: 16,
    line_count: 16,
  )
}

/// Prevents the default browser behavior for the given accepted navigation keys
pub fn prevent_default(event) {
  case storage.is_user_typing() {
    True ->
      case event.ctrl_key(event), event.key(event) {
        True, "e" -> event.prevent_default(event)
        _, "Escape" -> event.prevent_default(event)
        _, _ -> Nil
      }
    False ->
      case event.key(event) {
        "ArrowUp"
        | "ArrowDown"
        | "ArrowLeft"
        | "ArrowRight"
        | "PageUp"
        | "PageDown"
        | "Enter"
        | "e"
        | "Escape" -> event.prevent_default(event)
        _ -> Nil
      }
  }
}

pub fn do_page_navigation(event, model: Model) {
  let res = case storage.is_user_typing() {
    True -> {
      use <- handle_expanded_input_focus(event, model)
      use <- handle_input_escape(event, model)
      Ok(#(model, effect.none()))
    }
    False -> {
      use <- handle_keyboard_navigation(event, model)
      use <- handle_input_focus(event, model)
      use <- handle_expanded_input_focus(event, model)
      use <- handle_discussion_escape(event, model)
      Ok(#(model, effect.none()))
    }
  }

  case res {
    Ok(model_effect) -> model_effect
    Error(e) -> {
      io.println(snag.line_print(e))
      #(model, effect.none())
    }
  }
}

fn handle_input_escape(event, model: Model, else_do) {
  case event.key(event) {
    "Escape" ->
      Ok(#(
        model,
        focus_line_discussion(
          view_id: model.active_view_id,
          line_number: model.cursor_line_number,
          column_number: model.cursor_column_number,
        ),
      ))

    _ -> else_do()
  }
}

fn handle_expanded_input_focus(event, model, else_do) {
  case event.ctrl_key(event), event.key(event) {
    True, "e" -> {
      Ok(#(model, effect.none()))
      // let exp =
      // get_line_discussion_expanded_input(
      // storage.cursor_line_number(),
      // storage.cursor_column_number(),
      // )
    }
    _, _ -> else_do()
  }
}

fn handle_keyboard_navigation(event, model, else_do) {
  case event.shift_key(event), event.key(event) {
    False, "ArrowUp" -> {
      move_focus_line(model, by: -1)
    }
    False, "ArrowDown" -> {
      move_focus_line(model, by: 1)
    }
    True, "ArrowUp" -> {
      move_focus_line(model, by: -5)
    }
    True, "ArrowDown" -> {
      move_focus_line(model, by: 5)
    }
    _, "PageUp" -> {
      move_focus_line(model, by: -20)
    }
    _, "PageDown" -> {
      move_focus_line(model, by: 20)
    }
    _, "ArrowLeft" -> {
      move_focus_column(model, by: -1)
    }
    _, "ArrowRight" -> {
      move_focus_column(model, by: 1)
    }
    _, _ -> else_do()
  }
}

fn move_focus_line(model: Model, by step) {
  use #(new_line, column_count) <- result.map(find_next_discussion_line(
    model,
    model.cursor_line_number,
    step,
  ))

  #(
    Model(..model, current_line_column_count: column_count),
    focus_line_discussion(
      view_id: model.cursor_view_id,
      line_number: new_line,
      column_number: int.min(column_count, model.cursor_column_number),
    ),
  )
}

fn move_focus_column(model: Model, by step) {
  echo "moving focus column by " <> int.to_string(step)
  let new_column =
    int.max(1, model.cursor_column_number + step)
    |> int.min(model.current_line_column_count)

  echo "new column " <> int.to_string(new_column)
  #(
    model,
    focus_line_discussion(
      view_id: model.cursor_view_id,
      line_number: model.cursor_line_number,
      column_number: new_column,
    ),
  )
  |> Ok
}

fn handle_discussion_escape(event, model: Model, else_do) {
  case event.key(event) {
    "Escape" ->
      Ok(#(
        model,
        blur_line_discussion(
          view_id: model.cursor_view_id,
          line_number: model.cursor_line_number,
          column_number: model.cursor_column_number,
        ),
      ))

    _ -> else_do()
  }
}

fn handle_input_focus(event, model: Model, else_do) {
  case event.ctrl_key(event), event.key(event) {
    False, "e" ->
      Ok(#(
        model,
        focus_line_discussion_input(
          view_id: model.cursor_view_id,
          line_number: model.active_line_number,
          column_number: model.active_column_number,
        ),
      ))
    _, _ -> else_do()
  }
}

fn find_next_discussion_line(
  model: Model,
  current_line current_line: Int,
  step step: Int,
) {
  case step, current_line {
    _, _ if step > 0 && current_line == model.line_count ->
      snag.error(
        "Line is "
        <> int.to_string(model.line_count)
        <> ", cannot go further down",
      )

    _, _ if step < 0 && current_line == 1 ->
      snag.error("Line is 1, cannot go further up")

    _, _ if step == 0 -> snag.error("Step is zero")

    _, _ -> {
      let next_line = int.max(1, int.min(model.line_count, current_line + step))

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
          find_next_discussion_line(
            model,
            next_line,
            step: case step, current_line {
              // If we have skipped to the end of the file and have not found a
              // non-empty line, then work backwards to find the closest line 
              // with a discussion
              _, _ if step > 0 && next_line == model.line_count -> -1
              _, _ if step > 0 -> 1
              // If we have skipped to the beginning of the file and have not
              // found a non-empty line, then work forwards to find the closest
              // line with a discussion
              _, _ if step < 0 && next_line == 1 -> 1
              _, _ if step < 0 -> -1
              // Should never happen, but if step is zero
              _, _ -> 0
            },
          )
      }
    }
  }
}

fn focus_line_discussion(
  view_id view_id: String,
  line_number line_number: Int,
  column_number column_number: Int,
) {
  effect.from(fn(_dispatch) {
    echo "focus line discussion"
    let _ =
      selectors.discussion_entry(view_id:, line_number:, column_number:)
      |> result.replace_error(snag.new(
        "Failed to find line discussion to focus",
      ))
      |> result.map(element.focus)
      |> echo
    Nil
  })
}

fn blur_line_discussion(
  view_id view_id: String,
  line_number line_number: Int,
  column_number column_number: Int,
) {
  effect.from(fn(_dispatch) {
    echo "blurring line discussion"
    let element =
      selectors.discussion_entry(view_id:, line_number:, column_number:)
      |> result.replace_error(snag.new(
        "Failed to find line discussion to focus",
      ))

    // First focus the element so that when we blur it, it will trigger
    // the onBlur event. If the element is not focused and we try to blur it,
    // it will fail and not trigger the onBlur event.
    let _ = element |> result.map(element.focus)
    let _ = element |> result.map(element.blur)

    Nil
  })
}

fn focus_line_discussion_input(
  view_id view_id: String,
  line_number line_number: Int,
  column_number column_number: Int,
) {
  effect.from(fn(_dispatch) {
    let _ =
      selectors.discussion_input(view_id:, line_number:, column_number:)
      |> result.replace_error(snag.new(
        "Failed to find line discussion input to focus",
      ))
      |> result.map(element.focus)
    Nil
  })
}
