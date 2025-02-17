import gleam/function
import lib/persistent_concurrent_dict

pub fn persistent_concurrent_dict_test() {
  let assert Ok(pcd) =
    persistent_concurrent_dict.build(
      "test",
      function.identity,
      function.identity,
      function.identity,
      function.identity,
    )

  let assert Ok(Nil) = persistent_concurrent_dict.insert(pcd, "hello", "world")

  let assert Ok("world") = persistent_concurrent_dict.get(pcd, "hello")

  let assert Error(Nil) = persistent_concurrent_dict.get(pcd, "foo")

  // Reconstruct the persistent concurrent dict from the persisted data
  let assert Ok(pcd) =
    persistent_concurrent_dict.build(
      "test",
      function.identity,
      function.identity,
      function.identity,
      function.identity,
    )

  let assert Ok("world") = persistent_concurrent_dict.get(pcd, "hello")
}
