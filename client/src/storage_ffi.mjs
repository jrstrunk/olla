let current_line_number = 16;

export function set_current_line_number(line_number) {
  current_line_number = line_number;
}

export function get_current_line_number() {
  return current_line_number;
}

let current_column_number = 1;

export function set_current_column_number(column_number) {
  current_column_number = column_number;
}

export function get_current_column_number() {
  return current_column_number;
}

let current_line_column_count = 16;

export function set_current_line_column_count(column_count) {
  current_line_column_count = column_count;
}

export function get_current_line_column_count() {
  return current_line_column_count;
}

let is_user_typing = false;

export function set_is_user_typing(is_typing) {
  is_user_typing = is_typing;
}

export function get_is_user_typing() {
  return is_user_typing;
}
