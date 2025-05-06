import gleam/dynamic/decode
import gleam/option
import lustre/event

pub fn on_ctrl_click(ctrl_click ctrl_click, non_ctrl_click non_ctrl_click) {
  event.on("click", {
    use ctrl_key <- decode.field("ctrlKey", decode.bool)

    case ctrl_key {
      True -> decode.success(ctrl_click)
      False ->
        case non_ctrl_click {
          option.Some(non_ctrl_click) -> decode.success(non_ctrl_click)
          option.None -> decode.failure(ctrl_click, "ctrl_click")
        }
    }
  })
}

pub fn on_non_ctrl_click(msg: msg) {
  event.on("click", {
    use ctrl_key <- decode.field("ctrlKey", decode.bool)

    case ctrl_key {
      False -> decode.success(msg)
      _ -> decode.failure(msg, "non_ctrl_click")
    }
  })
}

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
