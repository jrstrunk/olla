import gleam/int
import gleam/list
import gleam/result
import snag

pub fn collect_errors(results: List(Result(a, snag.Snag))) {
  let #(oks, errors) = result.partition(results)

  case errors {
    [] -> Ok(oks)

    [single_error] ->
      { "1 collected error: " <> snag.line_print(single_error) } |> snag.error

    multiple_errors ->
      list.fold(
        multiple_errors,
        list.length(multiple_errors) |> int.to_string <> " collected errors: ",
        fn(acc, e) { acc <> ", then error: " <> snag.line_print(e) },
      )
      |> snag.error
  }
}
