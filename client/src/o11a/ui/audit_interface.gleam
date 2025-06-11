import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/computed_note
import o11a/preprocessor
import o11a/ui/discussion

pub const view_id = "interface"

pub type InterfaceData {
  InterfaceData(
    file_contracts: List(FileContract),
    contract_variables: List(preprocessor.Declaration),
    contract_functions: List(preprocessor.Declaration),
  )
}

pub const empty_interface_data = InterfaceData(
  file_contracts: [],
  contract_variables: [],
  contract_functions: [],
)

pub type FileContract {
  FileContract(file_name: String, contracts: List(preprocessor.Declaration))
}

pub type ContractDeclaration {
  ContractDeclaration(contract: String, dec: preprocessor.Declaration)
}

pub fn view(
  interface_data: InterfaceData,
  audit_name,
  declarations,
  discussion,
  discussion_context,
) {
  let active_discussion: option.Option(discussion.DiscussionReference) =
    discussion.get_active_discussion_reference(view_id, discussion_context)

  let #(_line_number_offset, elements) =
    list.map_fold(
      interface_data.file_contracts,
      0,
      fn(line_number_offset, contract_file) {
        let #(line_number_offset, contracts) =
          list.map_fold(
            contract_file.contracts,
            line_number_offset,
            fn(line_number_offset, contract) {
              let #(line_number_offset, state_elements) =
                contract_members_view(
                  contract.name,
                  interface_data.contract_variables,
                  declarations,
                  discussion,
                  active_discussion,
                  discussion_context,
                  line_number_offset:,
                )

              let #(line_number_offset, function_elements) =
                contract_members_view(
                  contract.name,
                  interface_data.contract_functions,
                  declarations,
                  discussion,
                  active_discussion,
                  discussion_context,
                  line_number_offset:,
                )

              let elements =
                html.div([attribute.class("ml-[1rem]")], [
                  html.p([], [html.text(contract.name)]),
                  element.fragment([state_elements, function_elements]),
                ])

              #(line_number_offset, elements)
            },
          )

        let elements =
          html.div([attribute.class("mt-[1rem]")], [
            html.p([], [html.text(contract_file.file_name)]),
            // List of contracts in file
            ..contracts
          ])

        #(line_number_offset, elements)
      },
    )

  html.div([attribute.id(view_id), attribute.class("p-[1rem]")], [
    // Page header
    html.h1([], [
      html.text(audit_name |> string.capitalise <> " Audit Interface"),
    ]),
    // List of files in scope
    ..elements
  ])
}

fn contract_members_view(
  contract: String,
  declarations_of_type: List(preprocessor.Declaration),
  declarations: dict.Dict(String, preprocessor.Declaration),
  discussion discussion: dict.Dict(String, List(computed_note.ComputedNote)),
  active_discussion active_discussion,
  discussion_context discussion_context,
  line_number_offset line_number_offset,
) {
  let items =
    list.filter(declarations_of_type, fn(declaration) {
      option.unwrap(declaration.scope.contract, "") == contract
    })

  let #(lines, elements) =
    list.map_fold(
      items,
      line_number_offset,
      fn(line_number_offset, declaration) {
        let el =
          html.p(
            [attribute.class("ml-[1rem] mb-[1rem] leading-[1.1875rem]")],
            discussion.topic_signature_view(
              view_id:,
              signature: declaration.signature,
              declarations:,
              discussion:,
              suppress_declaration: False,
              line_number_offset:,
              active_discussion:,
              discussion_context:,
            ),
          )
        #(line_number_offset + list.length(declaration.signature), el)
      },
    )

  #(line_number_offset + lines, element.fragment(elements))
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

  let contract_variables =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec.kind {
        preprocessor.VariableDeclaration -> Ok(declaration.dec)
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

  InterfaceData(file_contracts:, contract_variables:, contract_functions:)
}
