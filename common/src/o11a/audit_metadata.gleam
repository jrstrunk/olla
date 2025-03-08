import gleam/dynamic/decode
import gleam/json

pub type AuditMetaData {
  AuditMetaData(
    audit_name: String,
    audit_formatted_name: String,
    in_scope_files: List(String),
  )
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
  ))
}

pub fn encode_audit_metadata(audit_metadata: AuditMetaData) {
  json.object([
    #("audit_name", json.string(audit_metadata.audit_name)),
    #("audit_formatted_name", json.string(audit_metadata.audit_formatted_name)),
    #("in_scope_files", json.array(audit_metadata.in_scope_files, json.string)),
  ])
}
