@external(javascript, "../../storage_ffi.mjs", "set_current_line_number")
pub fn set_current_line_number(line_number: Int) -> Nil

@external(javascript, "../../storage_ffi.mjs", "get_current_line_number")
pub fn current_line_number() -> Int

@external(javascript, "../../storage_ffi.mjs", "set_current_column_number")
pub fn set_current_column_number(column_number: Int) -> Nil

@external(javascript, "../../storage_ffi.mjs", "get_current_column_number")
pub fn current_column_number() -> Int

@external(javascript, "../../storage_ffi.mjs", "set_current_line_column_count")
pub fn set_current_line_column_count(column_count: Int) -> Nil

@external(javascript, "../../storage_ffi.mjs", "get_current_line_column_count")
pub fn current_line_column_count() -> Int

@external(javascript, "../../storage_ffi.mjs", "set_is_user_typing")
pub fn set_is_user_typing(is_typing: Bool) -> Nil

@external(javascript, "../../storage_ffi.mjs", "get_is_user_typing")
pub fn is_user_typing() -> Bool
