import gleam/dynamic/decode
import gleam/function
import gleam/list
import gleam/option.{type Option}
import gleam/string
import gleeunit/should
import lib/persistent_concurrent_duplicate_dict as pcdd

pub fn pcdd_test() {
  let assert Ok(pcdd) =
    pcdd.build(
      "priv/persist/test_pcdd",
      function.identity,
      function.identity,
      #("hello", option.None),
      fn(val: #(String, Option(String))) {
        [pcdd.text(val.0), pcdd.text_nullable(val.1)]
      },
      {
        use msg <- decode.field(0, decode.string)
        use expanded_msg <- decode.field(1, decode.optional(decode.string))
        decode.success(#(msg, expanded_msg))
      },
    )

  let test_val = #("hello", option.None)

  let assert Ok(Nil) = pcdd.insert(pcdd, "first_msg", test_val)

  let assert [#("hello", option.None), ..] = pcdd.get(pcdd, "first_msg")

  let assert [] = pcdd.get(pcdd, "foo")

  // Reconstruct the persistent concurrent dict from the persisted data
  let assert Ok(pcdd) =
    pcdd.build(
      "priv/persist/test_pcdd",
      function.identity,
      function.identity,
      #("hello", option.None),
      fn(val: #(String, Option(String))) {
        [pcdd.text(val.0), pcdd.text_nullable(val.1)]
      },
      {
        use msg <- decode.field(0, decode.string)
        use expanded_msg <- decode.field(1, decode.optional(decode.string))
        decode.success(#(msg, expanded_msg))
      },
    )

  let assert Ok(Nil) = pcdd.insert(pcdd, "first_msg", test_val)

  // The value should already be there
  let assert [#("hello", option.None), #("hello", option.None), ..] =
    pcdd.get(pcdd, "first_msg")
}

pub fn topic_test() {
  let assert Ok(pcdd) =
    pcdd.build(
      "priv/persist/test_pcdd",
      function.identity,
      function.identity,
      #("hello", option.None),
      fn(val: #(String, Option(String))) {
        [pcdd.text(val.0), pcdd.text_nullable(val.1)]
      },
      {
        use msg <- decode.field(0, decode.string)
        use expanded_msg <- decode.field(1, decode.optional(decode.string))
        decode.success(#(msg, expanded_msg))
      },
    )

  let assert Ok(Nil) = pcdd.add_topic(pcdd, "first_topic")

  let assert Ok(Nil) = pcdd.add_topic(pcdd, "second_topic")

  pcdd.topics(pcdd)
  |> list.sort(string.compare)
  |> should.equal(["first_topic", "second_topic"])

  // Rebuilding the pcd dict should not lose the topics
  let assert Ok(pcdd) =
    pcdd.build(
      "priv/persist/test_pcdd",
      function.identity,
      function.identity,
      #("hello", option.None),
      fn(val: #(String, Option(String))) {
        [pcdd.text(val.0), pcdd.text_nullable(val.1)]
      },
      {
        use msg <- decode.field(0, decode.string)
        use expanded_msg <- decode.field(1, decode.optional(decode.string))
        decode.success(#(msg, expanded_msg))
      },
    )

  pcdd.topics(pcdd)
  |> list.sort(string.compare)
  |> should.equal(["first_topic", "second_topic"])
}
