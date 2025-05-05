import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/string

pub type AuditMetaData {
  AuditMetaData(
    audit_name: String,
    audit_formatted_name: String,
    in_scope_files: List(String),
    symbols: List(AddressableSymbol),
  )
}

pub fn encode_audit_metadata(audit_metadata: AuditMetaData) {
  json.object([
    #("audit_name", json.string(audit_metadata.audit_name)),
    #("audit_formatted_name", json.string(audit_metadata.audit_formatted_name)),
    #("in_scope_files", json.array(audit_metadata.in_scope_files, json.string)),
    #("symbols", json.array(audit_metadata.symbols, encode_addressable_symbol)),
  ])
}

pub fn audit_metadata_decoder() -> decode.Decoder(AuditMetaData) {
  use audit_name <- decode.field("audit_name", decode.string)
  use audit_formatted_name <- decode.field(
    "audit_formatted_name",
    decode.string,
  )
  use in_scope_files <- decode.field(
    "in_scope_files",
    decode.list(decode.string),
  )
  use symbols <- decode.field(
    "symbols",
    decode.list(addressable_symbol_decoder()),
  )

  decode.success(AuditMetaData(
    audit_name:,
    audit_formatted_name:,
    in_scope_files:,
    symbols:,
  ))
}

pub type AddressableSymbol {
  AddressableSymbol(
    name: String,
    scope: String,
    kind: AddressableSymbolKind,
    topic_id: String,
  )
}

pub fn addressable_symbol_decoder() -> decode.Decoder(AddressableSymbol) {
  use name <- decode.field("n", decode.string)
  use scope <- decode.field("s", decode.string)
  use kind <- decode.field("k", declaration_kind_decoder())
  use topic_id <- decode.field("i", decode.string)
  decode.success(AddressableSymbol(name:, scope:, kind:, topic_id:))
}

pub fn encode_addressable_symbol(declaration: AddressableSymbol) -> json.Json {
  let AddressableSymbol(name:, scope:, kind:, topic_id:) = declaration
  json.object([
    #("n", json.string(name)),
    #("s", json.string(scope)),
    #("k", encode_declaration_kind(kind)),
    #("i", json.string(topic_id)),
  ])
}

pub type AddressableSymbolKind {
  AddressableContract
  AddressableFunction
  AddressableVariable
  AddressableDocumentation
  AddressableLine
}

fn encode_declaration_kind(declaration_kind: AddressableSymbolKind) -> json.Json {
  case declaration_kind {
    AddressableContract -> json.string("c")
    AddressableFunction -> json.string("f")
    AddressableVariable -> json.string("v")
    AddressableDocumentation -> json.string("d")
    AddressableLine -> json.string("l")
  }
}

fn declaration_kind_decoder() -> decode.Decoder(AddressableSymbolKind) {
  use variant <- decode.then(decode.string)
  case variant {
    "c" -> decode.success(AddressableContract)
    "f" -> decode.success(AddressableFunction)
    "v" -> decode.success(AddressableVariable)
    "d" -> decode.success(AddressableDocumentation)
    "l" -> decode.success(AddressableLine)
    _ -> decode.failure(AddressableDocumentation, "DeclarationKind")
  }
}

pub type SourceFileMetaData {
  SourceFileMetaData(
    imports: dict.Dict(String, String),
    contracts: dict.Dict(String, ContractMetaData),
  )
}

pub type FunctionMetaData {
  FunctionMetaData(name: String)
}

pub type ContractMetaData {
  ContractMetaData(
    name: String,
    kind: ContractKind,
    functions: dict.Dict(String, FunctionMetaData),
    storage_vars: dict.Dict(String, ContractStorageVarMetaData),
  )
}

pub type ContractKind {
  Contract
  Interface
  Library
  Abstract
}

pub fn contract_kind_from_string(kind) {
  case kind |> string.lowercase {
    "contract" -> Contract
    "interface" -> Interface
    "library" -> Library
    "abstract" -> Abstract
    "abstract contract" -> Abstract
    "abstractcontract" -> Abstract
    _ -> panic as "Invalid contract kind given"
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

pub type FunctionKind {
  Function
  Constructor
  Fallback
  Receive
}

pub fn function_kind_from_string(kind) {
  case kind {
    "function" -> Function
    "constructor" -> Constructor
    "fallback" -> Fallback
    "receive" -> Receive
    _ -> panic as { "Invalid function kind given " <> kind }
  }
}

pub type ContractStorageVarMetaData {
  ContractStorageVarMetaData(name: String, kind: String, value: String)
}
