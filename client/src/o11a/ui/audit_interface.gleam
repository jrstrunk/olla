import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/preprocessor
import o11a/ui/node_renderer

pub type InterfaceData {
  InterfaceData(
    file_contracts: List(FileContract),
    contract_constants: List(preprocessor.Declaration),
    contract_variables: List(preprocessor.Declaration),
    contract_structs: List(preprocessor.Declaration),
    contract_enums: List(preprocessor.Declaration),
    contract_events: List(preprocessor.Declaration),
    contract_errors: List(preprocessor.Declaration),
    contract_functions: List(preprocessor.Declaration),
    contract_modifiers: List(preprocessor.Declaration),
  )
}

pub fn empty_interface_data() {
  InterfaceData(
    file_contracts: [],
    contract_constants: [],
    contract_variables: [],
    contract_structs: [],
    contract_enums: [],
    contract_events: [],
    contract_errors: [],
    contract_functions: [],
    contract_modifiers: [],
  )
}

pub type FileContract {
  FileContract(file_name: String, contracts: List(preprocessor.Declaration))
}

pub type ContractDeclaration {
  ContractDeclaration(contract: String, dec: preprocessor.Declaration)
}

pub fn view(interface_data: InterfaceData, audit_name, declarations) {
  html.div([attribute.class("p-[1rem]")], [
    // Page header
    html.h1([], [
      html.text(audit_name |> string.capitalise <> " Audit Interface"),
    ]),
    // List of files in scope
    ..list.map(interface_data.file_contracts, fn(contract_file) {
      html.div([attribute.class("mt-[1rem]")], [
        html.p([], [html.text(contract_file.file_name)]),
        // List of contracts in file
        ..list.map(contract_file.contracts, fn(contract) {
          html.div([attribute.class("ml-[1rem]")], [
            html.p([], [
              html.a(
                [attribute.href(preprocessor.declaration_to_link(contract))],
                [html.text(contract.name)],
              ),
            ]),
            // List of constants in contract
            contract_members_view(
              contract.name,
              "Constants",
              interface_data.contract_constants,
              declarations,
            ),
            // List of variables in contract
            contract_members_view(
              contract.name,
              "State Variables",
              interface_data.contract_variables,
              declarations,
            ),
            // List of structs in contract
            contract_members_view(
              contract.name,
              "Structs",
              interface_data.contract_structs,
              declarations,
            ),
            // List of enums in contract
            contract_members_view(
              contract.name,
              "Enums",
              interface_data.contract_enums,
              declarations,
            ),
            // List of events in contract
            contract_members_view(
              contract.name,
              "Events",
              interface_data.contract_events,
              declarations,
            ),
            // List of errors in contract
            contract_members_view(
              contract.name,
              "Errors",
              interface_data.contract_errors,
              declarations,
            ),
            // List of functions in contract
            contract_members_view(
              contract.name,
              "Functions",
              interface_data.contract_functions,
              declarations,
            ),
            // List of modifiers in contract
            contract_members_view(
              contract.name,
              "Modifiers",
              interface_data.contract_modifiers,
              declarations,
            ),
          ])
        })
      ])
    })
  ])
}

fn contract_members_view(
  contract: String,
  title,
  declarations_of_type: List(preprocessor.Declaration),
  declarations: dict.Dict(String, preprocessor.Declaration),
) {
  let items =
    list.filter(declarations_of_type, fn(declaration) {
      option.unwrap(declaration.scope.contract, "") == contract
    })

  case items {
    [] -> element.fragment([])
    items ->
      html.div([attribute.class("ml-[1rem] mb-[1.5rem]")], [
        html.p([], [html.text(title)]),
        ..list.map(items, fn(declaration) {
          html.p([attribute.class("ml-[1rem] mb-[1rem] leading-[1.1875rem]")], [
            html.a(
              [attribute.href(preprocessor.declaration_to_link(declaration))],
              node_renderer.render_topic_signature(
                declaration.signature,
                declarations,
              ),
            ),
          ])
        })
      ])
  }
}

pub fn gather_interface_data(
  declaration_list: List(preprocessor.Declaration),
  in_scope_files,
) {
  let declarations_in_scope =
    declaration_list
    |> list.filter(fn(declaration) {
      list.contains(in_scope_files, declaration.scope.file)
    })

  let contract_member_declarations_in_scope =
    declarations_in_scope
    |> list.filter_map(fn(declaration) {
      case
        // Only show declarations that are in scope to the audit
        declaration.scope.contract,
        declaration.scope.member
      {
        // Only show declarations that are defined in a contract (not line or 
        // unknown declarations), but not in a contract's functions
        option.Some(contract), option.None ->
          Ok(ContractDeclaration(contract, declaration))
        _, _ -> Error(Nil)
      }
    })
    |> list.sort(by: fn(a, b) {
      int.compare(a.dec.source_map.start, b.dec.source_map.start)
    })

  let file_contracts =
    declarations_in_scope
    |> list.filter(fn(declaration) {
      case declaration.kind {
        preprocessor.ContractDeclaration(..) -> True
        _ -> False
      }
    })
    |> list.group(by: fn(declaration) { declaration.scope.file })
    |> dict.map_values(fn(_k, value) {
      list.map(value, fn(declaration) { declaration })
      |> list.unique
    })
    |> dict.to_list
    |> list.map(fn(contracts) { FileContract(contracts.0, contracts.1) })

  let contract_constants =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        preprocessor.ConstantDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_variables =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        preprocessor.VariableDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_structs =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        preprocessor.StructDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_enums =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        preprocessor.EnumDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_events =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        preprocessor.EventDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_errors =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        preprocessor.ErrorDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_functions =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        preprocessor.FunctionDeclaration(..) -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_modifiers =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        preprocessor.ModifierDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  InterfaceData(
    file_contracts:,
    contract_constants:,
    contract_variables:,
    contract_structs:,
    contract_enums:,
    contract_events:,
    contract_errors:,
    contract_functions:,
    contract_modifiers:,
  )
}
