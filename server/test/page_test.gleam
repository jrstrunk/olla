import gleeunit/should
import o11a/ui/audit_page

pub fn style_code_tokens_operator_test() {
  audit_page.style_code_tokens("if (hi < hello == world) {")
  |> should.equal(
    "<span class=\"keyword\">if</span> (hi <span class=\"operator\">&lt;</span> hello <span class=\"operator\">==</span> world) {",
  )
}

pub fn style_code_tokens_function_definition_test() {
  audit_page.style_code_tokens("function hello(string memory world) {")
  |> should.equal(
    "<span class=\"keyword\">function</span> <span class=\"function\">hello</span>(<span class=\"type\">string</span> <span class=\"keyword\">memory</span> world) {",
  )
}

pub fn style_code_tokens_comment_test() {
  audit_page.style_code_tokens("return vr; // hello world")
  |> should.equal(
    "<span class=\"keyword\">return</span> vr; <span class=\"comment\">// hello world</span>",
  )
}

pub fn style_code_tokens_contract_test() {
  audit_page.style_code_tokens("using SafeERC20 for IERC20;")
  |> should.equal(
    "<span class=\"keyword\">using</span> <span class=\"contract\">SafeERC20</span> <span class=\"keyword\">for</span> <span class=\"contract\">IERC20</span>;",
  )
}

pub fn style_code_tokens_number_test() {
  audit_page.style_code_tokens("uint256 hello = 10;")
  |> should.equal(
    "<span class=\"type\">uint256</span> hello <span class=\"operator\">=</span> <span class=\"number\">10</span>;",
  )
}
