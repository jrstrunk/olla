console.log("Starting page navigation");

let current_selected_line_number = 16;
// 1 for line discussion, 0 for function discussion
let discussion_lane = 1;

let control_keys = [
  "ArrowUp",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight",
  "e",
  "PageUp",
  "PageDown",
];

window.addEventListener("keydown", (event) => {
  // If the key is a control key, prevent the default action
  if (control_keys.includes(event.key)) {
    event.preventDefault();

    console.log("Got control key", event.key);

    handle_discussion_focus(event) || handle_input_focus(event);
  }
});

// Focus a dicussion input logic
function handle_input_focus(event) {
  console.log("Handling input focus");
  if (event.key === "e") {
    let el = get_line_discussion_input(
      current_selected_line_number,
      discussion_lane
    );
    console.log("Got el", el);
    el?.focus();
  } else {
    return false;
  }
  return true;
}

function get_line_discussion_input(line_number, discussion_lane) {
  let discussion =
    discussion_lane === 1 ? "line-discussion" : "function-discussion";

  // Until function discussions are implemented
  discussion = "line-discussion";

  return document
    .querySelector("#audit-page")
    ?.shadowRoot?.querySelector(`#L${line_number} ${discussion}`)
    ?.shadowRoot?.querySelector("#new-comment-input");
}

// Arrow navigation on the audit page logic

function handle_discussion_focus(event) {
  if (event.key === "ArrowUp") {
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      -1
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.key === "ArrowDown") {
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      1
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.key === "PageUp") {
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      -1,
      20
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.key === "PageDown") {
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      1,
      20
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.key === "ArrowLeft") {
    discussion_lane = Math.max(0, discussion_lane - 1);
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.key === "ArrowRight") {
    discussion_lane = Math.min(1, discussion_lane + 1);
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else {
    return false;
  }
  return true;
}

function findNextDiscussionLine(current_line, direction, step = 1) {
  const max_lines =
    document
      .querySelector("lustre-server-component")
      ?.shadowRoot?.querySelectorAll("p")?.length ?? current_line;

  let line = current_line;
  // For page up/down, first jump by step amount
  if (step > 1) {
    line = Math.max(1, Math.min(max_lines, line + direction * step));
  } else {
    line += direction;
  }

  while (line >= 1 && line <= max_lines) {
    if (line < 1 || line > max_lines) break;

    if (get_line_discussion(line, discussion_lane)) {
      return line;
    }

    // If we missed, check the next line
    line += direction;
  }
  return current_line; // Return original line if no discussion found
}

function focus_line_discussion(line_number, discussion_lane) {
  get_line_discussion(line_number, discussion_lane)?.focus();
}

function get_line_discussion(line_number, discussion_lane) {
  let discussion =
    discussion_lane === 1 ? "line-discussion" : "function-discussion";

  // Until function discussions are implemented
  discussion = "line-discussion";

  return document
    .querySelector("#audit-page")
    ?.shadowRoot?.querySelector(`#L${line_number} ${discussion}`)
    ?.shadowRoot?.querySelector("#discussion-entry");
}
