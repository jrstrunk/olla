import filepath
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string

pub type Declaration {
  Declaration(
    id: Int,
    topic_id: String,
    name: String,
    signature: List(PreProcessedNode),
    scope: Scope,
    kind: DeclarationKind,
    references: List(Reference),
  )
}

pub fn encode_declaration(declaration: Declaration) -> json.Json {
  case declaration {
    Declaration(id:, topic_id:, name:, scope:, signature:, kind:, references:) ->
      json.object([
        #("i", json.int(id)),
        #("t", json.string(topic_id)),
        #("n", json.string(name)),
        #("s", encode_scope(scope)),
        #("g", json.array(signature, encode_pre_processed_node)),
        #("k", encode_declaration_kind(kind)),
        #("r", json.array(references, encode_reference)),
      ])
  }
}

pub fn declaration_decoder() -> decode.Decoder(Declaration) {
  use id <- decode.field("i", decode.int)
  use topic_id <- decode.field("t", decode.string)
  use name <- decode.field("n", decode.string)
  use scope <- decode.field("s", scope_decoder())
  use signature <- decode.field("g", decode.list(pre_processed_node_decoder()))
  use kind <- decode.field("k", decode_declaration_kind())
  use references <- decode.field("r", decode.list(reference_decoder()))
  decode.success(Declaration(
    id:,
    topic_id:,
    name:,
    scope:,
    signature:,
    kind:,
    references:,
  ))
}

pub const unknown_declaration = Declaration(
  0,
  "",
  "",
  [],
  Scope("", option.None, option.None),
  UnknownDeclaration,
  [],
)

pub type Scope {
  Scope(
    file: String,
    contract: option.Option(String),
    member: option.Option(String),
  )
}

fn encode_scope(scope: Scope) -> json.Json {
  let Scope(file:, contract:, member:) = scope
  json.object(
    [
      [#("f", json.string(file))],
      case contract {
        option.None -> []
        option.Some(contract) -> [#("c", json.string(contract))]
      },
      case member {
        option.None -> []
        option.Some(member) -> [#("m", json.string(member))]
      },
    ]
    |> list.flatten,
  )
}

fn scope_decoder() -> decode.Decoder(Scope) {
  use file <- decode.field("f", decode.string)
  use contract <- decode.optional_field(
    "c",
    option.None,
    decode.optional(decode.string),
  )
  use member <- decode.optional_field(
    "m",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(Scope(file:, contract:, member:))
}

pub fn contract_scope_to_string(scope: Scope) {
  scope.contract
  |> option.unwrap("")
  <> option.map(scope.member, fn(member) { "." <> member })
  |> option.unwrap("")
}

pub fn declaration_to_link(decaration: Declaration) {
  "/" <> decaration.scope.file <> "#" <> declaration_to_id(decaration)
}

pub fn declaration_to_id(decaration: Declaration) {
  case decaration.scope.contract {
    option.Some(contract) ->
      contract
      <> case decaration.scope.member {
        option.Some(member) -> "." <> member <> ":" <> decaration.name
        option.None -> "." <> decaration.name
      }
    option.None -> decaration.name
  }
}

pub fn reference_to_link(reference: Reference) {
  "/"
  <> reference.scope.file
  <> "#"
  <> case reference.scope.contract {
    option.Some(contract) ->
      contract
      <> case reference.scope.member {
        option.Some(member) -> "." <> member
        option.None -> ""
      }
    option.None -> ""
  }
}

pub type DeclarationKind {
  ContractDeclaration(contract_kind: ContractKind)
  FunctionDeclaration(function_kind: FunctionKind)
  ModifierDeclaration
  VariableDeclaration
  ConstantDeclaration
  EnumDeclaration
  EnumValueDeclaration
  StructDeclaration
  ErrorDeclaration
  EventDeclaration
  LineDeclaration
  UnknownDeclaration
}

pub type ContractKind {
  Contract
  Interface
  Library
  Abstract
}

pub type FunctionKind {
  Function
  Constructor
  Fallback
  Receive
}

pub fn encode_declaration_kind(kind) {
  case kind {
    ContractDeclaration(Contract) -> json.string("c")
    ContractDeclaration(Interface) -> json.string("i")
    ContractDeclaration(Library) -> json.string("l")
    ContractDeclaration(Abstract) -> json.string("a")
    FunctionDeclaration(Function) -> json.string("f")
    FunctionDeclaration(Constructor) -> json.string("cn")
    FunctionDeclaration(Fallback) -> json.string("fb")
    FunctionDeclaration(Receive) -> json.string("r")
    ModifierDeclaration -> json.string("m")
    VariableDeclaration -> json.string("v")
    ConstantDeclaration -> json.string("ct")
    EnumDeclaration -> json.string("en")
    EnumValueDeclaration -> json.string("nv")
    StructDeclaration -> json.string("s")
    ErrorDeclaration -> json.string("er")
    EventDeclaration -> json.string("ev")
    LineDeclaration -> json.string("ln")
    UnknownDeclaration -> json.string("u")
  }
}

pub fn decode_declaration_kind() {
  use variant <- decode.map(decode.string)
  case variant {
    "c" -> ContractDeclaration(Contract)
    "i" -> ContractDeclaration(Interface)
    "l" -> ContractDeclaration(Library)
    "a" -> ContractDeclaration(Abstract)
    "f" -> FunctionDeclaration(Function)
    "cn" -> FunctionDeclaration(Constructor)
    "fb" -> FunctionDeclaration(Fallback)
    "r" -> FunctionDeclaration(Receive)
    "m" -> ModifierDeclaration
    "v" -> VariableDeclaration
    "ct" -> ConstantDeclaration
    "en" -> EnumDeclaration
    "nv" -> EnumValueDeclaration
    "s" -> StructDeclaration
    "er" -> ErrorDeclaration
    "ev" -> EventDeclaration
    "ln" -> LineDeclaration
    "u" -> UnknownDeclaration
    _ -> UnknownDeclaration
  }
}

pub fn declaration_kind_to_string(kind) {
  case kind {
    ContractDeclaration(Contract) -> "contract"
    ContractDeclaration(Interface) -> "interface"
    ContractDeclaration(Library) -> "library"
    ContractDeclaration(Abstract) -> "abstract contract"
    FunctionDeclaration(Function) -> "function"
    FunctionDeclaration(Constructor) -> "constructor"
    FunctionDeclaration(Fallback) -> "fallback"
    FunctionDeclaration(Receive) -> "receive"
    ModifierDeclaration -> "modifier"
    VariableDeclaration -> "variable"
    ConstantDeclaration -> "constant"
    EnumDeclaration -> "enum"
    EnumValueDeclaration -> "enum value"
    StructDeclaration -> "struct"
    ErrorDeclaration -> "error"
    EventDeclaration -> "event"
    LineDeclaration -> "line"
    UnknownDeclaration -> "unknown"
  }
}

pub fn contract_kind_to_string(kind) {
  case kind {
    Contract -> "contract"
    Interface -> "interface"
    Library -> "library"
    Abstract -> "abstract contract"
  }
}

pub fn contract_kind_from_string(kind) {
  case kind {
    "contract" -> Contract
    "interface" -> Interface
    "library" -> Library
    "abstract contract" -> Abstract
    "abstract" -> Abstract
    _ -> panic as "Invalid contract kind given"
  }
}

pub fn function_kind_from_string(kind) {
  case kind {
    "function" -> Function
    "constructor" -> Constructor
    "fallback" -> Fallback
    "receive" -> Receive
    _ -> panic as "Invalid function kind given"
  }
}

/// A reference to a node in the AST, only possible to be done in the source
/// code
pub type Reference {
  Reference(
    parent_id: Int,
    scope: Scope,
    kind: NodeReferenceKind,
    source: SourceKind,
  )
}

pub fn encode_reference(node_reference: Reference) {
  let Reference(parent_id:, scope:, kind:, source:) = node_reference
  json.object([
    #("i", json.int(parent_id)),
    #("s", encode_scope(scope)),
    #("k", encode_node_reference_kind(kind)),
    #("c", encode_source_kind(source)),
  ])
}

pub fn reference_decoder() {
  use parent_id <- decode.field("i", decode.int)
  use scope <- decode.field("s", scope_decoder())
  use kind <- decode.field("k", node_reference_kind_decoder())
  use source <- decode.field("c", source_kind_decoder())
  decode.success(Reference(scope:, parent_id:, kind:, source:))
}

pub type NodeReferenceKind {
  CallReference
  MutationReference
  InheritanceReference
  AccessReference
  UsingReference
  TypeReference
}

fn encode_node_reference_kind(node_reference_kind: NodeReferenceKind) {
  case node_reference_kind {
    CallReference -> json.string("c")
    MutationReference -> json.string("m")
    InheritanceReference -> json.string("i")
    AccessReference -> json.string("a")
    UsingReference -> json.string("u")
    TypeReference -> json.string("t")
  }
}

fn node_reference_kind_decoder() {
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

pub fn get_references(
  in message: String,
  with declarations: dict.Dict(String, Declaration),
) {
  string.split(message, on: " ")
  |> list.filter_map(fn(word) {
    use ref <- result.try({
      case word {
        "#" <> ref -> Ok(ref)
        _ -> Error(Nil)
      }
    })

    let declarations = dict.values(declarations)

    list.find(declarations, fn(dec) {
      contract_scope_to_string(dec.scope) <> "." <> dec.name == ref
    })
    |> result.try_recover(fn(_) {
      list.find(declarations, fn(dec) { dec.name == ref })
    })
    |> result.map(fn(dec) { dec.topic_id })
  })
}

pub fn encode_declaration_links(declaration_links: dict.Dict(Int, String)) {
  json.array(declaration_links |> dict.to_list, fn(declaration_link) {
    json.object([
      #("d", json.int(declaration_link.0)),
      #("l", json.string(declaration_link.1)),
    ])
  })
}

pub type SourceKind {
  Solidity
  Text
}

fn encode_source_kind(source_kind: SourceKind) -> json.Json {
  case source_kind {
    Solidity -> json.string("s")
    Text -> json.string("t")
  }
}

fn source_kind_decoder() -> decode.Decoder(SourceKind) {
  use variant <- decode.then(decode.string)
  case variant {
    "s" -> decode.success(Solidity)
    "t" -> decode.success(Text)
    _ -> decode.failure(Text, "SourceKind")
  }
}

pub fn declaration_id_to_topic_id(declaration_id, source_kind source_kind) {
  case source_kind {
    Solidity -> "S" <> int.to_string(declaration_id)
    Text -> "T" <> int.to_string(declaration_id)
  }
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

pub type AST(solidity_ast, text_ast) {
  SolidityAST(solidity_ast)
  TextAST(text_ast)
}

pub type PreProcessedLine {
  PreProcessedLine(
    significance: PreProcessedLineSignificance,
    line_number: Int,
    line_number_text: String,
    line_tag: String,
    leading_spaces: Int,
    elements: List(PreProcessedNode),
    columns: Int,
    kind: PreProcessedLineKind,
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
    #("l", json.int(pre_processed_line.leading_spaces)),
    #("e", json.array(pre_processed_line.elements, encode_pre_processed_node)),
    #("c", json.int(pre_processed_line.columns)),
    #("k", encode_pre_processed_line_kind(pre_processed_line.kind)),
  ])
}

pub fn pre_processed_line_decoder() -> decode.Decoder(PreProcessedLine) {
  use significance <- decode.field(
    "s",
    pre_processed_line_significance_decoder(),
  )
  use line_number <- decode.field("n", decode.int)
  use leading_spaces <- decode.field("l", decode.int)
  use elements <- decode.field("e", decode.list(pre_processed_node_decoder()))
  use columns <- decode.field("c", decode.int)
  let line_number_text = line_number |> int.to_string
  use kind <- decode.field("k", pre_processed_line_kind_decoder())
  decode.success(PreProcessedLine(
    significance:,
    line_number:,
    line_number_text:,
    line_tag: "L" <> line_number_text,
    leading_spaces:,
    elements:,
    columns:,
    kind:,
  ))
}

pub type PreProcessedLineSignificance {
  SingleDeclarationLine(topic_id: String)
  NonEmptyLine(topic_id: String)
  EmptyLine
}

fn encode_pre_processed_line_significance(
  pre_processed_line_significance: PreProcessedLineSignificance,
) -> json.Json {
  case pre_processed_line_significance {
    SingleDeclarationLine(topic_id:) ->
      json.object([#("v", json.string("sdl")), #("t", json.string(topic_id))])
    NonEmptyLine(topic_id:) ->
      json.object([#("v", json.string("nel")), #("t", json.string(topic_id))])
    EmptyLine -> json.object([#("v", json.string("el"))])
  }
}

fn pre_processed_line_significance_decoder() -> decode.Decoder(
  PreProcessedLineSignificance,
) {
  use variant <- decode.field("v", decode.string)
  case variant {
    "sdl" -> {
      use topic_id <- decode.field("t", decode.string)
      decode.success(SingleDeclarationLine(topic_id:))
    }
    "nel" -> {
      use topic_id <- decode.field("t", decode.string)
      decode.success(NonEmptyLine(topic_id:))
    }
    "el" -> decode.success(EmptyLine)
    _ -> decode.failure(EmptyLine, "PreProcessedLineSignificance")
  }
}

pub type PreProcessedLineKind {
  SoliditySourceLine
  TextLine
}

fn encode_pre_processed_line_kind(
  pre_processed_line_kind: PreProcessedLineKind,
) -> json.Json {
  case pre_processed_line_kind {
    SoliditySourceLine -> json.string("s")
    TextLine -> json.string("t")
  }
}

fn pre_processed_line_kind_decoder() -> decode.Decoder(PreProcessedLineKind) {
  use variant <- decode.then(decode.string)
  case variant {
    "s" -> decode.success(SoliditySourceLine)
    "t" -> decode.success(TextLine)
    _ -> decode.failure(TextLine, "PreProcessedLineKind")
  }
}

pub type PreProcessedNode {
  PreProcessedDeclaration(topic_id: String, tokens: String)
  PreProcessedReference(topic_id: String, tokens: String)
  PreProcessedNode(element: String)
  PreProcessedGapNode(element: String, leading_spaces: Int)
}

fn encode_pre_processed_node(pre_processed_node: PreProcessedNode) -> json.Json {
  case pre_processed_node {
    PreProcessedDeclaration(..) ->
      json.object([
        #("v", json.string("ppd")),
        #("t", json.string(pre_processed_node.topic_id)),
        #("n", json.string(pre_processed_node.tokens)),
      ])
    PreProcessedReference(..) ->
      json.object([
        #("v", json.string("ppr")),
        #("t", json.string(pre_processed_node.topic_id)),
        #("n", json.string(pre_processed_node.tokens)),
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
      use topic_id <- decode.field("t", decode.string)
      use tokens <- decode.field("n", decode.string)
      decode.success(PreProcessedDeclaration(topic_id:, tokens:))
    }
    "ppr" -> {
      use topic_id <- decode.field("t", decode.string)
      use tokens <- decode.field("n", decode.string)
      decode.success(PreProcessedReference(topic_id:, tokens:))
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
