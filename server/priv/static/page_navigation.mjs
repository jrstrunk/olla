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

    console.log("Got control key", event.key, event.ctrlKey, event.shiftKey);

    handle_discussion_focus(event) || handle_input_focus(event);
  }
});

// Focus a dicussion input logic
function handle_input_focus(event) {
  if (!event.ctrlKey && event.key === "e") {
    get_line_discussion_input(
      current_selected_line_number,
      discussion_lane
    )?.focus();
  } else if (event.ctrlKey && event.key === "e") {
    console.log("Got ctrl e key", event.key);
    let exp = get_line_discussion_expanded_input(
      current_selected_line_number,
      discussion_lane
    );

    let exp_cont = get_line_discussion_expanded_input_container(
      current_selected_line_number,
      discussion_lane
    );


    if (exp_cont?.classList.contains("hide-exp")) {
      exp_cont.classList.remove("hide-exp");
      exp_cont.classList.add("show-exp");
      // Wait for the styles to be applied
      setTimeout(() => exp?.focus(), 100);
    } else {
      exp?.focus();
    }
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

function get_line_discussion_expanded_input(line_number, discussion_lane) {
  let discussion =
    discussion_lane === 1 ? "line-discussion" : "function-discussion";

  // Until function discussions are implemented
  discussion = "line-discussion";

  return document
    .querySelector("#audit-page")
    ?.shadowRoot?.querySelector(`#L${line_number} ${discussion}`)
    ?.shadowRoot?.querySelector("#expanded-message-box");
}

function get_line_discussion_expanded_input_container(
  line_number,
  discussion_lane
) {
  let discussion =
    discussion_lane === 1 ? "line-discussion" : "function-discussion";

  // Until function discussions are implemented
  discussion = "line-discussion";

  return document
    .querySelector("#audit-page")
    ?.shadowRoot?.querySelector(`#L${line_number} ${discussion}`)
    ?.shadowRoot?.querySelector("#expanded-message");
}

// Arrow navigation on the audit page logic

function handle_discussion_focus(event) {
  if (!event.shiftKey && event.key === "ArrowUp") {
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      -1
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (!event.shiftKey && event.key === "ArrowDown") {
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      1
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.shiftKey && event.key === "ArrowUp") {
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      -1,
      5
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.shiftKey && event.key === "ArrowDown") {
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      1,
      5
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
