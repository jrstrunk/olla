import gleam/dynamic/decode
import gleam/int
import gleam/json

pub type PreProcessedLine {
  PreProcessedLine(
    significance: PreProcessedLineSignificance,
    line_number: Int,
    line_number_text: String,
    line_tag: String,
    line_id: String,
    leading_spaces: Int,
    elements: String,
    columns: Int,
  )
}

pub fn encode_pre_processed_line(
  pre_processed_line: PreProcessedLine,
) -> json.Json {
  json.object([
    #(
      "s",
      encode_pre_processed_line_significance(pre_processed_line.significance),
    ),
    #("n", json.int(pre_processed_line.line_number)),
    #("i", json.string(pre_processed_line.line_id)),
    #("l", json.int(pre_processed_line.leading_spaces)),
    #("e", json.string(pre_processed_line.elements)),
    #("c", json.int(pre_processed_line.columns)),
  ])
}

pub fn pre_processed_line_decoder() -> decode.Decoder(PreProcessedLine) {
  use significance <- decode.field(
    "s",
    pre_processed_line_significance_decoder(),
  )
  use line_number <- decode.field("n", decode.int)
  use line_id <- decode.field("i", decode.string)
  use leading_spaces <- decode.field("l", decode.int)
  use elements <- decode.field("e", decode.string)
  use columns <- decode.field("c", decode.int)
  let line_number_text = line_number |> int.to_string
  decode.success(PreProcessedLine(
    significance:,
    line_number:,
    line_number_text:,
    line_tag: "L" <> line_number_text,
    line_id:,
    leading_spaces:,
    elements:,
    columns:,
  ))
}

pub type PreProcessedLineSignificance {
  SingleDeclarationLine(topic_id: String)
  NonEmptyLine
  EmptyLine
}

fn encode_pre_processed_line_significance(
  pre_processed_line_significance: PreProcessedLineSignificance,
) -> json.Json {
  case pre_processed_line_significance {
    SingleDeclarationLine(..) ->
      json.object([
        #("type", json.string("single_declaration_line")),
        #("topic_id", json.string(pre_processed_line_significance.topic_id)),
      ])
    NonEmptyLine -> json.object([#("type", json.string("non_empty_line"))])
    EmptyLine -> json.object([#("type", json.string("empty_line"))])
  }
}

fn pre_processed_line_significance_decoder() -> decode.Decoder(
  PreProcessedLineSignificance,
) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "single_declaration_line" -> {
      use topic_id <- decode.field("topic_id", decode.string)
      decode.success(SingleDeclarationLine(topic_id:))
    }
    "non_empty_line" -> decode.success(NonEmptyLine)
    "empty_line" -> decode.success(EmptyLine)
    _ -> decode.failure(EmptyLine, "PreProcessedLineSignificance")
  }
}
