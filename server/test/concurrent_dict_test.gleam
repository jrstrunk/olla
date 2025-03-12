import concurrent_dict
import gleeunit/should

pub fn nested_concurrent_dict_test() {
  let cd = concurrent_dict.new()
  let data = [
    #("hello", "world"),
    #("foo", "bar"),
    #("baz", "qux"),
    #("quux", "quuux"),
  ]

  concurrent_dict.insert(cd, "hello", data)

  let cd2 = concurrent_dict.new()
  concurrent_dict.insert(cd2, "hello", cd)

  let assert Ok(cd3) = concurrent_dict.get(cd2, "hello")

  concurrent_dict.get(cd3, "hello")
  |> should.equal(Ok(data))
}
