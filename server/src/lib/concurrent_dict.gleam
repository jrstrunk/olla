import gleam/list
import lamb
import tempo
import tempo/duration

pub type ConcurrentDict(key, val) =
  lamb.Table(key, val)

pub fn new() {
  // Wait to make sure there is not a naming collision between tables. This
  // could be done better by getting the unqiue value from tempo.instant
  tempo.sleep(duration.milliseconds(1))

  let assert Ok(table) =
    lamb.create(
      tempo.format_utc(tempo.ISO8601Micro),
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
