export function focus_line_discussion_input(line_tag) {
  document
    .querySelector("#audit-page")
    .shadowRoot.querySelector(`#${line_tag} line-discussion`)
    .shadowRoot.querySelector("input")
    .focus();
}
