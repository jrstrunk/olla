export function focus_line_discussion_input(line_tag) {
  console.log("Focusing on line tag", line_tag);
  document
    .querySelector("lustre-server-component")
    .shadowRoot.querySelector(`#${line_tag} line-discussion`)
    .shadowRoot.querySelector("input")
    .focus();
}
