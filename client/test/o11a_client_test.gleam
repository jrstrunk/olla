import gleeunit
import gleeunit/should
import lib/enumerate

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  1
  |> should.equal(1)
}

pub fn enumerate_test() {
  enumerate.translate_number_to_letter(1)
  |> should.equal("a")
}

pub fn enumerate2_test() {
  enumerate.translate_number_to_letter(26)
  |> should.equal("z")
}

pub fn enumerate3_test() {
  enumerate.translate_number_to_letter(29)
  |> should.equal("ac")
}
