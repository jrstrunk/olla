import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/server_component

pub fn server_component_with_skeleton(
  name: String,
  skeleton: element.Element(msg),
) {
  element.element(
    "lustre-server-component",
    [server_component.route("/" <> name)],
    [html.div([attribute.attribute("slot", "skeleton")], [skeleton])],
  )
}

pub fn hide_skeleton() {
  html.slot(
    [attribute.name("skeleton"), attribute.style("display", "none")],
    [],
  )
}
