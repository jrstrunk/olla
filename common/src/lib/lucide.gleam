import lustre/attribute.{type Attribute, attribute}
import lustre/element/svg

pub fn messages_square(attributes: List(Attribute(a))) {
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
      svg.path([
        attribute(
          "d",
          "M14 9a2 2 0 0 1-2 2H6l-4 4V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2z",
        ),
      ]),
      svg.path([
        attribute("d", "M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1"),
      ]),
    ],
  )
}

pub fn pencil_ruler(attributes: List(Attribute(a))) {
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
      svg.path([
        attribute(
          "d",
          "M13 7 8.7 2.7a2.41 2.41 0 0 0-3.4 0L2.7 5.3a2.41 2.41 0 0 0 0 3.4L7 13",
        ),
      ]),
      svg.path([attribute("d", "m8 6 2-2")]),
      svg.path([attribute("d", "m18 16 2-2")]),
      svg.path([
        attribute(
          "d",
          "m17 11 4.3 4.3c.94.94.94 2.46 0 3.4l-2.6 2.6c-.94.94-2.46.94-3.4 0L11 17",
        ),
      ]),
      svg.path([
        attribute(
          "d",
          "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",
        ),
      ]),
      svg.path([attribute("d", "m15 5 4 4")]),
    ],
  )
}

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

pub fn maximize_2(attributes: List(Attribute(a))) {
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
      svg.polyline([attribute("points", "15 3 21 3 21 9")]),
      svg.polyline([attribute("points", "9 21 3 21 3 15")]),
      svg.line([
        attribute("y2", "10"),
        attribute("y1", "3"),
        attribute("x2", "14"),
        attribute("x1", "21"),
      ]),
      svg.line([
        attribute("y2", "14"),
        attribute("y1", "21"),
        attribute("x2", "10"),
        attribute("x1", "3"),
      ]),
    ],
  )
}

pub fn x(attributes: List(Attribute(a))) {
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
      svg.path([attribute("d", "M18 6 6 18")]),
      svg.path([attribute("d", "m6 6 12 12")]),
    ],
  )
}

pub fn minimize_2(attributes: List(Attribute(a))) {
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
      svg.polyline([attribute("points", "4 14 10 14 10 20")]),
      svg.polyline([attribute("points", "20 10 14 10 14 4")]),
      svg.line([
        attribute("y2", "3"),
        attribute("y1", "10"),
        attribute("x2", "21"),
        attribute("x1", "14"),
      ]),
      svg.line([
        attribute("y2", "14"),
        attribute("y1", "21"),
        attribute("x2", "10"),
        attribute("x1", "3"),
      ]),
    ],
  )
}

pub fn pencil(attributes: List(Attribute(a))) {
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
      svg.path([
        attribute(
          "d",
          "M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z",
        ),
      ]),
      svg.path([attribute("d", "m15 5 4 4")]),
    ],
  )
}

pub fn square_arrow_out_up_right(attributes: List(Attribute(a))) {
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
      svg.path([
        attribute(
          "d",
          "M21 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h6",
        ),
      ]),
      svg.path([attribute("d", "m21 3-9 9")]),
      svg.path([attribute("d", "M15 3h6v6")]),
    ],
  )
}

pub fn copy(attributes) {
  svg.svg(
    [
      attribute("width", "24"),
      attribute("height", "24"),
      attribute("viewBox", "0 0 24 24"),
      attribute("fill", "none"),
      attribute("stroke", "currentColor"),
      attribute("stroke-width", "2"),
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute("class", "lucide lucide-copy-icon lucide-copy"),
      ..attributes
    ],
    [
      svg.rect([
        attribute("width", "14"),
        attribute("height", "14"),
        attribute("x", "8"),
        attribute("y", "8"),
        attribute("rx", "2"),
        attribute("ry", "2"),
      ]),
      svg.path([
        attribute(
          "d",
          "M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2",
        ),
      ]),
    ],
  )
}

pub fn square_arrow_right(attributes) {
  svg.svg(
    [
      attribute("width", "24"),
      attribute("height", "24"),
      attribute("viewBox", "0 0 24 24"),
      attribute("fill", "none"),
      attribute("stroke", "currentColor"),
      attribute("stroke-width", "2"),
      attribute("stroke-linecap", "round"),
      attribute("stroke-linejoin", "round"),
      attribute(
        "class",
        "lucide lucide-square-arrow-right-icon lucide-square-arrow-right",
      ),
      ..attributes
    ],
    [
      svg.rect([
        attribute("width", "18"),
        attribute("height", "18"),
        attribute("x", "3"),
        attribute("y", "3"),
        attribute("rx", "2"),
      ]),
      svg.path([attribute("d", "M8 8h8v8")]),
      svg.path([attribute("d", "m8 16 8-8")]),
    ],
  )
}
