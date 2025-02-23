import gleam/list
import gleam/string
import gleeunit/should
import lib/concurrent_duplicate_dict

pub fn keys_test() {
  let data = [
    #("hello", ["world", "world_again"]),
    #("foo", ["bar"]),
    #("baz", ["qux"]),
    #("quux", ["quuux"]),
  ]

  let cdd = concurrent_duplicate_dict.from_nested_list(data)

  concurrent_duplicate_dict.keys(cdd)
  |> list.sort(string.compare)
  |> should.equal(
    ["hello", "foo", "baz", "quux"]
    |> list.sort(string.compare),
  )
}

pub fn to_list_test() {
  let data = [
    #("hello", ["world", "world_again"]),
    #("foo", ["bar"]),
    #("baz", ["qux"]),
    #("quux", ["quuux"]),
  ]

  let cdd = concurrent_duplicate_dict.from_nested_list(data)

  concurrent_duplicate_dict.to_list(cdd)
  |> should.equal([
    #("foo", "bar"),
    #("baz", "qux"),
    #("hello", "world"),
    #("hello", "world_again"),
    #("quux", "quuux"),
  ])
}
