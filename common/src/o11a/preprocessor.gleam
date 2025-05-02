import filepath
import gleam/dynamic/decode
import gleam/int
import gleam/json
import o11a/audit_metadata

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
  SingleDeclarationLine(node_declaration: NodeDeclaration)
  NonEmptyLine
  EmptyLine
}

fn encode_pre_processed_line_significance(
  pre_processed_line_significance: PreProcessedLineSignificance,
) -> json.Json {
  case pre_processed_line_significance {
    SingleDeclarationLine(node_declaration:) ->
      json.object([
        #("v", json.string("sdl")),
        #("n", encode_node_declaration(node_declaration)),
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
      use node_declaration <- decode.field("n", node_declaration_decoder())
      decode.success(SingleDeclarationLine(node_declaration:))
    }
    "nel" -> decode.success(NonEmptyLine)
    "el" -> decode.success(EmptyLine)
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
        #("v", json.string("ppd")),
        #("i", json.int(pre_processed_node.node_id)),
        #("d", encode_node_declaration(pre_processed_node.node_declaration)),
        #("t", json.string(pre_processed_node.tokens)),
      ])
    PreProcessedReference(..) ->
      json.object([
        #("v", json.string("ppr")),
        #("i", json.int(pre_processed_node.referenced_node_id)),
        #(
          "d",
          encode_node_declaration(
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
      use node_declaration <- decode.field("d", node_declaration_decoder())
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
        node_declaration_decoder(),
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

pub type NodeDeclaration {
  NodeDeclaration(
    name: String,
    scoped_name: String,
    title: String,
    topic_id: String,
    kind: NodeDeclarationKind,
    references: List(NodeReference),
  )
}

pub const unknown_node_declaration = NodeDeclaration(
  "",
  "",
  "",
  "",
  UnknownDeclaration,
  [],
)

fn encode_node_declaration(node_declaration: NodeDeclaration) -> json.Json {
  json.object([
    #("n", json.string(node_declaration.name)),
    #("s", json.string(node_declaration.scoped_name)),
    #("t", json.string(node_declaration.title)),
    #("i", json.string(node_declaration.topic_id)),
    #("k", json.string(node_declaration_kind_to_string(node_declaration.kind))),
    #("r", json.array(node_declaration.references, encode_node_reference)),
  ])
}

fn node_declaration_decoder() -> decode.Decoder(NodeDeclaration) {
  use name <- decode.field("n", decode.string)
  use scoped_name <- decode.field("s", decode.string)
  use title <- decode.field("t", decode.string)
  use topic_id <- decode.field("i", decode.string)
  use kind <- decode.field("k", decode.string)
  use references <- decode.field("r", decode.list(node_reference_decoder()))
  decode.success(NodeDeclaration(
    name:,
    scoped_name:,
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

pub fn node_declaration_kind_to_metadata_declaration_kind(kind) {
  case kind {
    ContractDeclaration -> audit_metadata.AddressableContract
    FunctionDeclaration -> audit_metadata.AddressableFunction
    VariableDeclaration -> audit_metadata.AddressableVariable
    UnknownDeclaration -> audit_metadata.AddressableDocumentation
    ConstantDeclaration -> audit_metadata.AddressableVariable
    ConstructorDeclaration -> audit_metadata.AddressableFunction
    EnumDeclaration -> audit_metadata.AddressableVariable
    EnumValueDeclaration -> audit_metadata.AddressableVariable
    ErrorDeclaration -> audit_metadata.AddressableVariable
    EventDeclaration -> audit_metadata.AddressableVariable
    FallbackDeclaration -> audit_metadata.AddressableFunction
    ModifierDeclaration -> audit_metadata.AddressableFunction
    ReceiveDeclaration -> audit_metadata.AddressableFunction
    StructDeclaration -> audit_metadata.AddressableVariable
  }
}

pub type NodeReference {
  NodeReference(title: String, topic_id: String, kind: NodeReferenceKind)
}

fn encode_node_reference(node_reference: NodeReference) -> json.Json {
  json.object([
    #("t", json.string(node_reference.title)),
    #("i", json.string(node_reference.topic_id)),
    #("k", encode_node_reference_kind(node_reference.kind)),
  ])
}

fn node_reference_decoder() -> decode.Decoder(NodeReference) {
  use title <- decode.field("t", decode.string)
  use topic_id <- decode.field("i", decode.string)
  use kind <- decode.field("k", node_reference_kind_decoder())
  decode.success(NodeReference(title:, topic_id:, kind:))
}

pub type NodeReferenceKind {
  CallReference
  MutationReference
  InheritanceReference
  AccessReference
  UsingReference
  TypeReference
}

fn encode_node_reference_kind(
  node_reference_kind: NodeReferenceKind,
) -> json.Json {
  case node_reference_kind {
    CallReference -> json.string("c")
    MutationReference -> json.string("m")
    InheritanceReference -> json.string("i")
    AccessReference -> json.string("a")
    UsingReference -> json.string("u")
    TypeReference -> json.string("t")
  }
}

fn node_reference_kind_decoder() -> decode.Decoder(NodeReferenceKind) {
  use variant <- decode.then(decode.string)
  case variant {
    "c" -> decode.success(CallReference)
    "m" -> decode.success(MutationReference)
    "i" -> decode.success(InheritanceReference)
    "a" -> decode.success(AccessReference)
    "u" -> decode.success(UsingReference)
    "t" -> decode.success(TypeReference)
    _ -> decode.failure(CallReference, "NodeReferenceKind")
  }
}

pub fn node_reference_kind_to_annotation(kind) {
  case kind {
    CallReference -> "Called in:"
    MutationReference -> "Mutated in:"
    InheritanceReference -> "Inherited by:"
    AccessReference -> "Accessed in:"
    UsingReference -> "Used as a library in:"
    TypeReference -> "Used as a type in:"
  }
}
