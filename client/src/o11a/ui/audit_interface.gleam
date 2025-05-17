import filepath
import gleam/dict
import gleam/list
import gleam/option
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/declaration

pub type InterfaceData {
  InterfaceData(
    file_contracts: List(FileContract),
    contract_constants: List(declaration.Declaration),
    contract_variables: List(declaration.Declaration),
    contract_structs: List(declaration.Declaration),
    contract_enums: List(declaration.Declaration),
    contract_events: List(declaration.Declaration),
    contract_errors: List(declaration.Declaration),
    contract_functions: List(declaration.Declaration),
    contract_modifiers: List(declaration.Declaration),
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
  FileContract(file_name: String, contracts: List(declaration.Declaration))
}

pub type ContractDeclaration {
  ContractDeclaration(contract: String, dec: declaration.Declaration)
}

pub fn view(interface_data: InterfaceData) {
  html.div([attribute.class("p-[1rem]")], [
    // Page header
    html.h1([], [html.text("Interfaces")]),
    // List of files in scope
    ..list.map(interface_data.file_contracts, fn(contract_file) {
      html.div([attribute.class("mt-[1rem]")], [
        html.p([], [html.text(contract_file.file_name)]),
        // List of contracts in file
        ..list.map(contract_file.contracts, fn(contract) {
          html.div([attribute.class("ml-[1rem]")], [
            html.p([], [
              html.a([attribute.href("/" <> contract.topic_id)], [
                html.text(contract.name),
              ]),
            ]),
            // List of constants in contract
            contract_members_view(
              contract.name,
              "Constants",
              interface_data.contract_constants,
            ),
            // List of variables in contract
            contract_members_view(
              contract.name,
              "State Variables",
              interface_data.contract_variables,
            ),
            // List of structs in contract
            contract_members_view(
              contract.name,
              "Structs",
              interface_data.contract_structs,
            ),
            // List of enums in contract
            contract_members_view(
              contract.name,
              "Enums",
              interface_data.contract_enums,
            ),
            // List of events in contract
            contract_members_view(
              contract.name,
              "Events",
              interface_data.contract_events,
            ),
            // List of errors in contract
            contract_members_view(
              contract.name,
              "Errors",
              interface_data.contract_errors,
            ),
            // List of functions in contract
            contract_members_view(
              contract.name,
              "Functions",
              interface_data.contract_functions,
            ),
            // List of modifiers in contract
            contract_members_view(
              contract.name,
              "Modifiers",
              interface_data.contract_modifiers,
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
  declarations: List(declaration.Declaration),
) {
  let items =
    list.filter(declarations, fn(declaration) {
      option.unwrap(declaration.scope.contract, "") == contract
    })

  case items {
    [] -> element.fragment([])
    items ->
      html.div([attribute.class("ml-[1rem] mb-[1rem]")], [
        html.p([], [html.text(title)]),
        ..list.map(items, fn(declaration) {
          html.p([attribute.class("ml-[1rem]")], [
            html.a([attribute.href("/" <> declaration.topic_id)], [
              element.unsafe_raw_html(
                "signature",
                "span",
                [],
                declaration.signature,
              ),
            ]),
          ])
        })
      ])
  }
}

pub fn gather_interface_data(
  declarations: List(declaration.Declaration),
  in_scope_files,
) {
  let in_scope_file_names = in_scope_files |> list.map(filepath.base_name)

  let declarations_in_scope =
    declarations
    |> list.filter(fn(declaration) {
      list.contains(in_scope_file_names, declaration.scope.file)
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

  let file_contracts =
    declarations_in_scope
    |> list.filter(fn(declaration) {
      case declaration.kind {
        declaration.ContractDeclaration(..) -> True
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
        declaration.ConstantDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_variables =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        declaration.VariableDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_structs =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        declaration.StructDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_enums =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        declaration.EnumDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_events =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        declaration.EventDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_errors =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        declaration.ErrorDeclaration -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_functions =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        declaration.FunctionDeclaration(..) -> Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_modifiers =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        declaration.ModifierDeclaration -> Ok(declaration.dec)
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
