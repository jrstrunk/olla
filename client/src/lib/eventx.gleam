import gleam/dynamic/decode
import lustre/event

pub fn on_ctrl_enter(msg: msg) {
  event.on("keydown", {
    use ctrl_key <- decode.field("ctrlKey", decode.bool)
    use key <- decode.field("key", decode.string)

    case ctrl_key, key {
      True, "Enter" -> decode.success(msg)
      _, _ -> decode.failure(msg, "ctrl_enter")
    }
  })
}

pub fn on_up_arrow(msg: msg) {
  event.on("keydown", {
    use key <- decode.field("key", decode.string)
    case key {
      "ArrowUp" -> decode.success(msg)
      _ -> decode.failure(msg, "up_arrow")
    }
  })
}
