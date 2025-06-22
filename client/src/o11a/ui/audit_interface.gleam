import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/note
import o11a/preprocessor
import o11a/topic
import o11a/ui/discussion

pub const view_id = "interface"

pub type InterfaceData {
  InterfaceData(
    file_contracts: List(FileContract),
    contract_variables: List(topic.Topic),
    contract_functions: List(topic.Topic),
  )
}

pub const empty_interface_data = InterfaceData(
  file_contracts: [],
  contract_variables: [],
  contract_functions: [],
)

pub type FileContract {
  FileContract(file_name: String, contracts: List(topic.Topic))
}

pub type ContractDeclaration {
  ContractDeclaration(contract: String, dec: topic.Topic)
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
                  topic.topic_name(contract),
                  interface_data.contract_variables,
                  declarations,
                  discussion,
                  active_discussion,
                  discussion_context,
                  line_number_offset:,
                )

              let #(line_number_offset, function_elements) =
                contract_members_view(
                  topic.topic_name(contract),
                  interface_data.contract_functions,
                  declarations,
                  discussion,
                  active_discussion,
                  discussion_context,
                  line_number_offset:,
                )

              let elements =
                html.div([attribute.class("ml-[1rem]")], [
                  html.p([], [html.text(topic.topic_name(contract))]),
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
  declarations_of_type: List(topic.Topic),
  declarations: dict.Dict(String, topic.Topic),
  discussion discussion: dict.Dict(String, List(note.NoteStub)),
  active_discussion active_discussion,
  discussion_context discussion_context,
  line_number_offset line_number_offset,
) {
  let items =
    list.filter(declarations_of_type, fn(topic) {
      case topic {
        topic.SourceDeclaration(
          scope: preprocessor.Scope(
            contract: option.Some(topic_contract),
            ..,
          ),
          ..,
        ) -> topic_contract == contract
        _ -> False
      }
    })

  let #(lines, elements) =
    list.map_fold(
      items,
      line_number_offset,
      fn(line_number_offset, declaration) {
        let #(lines, signature) = case declaration {
          topic.SourceDeclaration(signature:, ..) -> #(
            list.length(signature),
            discussion.topic_signature_view(
              view_id:,
              signature:,
              declarations:,
              discussion:,
              suppress_declaration: False,
              line_number_offset:,
              active_discussion:,
              discussion_context:,
            ),
          )
          _ -> #(0, [html.text("")])
        }

        #(
          line_number_offset + lines,
          html.p(
            [attribute.class("ml-[1rem] mb-[1rem] leading-[1.1875rem]")],
            signature,
          ),
        )
      },
    )

  #(line_number_offset + lines, element.fragment(elements))
}

pub fn gather_interface_data(
  declaration_list: List(topic.Topic),
  in_scope_files,
) {
  let declarations_in_scope =
    declaration_list
    |> list.filter(fn(topic) {
      case topic {
        topic.SourceDeclaration(scope: preprocessor.Scope(file:, ..), ..) ->
          list.contains(in_scope_files, file)
        _ -> False
      }
    })

  let contract_member_declarations_in_scope =
    declarations_in_scope
    |> list.filter_map(fn(topic) {
      // Only show declarations that are in scope to the audit
      case topic {
        // Only show declarations that are defined in a contract (not line or 
        // unknown declarations), but not in a contract's functions
        topic.SourceDeclaration(
          scope: preprocessor.Scope(
            contract: option.Some(contract),
            member: option.None,
            ..,
          ),
          ..,
        ) -> Ok(ContractDeclaration(contract, topic))
        _ -> Error(Nil)
      }
    })
    |> list.sort(by: fn(a, b) {
      case a.dec, b.dec {
        topic.SourceDeclaration(
          source_map: a_source_map,
          ..,
        ),
          topic.SourceDeclaration(
            source_map: b_source_map,
            ..,
          )
        -> int.compare(a_source_map.start, b_source_map.start)

        _, _ -> order.Gt
      }
    })

  let file_contracts =
    declarations_in_scope
    |> list.filter(fn(declaration) {
      case declaration {
        topic.SourceDeclaration(kind: preprocessor.ContractDeclaration(..), ..) ->
          True
        _ -> False
      }
    })
    |> list.group(by: fn(topic) {
      case topic {
        topic.SourceDeclaration(scope: preprocessor.Scope(file:, ..), ..) ->
          file
        _ -> ""
      }
    })
    |> dict.map_values(fn(_k, value) {
      list.map(value, fn(declaration) { declaration })
      |> list.unique
    })
    |> dict.to_list
    |> list.map(fn(contracts) { FileContract(contracts.0, contracts.1) })

  let contract_variables =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec {
        topic.SourceDeclaration(kind: preprocessor.VariableDeclaration, ..) ->
          Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  let contract_functions =
    list.filter_map(contract_member_declarations_in_scope, fn(declaration) {
      case declaration.dec {
        topic.SourceDeclaration(kind: preprocessor.FunctionDeclaration(..), ..) ->
          Ok(declaration.dec)
        _ -> Error(Nil)
      }
    })

  InterfaceData(file_contracts:, contract_variables:, contract_functions:)
}
