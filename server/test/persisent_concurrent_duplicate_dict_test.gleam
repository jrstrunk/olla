import gleam/dynamic/decode
import gleam/function
import gleam/option.{type Option}
import lib/persistent_concurrent_duplicate_dict
import sqlight

pub fn persistent_concurrent_duplicate_dict_test() {
  let assert Ok(pcdd) =
    persistent_concurrent_duplicate_dict.build(
      "test_pcdd",
      function.identity,
      function.identity,
      "msg TEXT NOT NULL, expanded_msg TEXT",
      fn(val: #(String, Option(String))) {
        [sqlight.text(val.0), sqlight.nullable(sqlight.text, val.1)]
      },
      {
        use msg <- decode.field(0, decode.string)
        use expanded_msg <- decode.field(1, decode.optional(decode.string))
        decode.success(#(msg, expanded_msg))
      },
    )

  let test_val = #("hello", option.None)

  let assert Ok(Nil) =
    persistent_concurrent_duplicate_dict.insert(pcdd, "first_msg", test_val)

  let assert Ok([#("hello", option.None), ..]) =
    persistent_concurrent_duplicate_dict.get(pcdd, "first_msg")

  let assert Error(Nil) = persistent_concurrent_duplicate_dict.get(pcdd, "foo")

  // Reconstruct the persistent concurrent dict from the persisted data
  let assert Ok(pcdd) =
    persistent_concurrent_duplicate_dict.build(
      "test_pcdd",
      function.identity,
      function.identity,
      "msg TEXT NOT NULL, expanded_msg TEXT",
      fn(val: #(String, Option(String))) {
        [sqlight.text(val.0), sqlight.nullable(sqlight.text, val.1)]
      },
      {
        use msg <- decode.field(0, decode.string)
        use expanded_msg <- decode.field(1, decode.optional(decode.string))
        decode.success(#(msg, expanded_msg))
      },
    )

  let assert Ok(Nil) =
    persistent_concurrent_duplicate_dict.insert(pcdd, "first_msg", test_val)

  // The value should already be there
  let assert Ok([#("hello", option.None), #("hello", option.None), ..]) =
    persistent_concurrent_duplicate_dict.get(pcdd, "first_msg")
}
