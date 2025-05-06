import filepath
import gleam/dynamic/decode
import gleam/int
import gleam/json
import o11a/declaration

pub type SourceKind {
  Solidity
  Text
}

/// Classifies based on the file extension of the path, so it can be passed
/// an absolute path, a relative path, or just the file name
pub fn classify_source_kind(path path: String) {
  case filepath.extension(path) {
    Ok("sol") -> Ok(Solidity)
    Ok("md") | Ok("dj") -> Ok(Text)
    _ -> Error(Nil)
  }
}

pub type PreProcessedLine {
  PreProcessedLine(
    significance: PreProcessedLineSignificance,
    line_number: Int,
    line_number_text: String,
    line_tag: String,
    line_id: String,
    leading_spaces: Int,
    elements: List(PreProcessedNode),
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
    #("e", json.array(pre_processed_line.elements, encode_pre_processed_node)),
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
  use elements <- decode.field("e", decode.list(pre_processed_node_decoder()))
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
  SingleDeclarationLine(signature: String, topic_id: String)
  NonEmptyLine
  EmptyLine
}

fn encode_pre_processed_line_significance(
  pre_processed_line_significance: PreProcessedLineSignificance,
) -> json.Json {
  case pre_processed_line_significance {
    SingleDeclarationLine(signature:, topic_id:) ->
      json.object([
        #("v", json.string("sdl")),
        #("g", json.string(signature)),
        #("t", json.string(topic_id)),
      ])
    NonEmptyLine -> json.object([#("v", json.string("nel"))])
    EmptyLine -> json.object([#("v", json.string("el"))])
  }
}

fn pre_processed_line_significance_decoder() -> decode.Decoder(
  PreProcessedLineSignificance,
) {
  use variant <- decode.field("v", decode.string)
  case variant {
    "sdl" -> {
      use signature <- decode.field("g", decode.string)
      use topic_id <- decode.field("t", decode.string)
      decode.success(SingleDeclarationLine(signature:, topic_id:))
    }
    "nel" -> decode.success(NonEmptyLine)
    "el" -> decode.success(EmptyLine)
    _ -> decode.failure(EmptyLine, "PreProcessedLineSignificance")
  }
}

pub type PreProcessedNode {
  PreProcessedDeclaration(
    node_id: Int,
    node_declaration: declaration.Declaration,
    tokens: String,
  )
  PreProcessedReference(
    referenced_node_id: Int,
    referenced_node_declaration: declaration.Declaration,
    tokens: String,
  )
  PreProcessedNode(element: String)
  PreProcessedGapNode(element: String, leading_spaces: Int)
}

fn encode_pre_processed_node(pre_processed_node: PreProcessedNode) -> json.Json {
  case pre_processed_node {
    PreProcessedDeclaration(..) ->
      json.object([
        #("v", json.string("ppd")),
        #("i", json.int(pre_processed_node.node_id)),
        #(
          "d",
          declaration.encode_declaration(pre_processed_node.node_declaration),
        ),
        #("t", json.string(pre_processed_node.tokens)),
      ])
    PreProcessedReference(..) ->
      json.object([
        #("v", json.string("ppr")),
        #("i", json.int(pre_processed_node.referenced_node_id)),
        #(
          "d",
          declaration.encode_declaration(
            pre_processed_node.referenced_node_declaration,
          ),
        ),
        #("t", json.string(pre_processed_node.tokens)),
      ])
    PreProcessedNode(..) ->
      json.object([
        #("v", json.string("ppn")),
        #("e", json.string(pre_processed_node.element)),
      ])
    PreProcessedGapNode(..) ->
      json.object([
        #("v", json.string("ppgn")),
        #("e", json.string(pre_processed_node.element)),
        #("s", json.int(pre_processed_node.leading_spaces)),
      ])
  }
}

fn pre_processed_node_decoder() -> decode.Decoder(PreProcessedNode) {
  use variant <- decode.field("v", decode.string)
  case variant {
    "ppd" -> {
      use node_id <- decode.field("i", decode.int)
      use node_declaration <- decode.field(
        "d",
        declaration.declaration_decoder(),
      )
      use tokens <- decode.field("t", decode.string)
      decode.success(PreProcessedDeclaration(
        node_id:,
        node_declaration:,
        tokens:,
      ))
    }
    "ppr" -> {
      use referenced_node_id <- decode.field("i", decode.int)
      use referenced_node_declaration <- decode.field(
        "d",
        declaration.declaration_decoder(),
      )
      use tokens <- decode.field("t", decode.string)
      decode.success(PreProcessedReference(
        referenced_node_id:,
        referenced_node_declaration:,
        tokens:,
      ))
    }
    "ppn" -> {
      use element <- decode.field("e", decode.string)
      decode.success(PreProcessedNode(element:))
    }
    "ppgn" -> {
      use element <- decode.field("e", decode.string)
      use leading_spaces <- decode.field("s", decode.int)
      decode.success(PreProcessedGapNode(element:, leading_spaces:))
    }
    _ -> decode.failure(PreProcessedNode(""), "PreProcessedNode")
  }
}
