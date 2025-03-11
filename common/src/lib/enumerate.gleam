import gleam/list
import gleam/string

pub fn translate_number_to_letter(number) {
  case number {
    1 -> "a"
    2 -> "b"
    3 -> "c"
    4 -> "d"
    5 -> "e"
    6 -> "f"
    7 -> "g"
    8 -> "h"
    9 -> "i"
    10 -> "j"
    11 -> "k"
    12 -> "l"
    13 -> "m"
    14 -> "n"
    15 -> "o"
    16 -> "p"
    17 -> "q"
    18 -> "r"
    19 -> "s"
    20 -> "t"
    21 -> "u"
    22 -> "v"
    23 -> "w"
    24 -> "x"
    25 -> "y"
    26 -> "z"
    _ -> {
      let quotient = { number - 1 } / 26
      let remainder = { number - 1 } % 26
      case quotient {
        0 -> translate_number_to_letter(remainder + 1)
        _ ->
          translate_number_to_letter(quotient)
          <> translate_number_to_letter(remainder + 1)
      }
    }
  }
}

pub fn get_leading_spaces(string: String) -> String {
  string
  |> string.to_graphemes
  |> list.take_while(fn(char) { char == " " })
  |> string.join(with: "")
}
