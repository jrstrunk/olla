import gleeunit/should
import o11a/ui/audit_page_sol

pub fn split_info_comment_test() {
  audit_page_sol.split_info_comment("hello world", False, 0)
  |> should.equal(["hello world"])

  "hello world this is a really long comment that is going to be split somewhere around here"
  |> audit_page_sol.split_info_comment(True, 0)
  |> should.equal([
    "hello world this is a really long comment that is going to be split somewhere",
    "around here^",
  ])

  audit_page_sol.split_info_comment("hello world", True, 4)
  |> should.equal(["    hello world^"])
}
