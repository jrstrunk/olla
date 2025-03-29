import lustre/attribute

pub fn encode_grid_location_data(
  line_number line_number,
  column_number column_number,
) {
  attribute.data("g", line_number <> ":" <> column_number)
}

pub fn encode_topic_id_data(topic_id) {
  attribute.data("i", topic_id)
}

pub fn encode_topic_title_data(topic_title) {
  attribute.data("t", topic_title)
}

pub fn encode_is_reference_data(is_reference) {
  attribute.data("r", case is_reference {
    True -> "1"
    False -> "0"
  })
}
