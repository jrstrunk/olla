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
  SingleDeclarationLine(topic_id: String, topic_title: String)
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
        #(
          "topic_title",
          json.string(pre_processed_line_significance.topic_title),
        ),
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
      use topic_title <- decode.field("topic_title", decode.string)
      decode.success(SingleDeclarationLine(topic_id:, topic_title:))
    }
    "non_empty_line" -> decode.success(NonEmptyLine)
    "empty_line" -> decode.success(EmptyLine)
    _ -> decode.failure(EmptyLine, "PreProcessedLineSignificance")
  }
}

pub type PreProcessedNode {
  PreProcessedDeclaration(
    node_id: Int,
    node_declaration: NodeDeclaration,
    tokens: String,
  )
  PreProcessedReference(
    referenced_node_id: Int,
    referenced_node_declaration: NodeDeclaration,
    tokens: String,
  )
  PreProcessedNode(element: String)
  PreProcessedGapNode(element: String, leading_spaces: Int)
}

fn encode_pre_processed_node(pre_processed_node: PreProcessedNode) -> json.Json {
  case pre_processed_node {
    PreProcessedDeclaration(..) ->
      json.object([
        #("type", json.string("pre_processed_declaration")),
        #("node_id", json.int(pre_processed_node.node_id)),
        #(
          "node_declaration",
          encode_node_declaration(pre_processed_node.node_declaration),
        ),
        #("tokens", json.string(pre_processed_node.tokens)),
      ])
    PreProcessedReference(..) ->
      json.object([
        #("type", json.string("pre_processed_reference")),
        #("referenced_node_id", json.int(pre_processed_node.referenced_node_id)),
        #(
          "referenced_node_declaration",
          encode_node_declaration(
            pre_processed_node.referenced_node_declaration,
          ),
        ),
        #("tokens", json.string(pre_processed_node.tokens)),
      ])
    PreProcessedNode(..) ->
      json.object([
        #("type", json.string("pre_processed_node")),
        #("element", json.string(pre_processed_node.element)),
      ])
    PreProcessedGapNode(..) ->
      json.object([
        #("type", json.string("pre_processed_gap_node")),
        #("element", json.string(pre_processed_node.element)),
        #("leading_spaces", json.int(pre_processed_node.leading_spaces)),
      ])
  }
}

fn pre_processed_node_decoder() -> decode.Decoder(PreProcessedNode) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "pre_processed_declaration" -> {
      use node_id <- decode.field("node_id", decode.int)
      use node_declaration <- decode.field(
        "node_declaration",
        node_declaration_decoder(),
      )
      use tokens <- decode.field("tokens", decode.string)
      decode.success(PreProcessedDeclaration(
        node_id:,
        node_declaration:,
        tokens:,
      ))
    }
    "pre_processed_reference" -> {
      use referenced_node_id <- decode.field("referenced_node_id", decode.int)
      use referenced_node_declaration <- decode.field(
        "referenced_node_declaration",
        node_declaration_decoder(),
      )
      use tokens <- decode.field("tokens", decode.string)
      decode.success(PreProcessedReference(
        referenced_node_id:,
        referenced_node_declaration:,
        tokens:,
      ))
    }
    "pre_processed_node" -> {
      use element <- decode.field("element", decode.string)
      decode.success(PreProcessedNode(element:))
    }
    "pre_processed_gap_node" -> {
      use element <- decode.field("element", decode.string)
      use leading_spaces <- decode.field("leading_spaces", decode.int)
      decode.success(PreProcessedGapNode(element:, leading_spaces:))
    }
    _ -> decode.failure(PreProcessedNode(""), "PreProcessedNode")
  }
}

pub type NodeDeclaration {
  NodeDeclaration(
    title: String,
    topic_id: String,
    kind: NodeDeclarationKind,
    references: List(NodeReference),
  )
}

pub const unknown_node_declaration = NodeDeclaration(
  "",
  "",
  UnknownDeclaration,
  [],
)

fn encode_node_declaration(node_declaration: NodeDeclaration) -> json.Json {
  json.object([
    #("title", json.string(node_declaration.title)),
    #("topic_id", json.string(node_declaration.topic_id)),
    #(
      "kind",
      json.string(node_declaration_kind_to_string(node_declaration.kind)),
    ),
    #(
      "references",
      json.array(node_declaration.references, encode_node_reference),
    ),
  ])
}

fn node_declaration_decoder() -> decode.Decoder(NodeDeclaration) {
  use title <- decode.field("title", decode.string)
  use topic_id <- decode.field("topic_id", decode.string)
  use kind <- decode.field("kind", decode.string)
  use references <- decode.field(
    "references",
    decode.list(node_reference_decoder()),
  )
  decode.success(NodeDeclaration(
    title:,
    topic_id:,
    kind: node_declaration_kind_from_string(kind),
    references:,
  ))
}

pub type NodeDeclarationKind {
  ContractDeclaration
  ConstructorDeclaration
  FunctionDeclaration
  FallbackDeclaration
  ReceiveDeclaration
  ModifierDeclaration
  VariableDeclaration
  ConstantDeclaration
  EnumDeclaration
  EnumValueDeclaration
  StructDeclaration
  ErrorDeclaration
  EventDeclaration
  UnknownDeclaration
}

pub fn node_declaration_kind_to_string(kind) {
  case kind {
    ContractDeclaration -> "contract"
    ConstructorDeclaration -> "constructor"
    FunctionDeclaration -> "function"
    FallbackDeclaration -> "fallback"
    ReceiveDeclaration -> "receive"
    ModifierDeclaration -> "modifier"
    VariableDeclaration -> "variable"
    ConstantDeclaration -> "constant"
    EnumDeclaration -> "enum"
    EnumValueDeclaration -> "enum_value"
    StructDeclaration -> "struct"
    ErrorDeclaration -> "error"
    EventDeclaration -> "event"
    UnknownDeclaration -> "unknown"
  }
}

fn node_declaration_kind_from_string(kind) {
  case kind {
    "contract" -> ContractDeclaration
    "constructor" -> ConstructorDeclaration
    "function" -> FunctionDeclaration
    "fallback" -> FallbackDeclaration
    "receive" -> ReceiveDeclaration
    "modifier" -> ModifierDeclaration
    "variable" -> VariableDeclaration
    "constant" -> ConstantDeclaration
    "enum" -> EnumDeclaration
    "enum_value" -> EnumValueDeclaration
    "struct" -> StructDeclaration
    "error" -> ErrorDeclaration
    "event" -> EventDeclaration
    "unknown" -> UnknownDeclaration
    _ -> UnknownDeclaration
  }
}

pub type NodeReference {
  NodeReference(title: String, topic_id: String)
}

fn encode_node_reference(node_reference: NodeReference) -> json.Json {
  json.object([
    #("title", json.string(node_reference.title)),
    #("topic_id", json.string(node_reference.topic_id)),
  ])
}

fn node_reference_decoder() -> decode.Decoder(NodeReference) {
  use title <- decode.field("title", decode.string)
  use topic_id <- decode.field("topic_id", decode.string)
  decode.success(NodeReference(title:, topic_id:))
}
