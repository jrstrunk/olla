import gleam/dynamic
import gleam/dynamic/decode
import gleam/result
import lustre/event
import plinth/browser/event as browser_event

pub fn on_ctrl_enter(msg: msg) {
  use event <- event.on("keydown")

  let decoder = {
    use ctrl_key <- decode.field("ctrlKey", decode.bool)
    use key <- decode.field("key", decode.string)

    decode.success(#(ctrl_key, key))
  }

  let empty_error = [dynamic.DecodeError("", "", [])]

  use #(ctrl_key, key) <- result.try(
    decode.run(event, decoder)
    |> result.replace_error(empty_error),
  )

  case ctrl_key, key {
    True, "Enter" -> Ok(msg)
    _, _ -> Error(empty_error)
  }
}

pub fn on_up_arrow(msg: msg) {
  use event <- event.on("keydown")

  let empty_error = [dynamic.DecodeError("", "", [])]

  use key <- result.try(
    decode.field("key", decode.string, decode.success)
    |> decode.run(event, _)
    |> result.replace_error(empty_error),
  )

  case key {
    "ArrowUp" -> Ok(msg)
    _ -> Error(empty_error)
  }
}

pub fn on_parent_click(msg: msg) {
  event.on("click", fn(event) {
    event.stop_propagation(event)
    let empty_error = [dynamic.DecodeError("", "", [])]
    use event <- result.try(
      browser_event.cast_event(event)
      |> result.replace_error(empty_error),
    )

    case browser_event.target(event) == browser_event.current_target(event) {
      True -> Ok(msg)
      False -> Error(empty_error)
    }
  })
}

pub fn on_input_no_propagation(msg: fn(String) -> msg) {
  use event <- event.on("input")
  event.stop_propagation(event)

  decode.run(
    event,
    decode.subfield(["target", "value"], decode.string, decode.success),
  )
  |> result.replace_error([dynamic.DecodeError("", "", [])])
  |> result.map(msg)
}

pub fn suppress_keydown_propagation(msg) {
  use event <- event.on("keydown")
  event.stop_propagation(event)
  Ok(msg)
}

pub fn suppress_click_propagation() {
  use event <- event.on("click")
  event.stop_propagation(event)
  // Ok(msg)
  Error([dynamic.DecodeError("", "", [])])
}
