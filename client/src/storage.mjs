var is_user_typing_storage = false;

export function set_is_user_typing(value) {
  is_user_typing_storage = value;
}

export function is_user_typing() {
  return is_user_typing_storage;
}
