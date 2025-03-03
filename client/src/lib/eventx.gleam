import gleam/dynamic
import gleam/dynamic/decode
import gleam/result
import lustre/event

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

pub fn on_e(msg: msg) {
  use event <- event.on("keydown")

  let empty_error = [dynamic.DecodeError("", "", [])]

  use key <- result.try(
    decode.run(event, decode.field("key", decode.string, decode.success))
    |> result.replace_error(empty_error),
  )

  case key {
    "e" -> Ok(msg)
    _ -> Error(empty_error)
  }
}
