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

    [first_error, ..rest_errors] ->
      list.fold(
        rest_errors,
        { list.length(rest_errors) + 1 } |> int.to_string
          <> " collected errors <- "
          <> snag.line_print(first_error),
        fn(acc, e) { acc <> ", then " <> snag.line_print(e) },
      )
      |> snag.error
  }
}
