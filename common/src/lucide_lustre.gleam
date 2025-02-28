import lustre/attribute.{type Attribute, attribute}
import lustre/element/svg

pub fn list_collapse(attributes: List(Attribute(a))) {
  svg.svg(
    [
      attribute("stroke-linejoin", "round"),
      attribute("stroke-linecap", "round"),
      attribute("stroke-width", "2"),
      attribute("stroke", "currentColor"),
      attribute("fill", "none"),
      attribute("viewBox", "0 0 24 24"),
      attribute("height", "24"),
      attribute("width", "24"),
      ..attributes
    ],
    [
      svg.path([attribute("d", "m3 10 2.5-2.5L3 5")]),
      svg.path([attribute("d", "m3 19 2.5-2.5L3 14")]),
      svg.path([attribute("d", "M10 6h11")]),
      svg.path([attribute("d", "M10 12h11")]),
      svg.path([attribute("d", "M10 18h11")]),
    ],
  )
}
