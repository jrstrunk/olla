import o11a/user_interface/line_notes

pub const name = line_notes.component_name

pub fn register() {
  line_notes.component()
  // |> lustre.register(name)
  // 
  // We could then call lustre register like so to register the component 
  // manually, but when we build this as a component with the lustre dev tools,
  // the produced javascript will automatically do this. If we ever build this
  // component in a different way, we'll need to register it manually.
}
