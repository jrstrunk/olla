import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/string

pub type AuditMetaData {
  AuditMetaData(
    audit_name: String,
    audit_formatted_name: String,
    in_scope_files: List(String),
    declarations: List(Declaration),
  )
}

pub fn encode_audit_metadata(audit_metadata: AuditMetaData) {
  json.object([
    #("audit_name", json.string(audit_metadata.audit_name)),
    #("audit_formatted_name", json.string(audit_metadata.audit_formatted_name)),
    #("in_scope_files", json.array(audit_metadata.in_scope_files, json.string)),
    #(
      "declarations",
      json.array(audit_metadata.declarations, encode_declaration),
    ),
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
  use declarations <- decode.field(
    "declarations",
    decode.list(declaration_decoder()),
  )

  decode.success(AuditMetaData(
    audit_name:,
    audit_formatted_name:,
    in_scope_files:,
    declarations:,
  ))
}

pub type Declaration {
  Declaration(
    name: String,
    scoped_name: String,
    kind: DeclarationKind,
    topic_id: String,
  )
}

fn declaration_decoder() -> decode.Decoder(Declaration) {
  use name <- decode.field("n", decode.string)
  use scoped_name <- decode.field("s", decode.string)
  use kind <- decode.field("k", declaration_kind_decoder())
  use topic_id <- decode.field("i", decode.string)
  decode.success(Declaration(name:, scoped_name:, kind:, topic_id:))
}

fn encode_declaration(declaration: Declaration) -> json.Json {
  let Declaration(name:, scoped_name:, kind:, topic_id:) = declaration
  json.object([
    #("n", json.string(name)),
    #("s", json.string(scoped_name)),
    #("k", encode_declaration_kind(kind)),
    #("i", json.string(topic_id)),
  ])
}

pub type DeclarationKind {
  ContractDeclaration
  FunctionDeclaration
  VariableDeclaration
  DocumentationDeclaration
}

fn encode_declaration_kind(declaration_kind: DeclarationKind) -> json.Json {
  case declaration_kind {
    ContractDeclaration -> json.string("c")
    FunctionDeclaration -> json.string("f")
    VariableDeclaration -> json.string("v")
    DocumentationDeclaration -> json.string("d")
  }
}

fn declaration_kind_decoder() -> decode.Decoder(DeclarationKind) {
  use variant <- decode.then(decode.string)
  case variant {
    "c" -> decode.success(ContractDeclaration)
    "f" -> decode.success(FunctionDeclaration)
    "v" -> decode.success(VariableDeclaration)
    "d" -> decode.success(DocumentationDeclaration)
    _ -> decode.failure(DocumentationDeclaration, "DeclarationKind")
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
