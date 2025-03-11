console.log("Starting page navigatiosn");

let current_selected_line_number = 16;

let discussion_lane = 1; // 1 for line discussion, 0 for function discussion

let is_user_typing = false;

window.addEventListener("keydown", (event) => {
  // If the key is a control key, prevent the default action and handle the key.
  // If the user is currently typing, do nothing.
  console.log("got Keydown", event, is_user_typing);
  if (is_user_typing) {
    handle_input_escape(event) || handle_expanded_input_focus(event);
  } else {
    handle_discussion_focus(event) ||
      handle_input_focus(event) ||
      handle_expanded_input_focus(event) ||
      handle_discussion_escape(event);
  }
});

let user_trigger_loc_event = "user-triggered-discussion-preview-select";

window.addEventListener(user_trigger_loc_event, (e) => {
  console.log("Triggered discussion preview select", e.detail.line_number);
  current_selected_line_number = e.detail.line_number;
});

document.addEventListener("DOMContentLoaded", function () {
  // Wait for the server component to render first. When an event is added to
  // the lustre runtime then we can listen for that instead of setting a time out
  setTimeout(() => {
    document
      .querySelector("#audit-page")
      .shadowRoot.querySelectorAll(".line-container")
      .forEach((element) => {
        element.addEventListener("mouseenter", (e) => {
          const event = new CustomEvent(user_trigger_loc_event, {
            detail: { line_number: parseInt(e.target.dataset.lineNumber) },
          });
          window.dispatchEvent(event);
        });
      });
  }, 1000);
});

window.addEventListener("user-focused-input", (event) => {
  is_user_typing = true;
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

    if (!exp_cont?.classList.contains("show-exp")) {
      exp_cont.classList.add("show-exp");
      // Wait for the styles to be applied after changing the class
      setTimeout(() => exp?.focus(), 50);
    } else {
      exp?.focus();
    }
    return true;
  }
  return false;
}

// Focus a discussion input logic
function handle_input_focus(event) {
  if (!event.ctrlKey && event.key === "e") {
    event.preventDefault();

    console.log("input focusing");

    let overlay = get_line_discussion_component(
      current_selected_line_number,
      discussion_lane
    );

    let inp = get_line_discussion_input(
      current_selected_line_number,
      discussion_lane
    );

    if (!overlay?.classList.contains("show-dis")) {
      overlay.classList.add("show-dis");
      // Wait for the styles to be applied after changing the class to show the
      // overlay so we can focus it. Then after it is focused, we can remove
      // the class because the :focus selector will take over showing the
      // overlay when appropriate.
      setTimeout(() => {
        inp?.focus();
        overlay.classList.remove("show-dis");
      }, 50);
    } else {
      inp?.focus();
    }

    return true;
  }
  return false;
}

function get_line_discussion_input(line_number, discussion_lane) {
  return get_discussion_shadow_root(line_number)?.querySelector(
    "#new-comment-input"
  );
}

function get_line_discussion_component(line_number, discussion_lane) {
  return document
    .querySelector("#audit-page")
    ?.shadowRoot?.querySelector(`#L${line_number} line-discussion`);
}

function get_line_discussion_expanded_input(line_number, discussion_lane) {
  return get_discussion_shadow_root(line_number)?.querySelector(
    "#expanded-message-box"
  );
}

function get_line_discussion_expanded_input_container(
  line_number,
  discussion_lane
) {
  return get_discussion_shadow_root(line_number)?.querySelector(
    "#expanded-message"
  );
}

// Arrow navigation on the audit page logic

function handle_discussion_escape(event) {
  if (event.key === "Escape") {
    console.log("Escaping discussion");
    event.preventDefault();
    get_line_discussion_entry(
      current_selected_line_number,
      discussion_lane
    )?.blur();
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
    console.log("Down to ", current_selected_line_number);
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
      .querySelector("#audit-page")
      ?.shadowRoot?.querySelectorAll("line-discussion")?.length ?? current_line;

  let line = current_line;
  // For page up/down, first jump by step amount
  if (step > 1) {
    line = Math.max(1, Math.min(max_lines, line + direction * step));
  } else {
    line += direction;
  }

  while (line >= 1 && line <= max_lines) {
    if (line < 1 || line > max_lines) break;

    if (get_line_discussion_entry(line, discussion_lane)) {
      return line;
    }

    // If we missed, check the next line
    line += direction;
  }
  return current_line; // Return original line if no discussion found
}

function focus_line_discussion(line_number, discussion_lane) {
  get_line_discussion_entry(line_number, discussion_lane)?.focus();
}

function get_line_discussion_entry(line_number, discussion_lane) {
  return document
    .querySelector("#audit-page")
    ?.shadowRoot?.querySelector(`#L${line_number} .discussion-entry`);
}

function get_discussion_shadow_root(line_number) {
  return document
    .querySelector("#audit-page")
    ?.shadowRoot?.querySelector(`#L${line_number} line-discussion`)?.shadowRoot;
}
