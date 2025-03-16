import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/string

pub type AuditMetaData {
  AuditMetaData(
    audit_name: String,
    audit_formatted_name: String,
    in_scope_files: List(String),
    source_files_sol: dict.Dict(String, SourceFileMetaData),
  )
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
    _ -> panic as { "Invalid contract kind given " <> kind }
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

pub type ContractStorageVarMetaData {
  ContractStorageVarMetaData(name: String, kind: String, value: String)
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

  decode.success(AuditMetaData(
    audit_name:,
    audit_formatted_name:,
    in_scope_files:,
    source_files_sol: dict.new(),
  ))
}

pub fn encode_audit_metadata(audit_metadata: AuditMetaData) {
  json.object([
    #("audit_name", json.string(audit_metadata.audit_name)),
    #("audit_formatted_name", json.string(audit_metadata.audit_formatted_name)),
    #("in_scope_files", json.array(audit_metadata.in_scope_files, json.string)),
  ])
}
