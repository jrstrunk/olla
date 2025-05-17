import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string

pub type Declaration {
  Declaration(
    name: String,
    signature: String,
    scope: Scope,
    topic_id: String,
    kind: DeclarationKind,
    references: List(Reference),
  )
}

pub fn encode_declaration(declaration: Declaration) -> json.Json {
  case declaration {
    Declaration(name:, scope:, topic_id:, signature:, kind:, references:) ->
      json.object([
        #("n", json.string(name)),
        #("s", encode_scope(scope)),
        #("t", json.string(topic_id)),
        #("g", json.string(signature)),
        #("k", encode_declaration_kind(kind)),
        #("r", json.array(references, encode_reference)),
      ])
  }
}

pub fn declaration_decoder() -> decode.Decoder(Declaration) {
  use name <- decode.field("n", decode.string)
  use scope <- decode.field("s", scope_decoder())
  use topic_id <- decode.field("t", decode.string)
  use signature <- decode.field("g", decode.string)
  use kind <- decode.field("k", decode_declaration_kind())
  use references <- decode.field("r", decode.list(reference_decoder()))
  decode.success(Declaration(
    name:,
    scope:,
    topic_id:,
    signature:,
    kind:,
    references:,
  ))
}

pub const unknown_declaration = Declaration(
  "",
  "",
  Scope("", option.None, option.None),
  "",
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
    EnumValueDeclaration -> "enum_value"
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
  Reference(scope: Scope, topic_id: String, kind: NodeReferenceKind)
}

pub fn encode_reference(node_reference: Reference) {
  json.object([
    #("s", encode_scope(node_reference.scope)),
    #("i", json.string(node_reference.topic_id)),
    #("k", encode_node_reference_kind(node_reference.kind)),
  ])
}

pub fn reference_decoder() {
  use scope <- decode.field("s", scope_decoder())
  use topic_id <- decode.field("i", decode.string)
  use kind <- decode.field("k", node_reference_kind_decoder())
  decode.success(Reference(scope:, topic_id:, kind:))
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

pub fn get_references(in message: String, with declarations: List(Declaration)) {
  string.split(message, on: " ")
  |> list.filter_map(fn(word) {
    use ref <- result.try({
      case word {
        "#" <> ref -> Ok(ref)
        _ -> Error(Nil)
      }
    })

    list.find(declarations, fn(dec) {
      contract_scope_to_string(dec.scope) <> "." <> dec.name == ref
    })
    |> result.try_recover(fn(_) {
      list.find(declarations, fn(dec) { dec.name == ref })
    })
    |> result.map(fn(dec) { dec.topic_id })
  })
}
