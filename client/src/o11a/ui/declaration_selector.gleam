import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/preprocessor
import gleam/dict

pub fn view(
  declarations: dict.Dict(String, preprocessor.Declaration),
) {
    // html.div([attribute.class("max-w-9/10 max-h-9/10")], [
}