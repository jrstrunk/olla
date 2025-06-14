import filepath
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result

pub type Declaration {
  SourceDeclaration(
    topic_id: String,
    name: String,
    signature: List(PreProcessedSnippetLine),
    scope: Scope,
    id: Int,
    kind: DeclarationKind,
    source_map: SourceMap,
    references: List(Reference),
    calls: List(String),
    errors: List(String),
  )
  TextDeclaration(
    topic_id: String,
    name: String,
    signature: String,
    scope: Scope,
  )
}

pub fn encode_declaration(declaration: Declaration) -> json.Json {
  case declaration {
    SourceDeclaration(
      id:,
      topic_id:,
      name:,
      scope:,
      signature:,
      kind:,
      source_map:,
      references:,
      calls:,
      errors:,
    ) ->
      json.object([
        #("v", json.string("s")),
        #("i", json.int(id)),
        #("t", json.string(topic_id)),
        #("n", json.string(name)),
        #("s", encode_scope(scope)),
        #("g", json.array(signature, pre_processed_snippet_line_to_json)),
        #("k", encode_declaration_kind(kind)),
        #("m", encode_source_map(source_map)),
        #("r", json.array(references, encode_reference)),
        #("c", json.array(calls, json.string)),
        #("e", json.array(errors, json.string)),
      ])
    TextDeclaration(topic_id:, name:, signature:, scope:) ->
      json.object([
        #("v", json.string("t")),
        #("t", json.string(topic_id)),
        #("n", json.string(name)),
        #("g", json.string(signature)),
        #("s", encode_scope(scope)),
      ])
  }
}

pub fn declaration_decoder() -> decode.Decoder(Declaration) {
  use variant <- decode.field("v", decode.string)
  case variant {
    "s" -> {
      use topic_id <- decode.field("t", decode.string)
      use name <- decode.field("n", decode.string)
      use signature <- decode.field(
        "g",
        decode.list(pre_processed_snippet_line_decoder()),
      )
      use scope <- decode.field("s", scope_decoder())
      use id <- decode.field("i", decode.int)
      use kind <- decode.field("k", declaration_kind_decoder())
      use source_map <- decode.field("m", source_map_decoder())
      use references <- decode.field("r", decode.list(reference_decoder()))
      use calls <- decode.field("c", decode.list(decode.string))
      use errors <- decode.field("e", decode.list(decode.string))
      decode.success(SourceDeclaration(
        topic_id:,
        name:,
        signature:,
        scope:,
        id:,
        kind:,
        source_map:,
        references:,
        calls:,
        errors:,
      ))
    }
    "t" -> {
      use topic_id <- decode.field("t", decode.string)
      use name <- decode.field("n", decode.string)
      use signature <- decode.field("g", decode.string)
      use scope <- decode.field("s", scope_decoder())
      decode.success(TextDeclaration(topic_id:, name:, signature:, scope:))
    }
    _ ->
      decode.failure(
        TextDeclaration(
          topic_id: "",
          name: "",
          signature: "",
          scope: Scope("", option.None, option.None),
        ),
        "Declaration",
      )
  }
}

pub const unknown_declaration = SourceDeclaration(
  "",
  "",
  [],
  Scope("", option.None, option.None),
  0,
  UnknownDeclaration,
  SourceMap(-1, -1),
  [],
  [],
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
  "/"
  <> decaration.scope.file
  <> "#"
  <> declaration_to_qualified_name(decaration)
}

pub fn declaration_to_qualified_name(decaration: Declaration) {
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

pub type SourceMap {
  SourceMap(start: Int, length: Int)
}

fn encode_source_map(source_map: SourceMap) -> json.Json {
  let SourceMap(start:, length:) = source_map
  json.object([#("s", json.int(start)), #("l", json.int(length))])
}

fn source_map_decoder() -> decode.Decoder(SourceMap) {
  use start <- decode.field("s", decode.int)
  use length <- decode.field("l", decode.int)
  decode.success(SourceMap(start:, length:))
}

pub fn get_source_map_end(source_map: SourceMap) {
  source_map.start + source_map.length
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

pub fn declaration_kind_decoder() {
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
    parent_topic_id: String,
    scope: Scope,
    kind: NodeReferenceKind,
    source: SourceKind,
  )
}

pub fn encode_reference(node_reference: Reference) {
  let Reference(parent_topic_id:, scope:, kind:, source:) = node_reference
  json.object([
    #("i", json.string(parent_topic_id)),
    #("s", encode_scope(scope)),
    #("k", encode_node_reference_kind(kind)),
    #("c", encode_source_kind(source)),
  ])
}

pub fn reference_decoder() {
  use parent_topic_id <- decode.field("i", decode.string)
  use scope <- decode.field("s", scope_decoder())
  use kind <- decode.field("k", node_reference_kind_decoder())
  use source <- decode.field("c", source_kind_decoder())
  decode.success(Reference(scope:, parent_topic_id:, kind:, source:))
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

pub fn find_reference(
  for name: String,
  with declarations: dict.Dict(String, Declaration),
) {
  let declarations = dict.values(declarations)

  list.find(declarations, fn(dec) { declaration_to_qualified_name(dec) == name })
  |> result.try_recover(fn(_) {
    // If exactly one declaration matches the unqualified name, use it
    case list.filter(declarations, fn(dec) { dec.name == name }) {
      [unique_decl] -> Ok(unique_decl)
      _ -> Error(Nil)
    }
  })
  |> result.map(fn(dec) { dec.topic_id })
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

pub fn node_id_to_topic_id(declaration_id, source_kind source_kind) {
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

pub type PreProcessedSnippetLine {
  SourceSnippetLine(
    elements: List(PreProcessedNode),
    topic_id: option.Option(String),
    leading_spaces: Int,
  )
  TextSnippetLine(elements: List(PreProcessedNode))
}

fn pre_processed_snippet_line_to_json(
  pre_processed_snippet_line: PreProcessedSnippetLine,
) -> json.Json {
  case pre_processed_snippet_line {
    SourceSnippetLine(topic_id:, elements:, leading_spaces:) ->
      json.object([
        #("v", json.string("s")),
        #("t", json.nullable(topic_id, json.string)),
        #("e", json.array(elements, encode_pre_processed_node)),
        #("l", json.int(leading_spaces)),
      ])
    TextSnippetLine(elements:) ->
      json.object([
        #("v", json.string("t")),
        #("e", json.array(elements, encode_pre_processed_node)),
      ])
  }
}

fn pre_processed_snippet_line_decoder() -> decode.Decoder(
  PreProcessedSnippetLine,
) {
  use variant <- decode.field("v", decode.string)
  case variant {
    "s" -> {
      use topic_id <- decode.field("t", decode.optional(decode.string))
      use elements <- decode.field(
        "e",
        decode.list(pre_processed_node_decoder()),
      )
      use leading_spaces <- decode.field("l", decode.int)
      decode.success(SourceSnippetLine(topic_id:, elements:, leading_spaces:))
    }
    "t" -> {
      use elements <- decode.field(
        "e",
        decode.list(pre_processed_node_decoder()),
      )
      decode.success(TextSnippetLine(elements:))
    }
    _ ->
      decode.failure(TextSnippetLine(elements: []), "PreProcessedSnippetLine")
  }
}

pub type PreProcessedLine {
  PreProcessedLine(
    topic_id: option.Option(String),
    elements: List(PreProcessedNode),
    line_number: Int,
    columns: Int,
    line_number_text: String,
    line_tag: String,
    level: Int,
    kind: SourceKind,
  )
}

pub fn encode_pre_processed_line(
  pre_processed_line: PreProcessedLine,
) -> json.Json {
  let PreProcessedLine(
    topic_id:,
    elements:,
    line_number:,
    columns:,
    line_number_text: _,
    line_tag: _,
    level:,
    kind:,
  ) = pre_processed_line

  json.object([
    #("v", json.string("s")),
    #("t", json.nullable(topic_id, json.string)),
    #("e", json.array(elements, encode_pre_processed_node)),
    #("n", json.int(line_number)),
    #("c", json.int(columns)),
    #("l", json.int(level)),
    #("k", encode_source_kind(kind)),
  ])
}

pub fn pre_processed_line_decoder() -> decode.Decoder(PreProcessedLine) {
  use topic_id <- decode.field("t", decode.optional(decode.string))
  use elements <- decode.field("e", decode.list(pre_processed_node_decoder()))
  use line_number <- decode.field("n", decode.int)
  use columns <- decode.field("c", decode.int)
  let line_number_text = line_number |> int.to_string
  use level <- decode.field("l", decode.int)
  use kind <- decode.field("k", source_kind_decoder())
  decode.success(PreProcessedLine(
    topic_id:,
    elements:,
    line_number:,
    columns:,
    line_number_text:,
    line_tag: "L" <> line_number_text,
    level:,
    kind:,
  ))
}

pub type PreProcessedNode {
  PreProcessedDeclaration(topic_id: String, tokens: String)
  PreProcessedReference(topic_id: String, tokens: String)
  PreProcessedNode(element: String)
  PreProcessedGapNode(element: String, leading_spaces: Int)
  FormatterNewline
  FormatterBlock(nodes: List(PreProcessedNode))
  FormatterHeader(level: Int)
}

fn encode_pre_processed_node(pre_processed_node: PreProcessedNode) -> json.Json {
  case pre_processed_node {
    PreProcessedDeclaration(..) ->
      json.object([
        #("v", json.string("d")),
        #("t", json.string(pre_processed_node.topic_id)),
        #("n", json.string(pre_processed_node.tokens)),
      ])
    PreProcessedReference(..) ->
      json.object([
        #("v", json.string("r")),
        #("t", json.string(pre_processed_node.topic_id)),
        #("n", json.string(pre_processed_node.tokens)),
      ])
    PreProcessedNode(..) ->
      json.object([
        #("v", json.string("n")),
        #("e", json.string(pre_processed_node.element)),
      ])
    PreProcessedGapNode(..) ->
      json.object([
        #("v", json.string("g")),
        #("e", json.string(pre_processed_node.element)),
        #("s", json.int(pre_processed_node.leading_spaces)),
      ])
    FormatterNewline -> json.object([#("v", json.string("l"))])
    FormatterBlock(nodes) ->
      json.object([
        #("v", json.string("b")),
        #("n", json.array(nodes, encode_pre_processed_node)),
      ])
    FormatterHeader(level) ->
      json.object([#("v", json.string("h")), #("l", json.int(level))])
  }
}

fn pre_processed_node_decoder() -> decode.Decoder(PreProcessedNode) {
  use variant <- decode.field("v", decode.string)
  case variant {
    "d" -> {
      use topic_id <- decode.field("t", decode.string)
      use tokens <- decode.field("n", decode.string)
      decode.success(PreProcessedDeclaration(topic_id:, tokens:))
    }
    "r" -> {
      use topic_id <- decode.field("t", decode.string)
      use tokens <- decode.field("n", decode.string)
      decode.success(PreProcessedReference(topic_id:, tokens:))
    }
    "n" -> {
      use element <- decode.field("e", decode.string)
      decode.success(PreProcessedNode(element:))
    }
    "g" -> {
      use element <- decode.field("e", decode.string)
      use leading_spaces <- decode.field("s", decode.int)
      decode.success(PreProcessedGapNode(element:, leading_spaces:))
    }
    "l" -> decode.success(FormatterNewline)
    "b" -> {
      use nodes <- decode.field("n", decode.list(pre_processed_node_decoder()))
      decode.success(FormatterBlock(nodes:))
    }
    "h" -> {
      use level <- decode.field("l", decode.int)
      decode.success(FormatterHeader(level:))
    }
    _ -> decode.failure(PreProcessedNode(""), "PreProcessedNode")
  }
}
