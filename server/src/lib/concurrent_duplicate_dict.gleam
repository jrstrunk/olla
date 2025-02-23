import gleam/list
import lamb
import lamb/query
import lamb/query/term
import tempo

pub type ConcurrentDuplicateDict(key, val) =
  lamb.Table(key, val)

pub fn new() {
  let assert Ok(table) =
    lamb.create(
      tempo.format_utc(tempo.ISO8601Micro),
      lamb.Public,
      lamb.DuplicateBag,
      True,
    )
  table
}

pub fn from_nested_list(list: List(#(key, List(val)))) {
  let table: ConcurrentDuplicateDict(key, val) = new()

  list.each(list, fn(item) {
    list.each(item.1, fn(val) { insert(table, item.0, val) })
  })

  table
}

pub fn from_list(list: List(#(key, val))) {
  let table = new()

  list.each(list, fn(item) { insert(table, item.0, item.1) })

  table
}

pub fn insert(table: ConcurrentDuplicateDict(key, val), key, val) {
  lamb.insert(table, key, val)
}

pub fn get(table: ConcurrentDuplicateDict(key, val), key) {
  case lamb.lookup(table, key) {
    [] -> Error(Nil)
    values -> Ok(values)
  }
}

pub fn keys(table: ConcurrentDuplicateDict(key, val)) -> List(key) {
  let query =
    query.new()
    |> query.index(term.var(0))
    |> query.map(fn(index, _record) { index })

  lamb.search(table, query)
  |> list.unique
}

pub fn to_list(table: ConcurrentDuplicateDict(key, val)) -> List(#(key, val)) {
  lamb.search(table, query.new())
}
