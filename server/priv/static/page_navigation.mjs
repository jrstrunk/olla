console.log("Starting page navigation");

let current_selected_line_number = 16;

let discussion_lane = 1; // 1 for line discussion, 0 for function discussion

let is_user_typing = false;

window.addEventListener("keydown", (event) => {
  // If the key is a control key, prevent the default action and handle the key.
  // If the user is currently typing, do nothing.
  if (is_user_typing) {
    handle_input_escape(event) || handle_expanded_input_focus(event);
  } else {
    handle_discussion_focus(event) ||
      handle_input_focus(event) ||
      handle_expanded_input_focus(event) ||
      handle_discussion_escape(event);
  }
});

window.addEventListener("user-clicked-discussion-preview", (event) => {
  console.log("Clicked discussion preview", event.detail);
  current_selected_line_number = event.detail.line_number;
  discussion_lane = event.detail.discussion_lane;
});

window.addEventListener("user-focused-input", (event) => {
  is_user_typing = true;
  current_selected_line_number = event.detail.line_number;
  discussion_lane = event.detail.discussion_lane;
});

window.addEventListener("user-unfocused-input", (event) => {
  is_user_typing = false;
});

function handle_input_escape(event) {
  if (event.key === "Escape") {
    event.preventDefault();
    focus_line_discussion(current_selected_line_number, discussion_lane);
  }
}

function handle_expanded_input_focus(event) {
  if (event.ctrlKey && event.key === "e") {
    event.preventDefault();
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
  }
}

// Focus a dicussion input logic
function handle_input_focus(event) {
  if (!event.ctrlKey && event.key === "e") {
    event.preventDefault();
    get_line_discussion_input(
      current_selected_line_number,
      discussion_lane
    )?.focus();
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

function handle_discussion_escape(event) {
  if (event.key === "Escape") {
    console.log("Escaping discussion");
    event.preventDefault();
    get_line_discussion(current_selected_line_number, discussion_lane)?.blur();
    return true;
  }
  return false;
}

function handle_discussion_focus(event) {
  if (!event.shiftKey && event.key === "ArrowUp") {
    event.preventDefault();
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      -1
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (!event.shiftKey && event.key === "ArrowDown") {
    event.preventDefault();
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      1
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.shiftKey && event.key === "ArrowUp") {
    event.preventDefault();
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      -1,
      5
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.shiftKey && event.key === "ArrowDown") {
    event.preventDefault();
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      1,
      5
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.key === "PageUp") {
    event.preventDefault();
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      -1,
      20
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.key === "PageDown") {
    event.preventDefault();
    current_selected_line_number = findNextDiscussionLine(
      current_selected_line_number,
      1,
      20
    );
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.key === "ArrowLeft") {
    event.preventDefault();
    discussion_lane = Math.max(0, discussion_lane - 1);
    focus_line_discussion(current_selected_line_number, discussion_lane);
  } else if (event.key === "ArrowRight") {
    event.preventDefault();
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
