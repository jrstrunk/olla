import gleam/int
import gleam/list
import lamb
import tempo/instant

pub type ConcurrentDict(key, val) =
  lamb.Table(key, val)

pub fn new() {
  let assert Ok(table) =
    lamb.create(
      "cd" <> instant.now() |> instant.to_unique_int |> int.to_string,
      lamb.Public,
      lamb.Set,
      True,
    )
  table
}

pub fn from_list(list: List(#(key, val))) {
  let table = new()

  list.each(list, fn(item) { insert(table, item.0, item.1) })

  table
}

pub fn insert(table: ConcurrentDict(key, val), key, val) {
  lamb.insert(table, key, val)
}

pub fn get(table: ConcurrentDict(key, val), key) {
  case lamb.lookup(table, key) {
    [value] -> Ok(value)
    _ -> Error(Nil)
  }
}
