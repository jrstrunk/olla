import filepath
import given
import gleam/bit_array
import gleam/bool
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/regexp
import gleam/result
import gleam/string
import lib/enumerate
import lib/snagx
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/audit_metadata
import o11a/config
import simplifile
import snag

pub type PreProcessedLine(msg) {
  PreProcessedLine(
    significance: PreProcessedLineSignificance,
    line_number: Int,
    line_number_text: String,
    line_tag: String,
    line_id: String,
    leading_spaces: Int,
    nodes: List(PreProcessedNode(msg)),
  )
}

pub type PreProcessedLineSignificance {
  SingleDeclarationLine(topic_id: String, title: String)
  NonEmptyLine
  EmptyLine
}

pub fn preprocess_source(
  source source: String,
  nodes nodes: List(Node),
  declarations declarations: dict.Dict(Int, NodeDeclaration),
  page_path page_path: String,
  audit_name audit_name: String,
) {
  use line, index <- list.index_map(consume_source(
    source:,
    nodes:,
    declarations:,
    audit_name:,
  ))

  let line_number = index + 1
  let line_number_text = int.to_string(line_number)
  let line_tag = "L" <> line_number_text
  let line_id = page_path <> "#" <> line_tag
  let leading_spaces = case line {
    [PreProcessedGapNode(leading_spaces:, ..), ..] -> leading_spaces
    _ -> 0
  }

  let declaration_count =
    list.count(line, fn(decl) {
      case decl {
        PreProcessedDeclaration(..) -> True
        _ -> False
      }
    })

  let reference_count =
    list.count(line, fn(ref) {
      case ref {
        PreProcessedReference(..) -> True
        _ -> False
      }
    })

  let significance = case declaration_count, reference_count {
    1, _ -> {
      let assert Ok(PreProcessedDeclaration(node_declaration:, ..)) =
        list.find(line, fn(decl) {
          case decl {
            PreProcessedDeclaration(..) -> True
            _ -> False
          }
        })

      SingleDeclarationLine(
        topic_id: node_declaration.topic_id,
        title: node_declaration.title,
      )
    }
    0, 0 -> EmptyLine
    _, _ -> NonEmptyLine
  }

  PreProcessedLine(
    significance:,
    nodes: line,
    line_id:,
    line_number:,
    line_number_text:,
    line_tag:,
    leading_spaces:,
  )
}

pub type PreProcessedNode(msg) {
  PreProcessedDeclaration(
    build_element: fn(element.Element(msg)) -> element.Element(msg),
    node_declaration: NodeDeclaration,
  )
  PreProcessedReference(
    build_element: fn(element.Element(msg)) -> element.Element(msg),
    referenced_node_declaration: NodeDeclaration,
  )
  PreProcessedNode(element: element.Element(msg))
  PreProcessedGapNode(element: element.Element(msg), leading_spaces: Int)
}

pub fn consume_source(
  source source: String,
  nodes nodes: List(Node),
  declarations declarations: dict.Dict(Int, NodeDeclaration),
  audit_name audit_name: String,
) {
  let #(_, current_line, processed, rest) =
    list.fold(nodes, #(0, [], [], source), fn(source_data, node) {
      let #(total_consumed_count, current_line, processed, rest) = source_data

      let style_node_tokens = case node {
        ImportDirectiveNode(absolute_path:, ..) -> style_import_node(
          absolute_path,
          _,
          // Add source units to the declarations dict and store import data
          // there too maybe? idk we just need the full path somethow
          dict.new(),
          audit_name,
        )

        ContractDefinitionNode(id:, ..)
        | VariableDeclarationNode(id:, ..)
        | FunctionDefinitionNode(id:, ..)
        | ModifierDefinitionNode(id:, ..)
        | EventDefinitionNode(id:, ..)
        | ErrorDefinitionNode(id:, ..)
        | EnumDefinition(id:, ..)
        | StructDefinition(id:, ..)
        | EnumValue(id:, ..) -> style_declaration_node(
          declarations:,
          id:,
          tokens: _,
        )

        BaseContract(reference_id:, ..) | Modifier(reference_id:, ..) -> style_reference_node(
          declarations:,
          reference_id:,
          tokens: _,
        )

        FunctionCall(reference_id:, kind:, ..) ->
          case reference_id < 0, kind {
            _, TypeConversion -> style_gap_token(_, class: "type")
            True, _ -> style_gap_token(_, class: "global-variable")
            False, _ -> style_reference_node(
              declarations:,
              reference_id:,
              tokens: _,
            )
          }

        Identifier(reference_id:, ..) | IdentifierPath(reference_id:, ..) ->
          case reference_id < 0 {
            True -> style_gap_token(_, class: "global-variable")
            False -> style_reference_node(
              declarations:,
              reference_id:,
              tokens: _,
            )
          }

        MemberAccess(reference_id:, is_global_access:, ..) ->
          case reference_id, is_global_access {
            option.Some(reference_id), _ -> style_reference_node(
              declarations:,
              reference_id:,
              tokens: _,
            )
            option.None, True -> style_gap_token(_, class: "global-variable")
            option.None, False -> style_gap_token(_, class: "text")
          }

        ElementaryTypeNameExpression(..) -> style_gap_token(_, class: "type")

        Literal(kind:, ..) ->
          case kind {
            StringLiteral -> style_gap_token(_, class: "string")
            NumberLiteral | BoolLiteral | HexStringLiteral -> style_gap_token(
              _,
              class: "number",
            )
          }

        _ -> style_gap_tokens
      }

      consume_part(
        node:,
        total_consumed_count:,
        current_line:,
        rest:,
        processed:,
        style_node_tokens:,
      )
    })

  // Flush the rest of the file into the processed list
  case current_line == [], rest == "" {
    _, False -> {
      let #(consumed, _, rest, _) = consume_line(rest, 10_000)
      let processed = [
        [style_gap_tokens(consumed), ..current_line] |> list.reverse,
        ..processed
      ]

      string.split(rest, on: "\n")
      |> list.fold(processed, fn(processed, line) {
        [[style_gap_tokens(line)], ..processed]
      })
    }
    False, True -> [current_line, ..processed]
    True, True -> processed
  }
  |> list.reverse
}

pub fn consume_part(
  node node: Node,
  total_consumed_count total_consumed_count,
  current_line current_line: List(PreProcessedNode(msg)),
  processed processed: List(List(PreProcessedNode(msg))),
  rest rest,
  style_node_tokens style_node_tokens,
) {
  use <- given.that(node.source_map == SourceMap(-1, -1), return: fn() {
    #(total_consumed_count, current_line, processed, rest)
  })

  let gap_to_consume =
    int.min(node.source_map.start - total_consumed_count, string.length(rest))

  let node_to_consume =
    int.min(
      get_source_map_end(node.source_map) - total_consumed_count,
      string.length(rest),
    )

  case gap_to_consume > 0, node_to_consume > 0 {
    True, _ -> {
      let #(gap_tokens, consumed_count, rest, reached_newline) =
        consume_line(rest, for: gap_to_consume)

      let total_consumed_count = total_consumed_count + consumed_count
      let current_line = [style_gap_tokens(gap_tokens), ..current_line]

      case reached_newline {
        // If we reached the newline, it means we may still have some gap to go
        True ->
          consume_part(
            node:,
            total_consumed_count:,
            current_line: [],
            processed: [current_line |> list.reverse, ..processed],
            rest:,
            style_node_tokens:,
          )
        // If we didn't reach the newline, we are at the beginning of the
        // node code
        False ->
          consume_part(
            node:,
            total_consumed_count:,
            current_line:,
            processed:,
            rest:,
            style_node_tokens:,
          )
      }
    }
    False, True -> {
      let node_end = get_source_map_end(node.source_map)
      let #(node_tokens, consumed_count, rest, reached_newline) =
        consume_line(rest, for: node_end - total_consumed_count)

      let total_consumed_count = total_consumed_count + consumed_count
      let current_line = [style_node_tokens(node_tokens), ..current_line]

      case reached_newline {
        // If we reached the newline, but not the end of the node, it means we 
        // may still have some of the current node to go
        True ->
          consume_part(
            node:,
            total_consumed_count:,
            current_line: [],
            processed: [current_line |> list.reverse, ..processed],
            rest:,
            style_node_tokens:,
          )
        // We reached the end of the node, so we are done in the middle of the 
        // line
        False -> #(total_consumed_count, current_line, processed, rest)
      }
    }
    // We ended right at a line boundry last time
    False, False -> {
      #(total_consumed_count, current_line, processed, rest)
    }
  }
}

fn style_declaration_node(
  declarations declarations,
  id id,
  tokens tokens: String,
) {
  let node_declaration =
    dict.get(declarations, id)
    |> result.unwrap(NodeDeclaration("", "", UnknownDeclaration, []))

  let build_element = fn(child_element) {
    html.span([attribute.class("relative")], [
      html.span(
        [
          attribute.id(node_declaration.topic_id),
          attribute.class(node_declaration_kind_to_string(node_declaration.kind)),
          attribute.class(
            "declaration-preview discussion-entry n" <> int.to_string(id),
          ),
          attribute.attribute("tabindex", "0"),
        ],
        [html.text(tokens)],
      ),
      child_element,
    ])
  }

  PreProcessedDeclaration(node_declaration:, build_element:)
}

fn style_reference_node(
  declarations declarations,
  reference_id reference_id,
  tokens tokens: String,
) {
  let referenced_node_declaration =
    dict.get(declarations, reference_id)
    |> result.unwrap(NodeDeclaration("", "", UnknownDeclaration, []))

  let build_element = fn(child_element) {
    html.span([attribute.class("relative")], [
      html.span(
        [
          attribute.class(node_declaration_kind_to_string(
            referenced_node_declaration.kind,
          )),
          attribute.class(
            "reference-preview discussion-entry n"
            <> int.to_string(reference_id),
          ),
          attribute.attribute("tabindex", "0"),
        ],
        [html.text(tokens)],
      ),
      child_element,
    ])
  }

  PreProcessedReference(referenced_node_declaration:, build_element:)
}

fn style_import_node(
  abs_path: String,
  tokens: String,
  _import_declarations: dict.Dict(String, Int),
  audit_name,
) {
  let #(import_statement_base, import_path) =
    tokens
    |> string.split_once("\"")
    |> result.unwrap(#(tokens, ""))

  // Remove the "import " that is always present
  let import_statement_base = import_statement_base |> string_drop_start(7)
  // Remove the trailing "";"
  let import_path = import_path |> string_drop_end(2)

  let assert Ok(capitalized_word_regex) = regexp.from_string("\\b[A-Z]\\w+\\b")

  let styled_line =
    html.span([attribute.class("keyword")], [html.text("import")])
    |> element.to_string
    <> " "
    <> regexp.match_map(
      capitalized_word_regex,
      import_statement_base,
      fn(match) {
        html.span([attribute.class("contract")], [html.text(match.content)])
        |> element.to_string
      },
    )
    |> string.replace(
      "from",
      html.span([attribute.class("keyword")], [html.text("from")])
        |> element.to_string,
    )
    <> html.span([attribute.class("string")], [
      html.text("\""),
      html.a(
        [
          attribute.class("import-path"),
          attribute.href("/" <> filepath.join(audit_name, abs_path)),
        ],
        [html.text(import_path)],
      ),
      html.text("\""),
    ])
    |> element.to_string
    <> ";"

  html.span([attribute.attribute("dangerous-unescaped-html", styled_line)], [])
  |> PreProcessedNode
}

fn style_gap_token(gap_token, class class) {
  html.span([attribute.class(class)], [html.text(gap_token)])
  |> PreProcessedNode
}

/// Gap tokens are everything left out of the AST: brackets, comments, etc.
fn style_gap_tokens(gap_tokens) {
  let styled_gap_tokens = {
    use <- given.that(
      gap_tokens |> string.trim_start |> string.starts_with("//"),
      return: fn() { style_comment_line(gap_tokens) },
    )
    use <- given.that(gap_tokens |> string.starts_with("pragma"), return: fn() {
      style_pragma_line(gap_tokens)
    })
    use <- given.that(
      case gap_tokens |> string.trim {
        "*" | "-" | "+" | "**" | "==" | "=" | "!=" | "<" | ">" | "<=" | ">=" ->
          True
        _ -> False
      },
      return: fn() { style_operator_token(gap_tokens) },
    )
    style_code_tokens(gap_tokens)
  }

  let leading_spaces = enumerate.leading_spaces(gap_tokens)

  html.span(
    [attribute.attribute("dangerous-unescaped-html", styled_gap_tokens)],
    [],
  )
  |> PreProcessedGapNode(leading_spaces:)
}

pub fn style_comment_line(line_text) {
  html.span([attribute.class("comment")], [html.text(line_text)])
  |> element.to_string
}

pub fn style_pragma_line(line_text) {
  let solidity_version =
    line_text
    // Remove "pragma solidity "
    |> string_drop_start(16)
    // Remove ";"
    |> string_drop_end(1)

  html.span([attribute.class("keyword")], [html.text("pragma solidity")])
  |> element.to_string
  <> " "
  <> html.span([attribute.class("number")], [html.text(solidity_version)])
  |> element.to_string
  <> ";"
}

pub fn style_operator_token(tokens) {
  html.span([attribute.class("operator")], [html.text(tokens)])
  |> element.to_string
}

/// Consumes a line of text until a newline character, at which point
/// it destroys the newline, and returns the consumed line, the number
/// of characters consumed, and the remaining source
pub fn consume_line(line, for length) {
  let #(consumed, consumed_count, rest, reached_newline) =
    do_consume_line(line |> bit_array.from_string, length, <<>>, 0)

  let assert Ok(consumed) = bit_array.to_string(consumed)
  let assert Ok(rest) = bit_array.to_string(rest)

  #(consumed, consumed_count, rest, reached_newline)
}

fn do_consume_line(
  line: BitArray,
  length: Int,
  consumed: BitArray,
  consumed_count: Int,
) {
  case consumed_count >= length {
    True -> #(consumed, consumed_count, line, False)
    False ->
      case line {
        <<"\n":utf8, rest:bits>> -> #(consumed, consumed_count + 1, rest, True)
        <<ch:8, rest:bits>> ->
          do_consume_line(
            rest,
            length,
            bit_array.append(consumed, <<ch>>),
            consumed_count + 1,
          )
        _ -> #(consumed, consumed_count, line, False)
      }
  }
}

pub fn process_asts(asts: List(#(String, AST)), audit_name: String) {
  list.map(asts, fn(ast_data) {
    let #(source_file, ast) = ast_data

    let imports =
      ast.nodes
      |> list.filter_map(fn(node) {
        case node {
          ImportDirectiveNode(file:, absolute_path:, ..) -> {
            Ok(#(file, filepath.join(audit_name, absolute_path)))
          }
          _ -> Error(Nil)
        }
      })
      |> dict.from_list

    let contracts =
      ast.nodes
      |> list.filter_map(fn(node) {
        case node {
          ContractDefinitionNode(name:, contract_kind:, ..) -> {
            Ok(#(
              name,
              audit_metadata.ContractMetaData(
                name:,
                kind: contract_kind,
                functions: dict.new(),
                storage_vars: dict.new(),
              ),
            ))
          }
          _ -> Error(Nil)
        }
      })
      |> dict.from_list

    #(source_file, audit_metadata.SourceFileMetaData(imports:, contracts:))
  })
  |> dict.from_list
}

/// Flattens all nodes into a list of leaf nodes that we are interested in
/// for styling and other targeted purposes. The nodes are sorted by their
/// source map start position.
pub fn linearize_nodes(ast: AST) {
  list.fold(ast.nodes, [], do_linearize_nodes)
  |> list.sort(by: fn(a, b) {
    int.compare(a.source_map.start, b.source_map.start)
  })
}

fn do_linearize_nodes(linearized_nodes: List(Node), node: Node) {
  case node {
    ElementaryTypeNameExpression(..)
    | Literal(..)
    | BaseContract(..)
    | ImportDirectiveNode(..) -> [node, ..linearized_nodes]

    Node(nodes:, ..) -> do_linearize_nodes_multi(linearized_nodes, nodes)
    NamedNode(nodes:, ..) -> do_linearize_nodes_multi(linearized_nodes, nodes)
    Assignment(left_hand_side:, right_hand_side:, ..) ->
      do_linearize_nodes(linearized_nodes, left_hand_side)
      |> do_linearize_nodes(right_hand_side)
    BinaryOperation(left_expression:, right_expression:, ..) ->
      do_linearize_nodes(linearized_nodes, left_expression)
      |> do_linearize_nodes(right_expression)
    BlockNode(nodes:, statements:, expression:, ..) ->
      case expression {
        option.Some(node) -> do_linearize_nodes(linearized_nodes, node)
        option.None -> linearized_nodes
      }
      |> do_linearize_nodes_multi(nodes)
      |> do_linearize_nodes_multi(statements)
    ContractDefinitionNode(base_contracts:, nodes:, ..) ->
      [node, ..linearized_nodes]
      |> do_linearize_nodes_multi(nodes)
      |> do_linearize_nodes_multi(base_contracts)
    EmitStatementNode(event_call:, ..) ->
      do_linearize_nodes(linearized_nodes, event_call)

    ErrorDefinitionNode(parameters:, nodes:, ..) ->
      [node, ..linearized_nodes]
      |> do_linearize_nodes_multi(nodes)
      |> do_linearize_nodes(parameters)
    EventDefinitionNode(parameters:, nodes:, ..) ->
      [node, ..linearized_nodes]
      |> do_linearize_nodes_multi(nodes)
      |> do_linearize_nodes(parameters)
    Expression(expression:, ..) ->
      case expression {
        option.Some(node) -> do_linearize_nodes(linearized_nodes, node)
        option.None -> linearized_nodes
      }
    FunctionCall(arguments:, expression:, ..) ->
      [node, ..linearized_nodes]
      |> fn(linearized_nodes) {
        case expression {
          option.Some(node) -> do_linearize_nodes(linearized_nodes, node)
          option.None -> linearized_nodes
        }
      }
      |> do_linearize_nodes_multi(arguments)
    FunctionDefinitionNode(
      parameters:,
      modifiers:,
      return_parameters:,
      nodes:,
      body:,
      ..,
    ) ->
      [node, ..linearized_nodes]
      |> fn(linearized_nodes) {
        case body {
          option.Some(body) -> do_linearize_nodes(linearized_nodes, body)
          option.None -> linearized_nodes
        }
      }
      |> do_linearize_nodes_multi(nodes)
      |> do_linearize_nodes(parameters)
      |> do_linearize_nodes(return_parameters)
      |> do_linearize_nodes_multi(modifiers)
    ModifierDefinitionNode(parameters:, nodes:, body:, ..) -> {
      [node, ..linearized_nodes]
      |> fn(linearized_nodes) {
        case body {
          option.Some(body) -> do_linearize_nodes(linearized_nodes, body)
          option.None -> linearized_nodes
        }
      }
      |> do_linearize_nodes_multi(nodes)
      |> do_linearize_nodes(parameters)
    }
    Identifier(expression:, ..) | MemberAccess(expression:, ..) ->
      [node, ..linearized_nodes]
      |> fn(linearized_nodes) {
        case expression {
          option.Some(exprssion) ->
            do_linearize_nodes(linearized_nodes, exprssion)
          option.None -> linearized_nodes
        }
      }
    IdentifierPath(..) -> [node, ..linearized_nodes]
    IfStatementNode(condition:, true_body:, false_body:, ..) ->
      case false_body {
        option.Some(false_body) ->
          do_linearize_nodes(linearized_nodes, false_body)
        option.None -> linearized_nodes
      }
      |> do_linearize_nodes(true_body)
      |> do_linearize_nodes(condition)
    ForStatementNode(
      initialization_expression:,
      condition:,
      loop_expression:,
      body:,
      ..,
    ) ->
      case initialization_expression {
        option.Some(init) -> do_linearize_nodes(linearized_nodes, init)
        option.None -> linearized_nodes
      }
      |> fn(linearized_nodes) {
        case condition {
          option.Some(condition) ->
            do_linearize_nodes(linearized_nodes, condition)
          option.None -> linearized_nodes
        }
      }
      |> fn(linearized_nodes) {
        case loop_expression {
          option.Some(loop) -> do_linearize_nodes(linearized_nodes, loop)
          option.None -> linearized_nodes
        }
      }
      |> do_linearize_nodes(body)
    IndexAccess(base:, index:, ..) ->
      case index {
        option.Some(index) -> do_linearize_nodes(linearized_nodes, index)
        option.None -> linearized_nodes
      }
      |> do_linearize_nodes(base)
    Modifier(arguments:, ..) ->
      [node, ..linearized_nodes]
      |> fn(linearized_nodes) {
        case arguments {
          option.Some(arguments) ->
            do_linearize_nodes_multi(linearized_nodes, arguments)
          option.None -> linearized_nodes
        }
      }
    ExpressionStatementNode(expression:, ..) ->
      case expression {
        option.Some(expression) ->
          do_linearize_nodes(linearized_nodes, expression)
        option.None -> linearized_nodes
      }
    ParameterListNode(parameters:, ..) ->
      do_linearize_nodes_multi(linearized_nodes, parameters)
    RevertStatementNode(expression:, ..) ->
      case expression {
        option.Some(expression) ->
          do_linearize_nodes(linearized_nodes, expression)
        option.None -> linearized_nodes
      }
    StructuredDocumentationNode(..) -> linearized_nodes
    UnaryOperation(expression:, ..) ->
      do_linearize_nodes(linearized_nodes, expression)
    VariableDeclarationNode(..) -> [node, ..linearized_nodes]
    VariableDeclarationStatementNode(declarations:, initial_value:, ..) ->
      case initial_value {
        option.Some(initial_value) ->
          do_linearize_nodes(linearized_nodes, initial_value)
        option.None -> linearized_nodes
      }
      |> list.fold(declarations, _, fn(linearized_nodes, declaration) {
        case declaration {
          Some(declaration) -> do_linearize_nodes(linearized_nodes, declaration)
          option.None -> linearized_nodes
        }
      })
    TupleExpression(nodes:, ..) ->
      do_linearize_nodes_multi(linearized_nodes, nodes)
    Conditional(condition:, true_expression:, false_expression:, ..) ->
      do_linearize_nodes(linearized_nodes, condition)
      |> do_linearize_nodes(true_expression)
      |> do_linearize_nodes(false_expression)
    EnumDefinition(members:, nodes:, ..) ->
      [node, ..linearized_nodes]
      |> do_linearize_nodes_multi(nodes)
      |> do_linearize_nodes_multi(members)
    EnumValue(..) -> [node, ..linearized_nodes]
    StructDefinition(members:, nodes:, ..) ->
      [node, ..linearized_nodes]
      |> do_linearize_nodes_multi(nodes)
      |> do_linearize_nodes_multi(members)
    UserDefinedTypeName(path_node:, ..) ->
      do_linearize_nodes(linearized_nodes, path_node)
  }
}

fn do_linearize_nodes_multi(linearized_nodes: List(Node), nodes: List(Node)) {
  list.fold(nodes, linearized_nodes, do_linearize_nodes)
}

pub type NodeDeclaration {
  NodeDeclaration(
    title: String,
    topic_id: String,
    kind: NodeDeclarationKind,
    references: List(NodeReference),
  )
}

pub type NodeDeclarationKind {
  ContractDeclaration
  ConstructorDeclaration
  FunctionDeclaration
  FallbackDeclaration
  ReceiveDeclaration
  ModifierDeclaration
  VariableDeclaration
  ConstantDeclaration
  EnumDeclaration
  EnumValueDeclaration
  StructDeclaration
  ErrorDeclaration
  EventDeclaration
  UnknownDeclaration
}

fn node_declaration_kind_to_string(kind) {
  case kind {
    ContractDeclaration -> "contract"
    ConstructorDeclaration -> "constructor"
    FunctionDeclaration -> "function"
    FallbackDeclaration -> "fallback"
    ReceiveDeclaration -> "receive"
    ModifierDeclaration -> "modifier"
    VariableDeclaration -> "variable"
    ConstantDeclaration -> "constant"
    EnumDeclaration -> "enum"
    EnumValueDeclaration -> "enum-value"
    StructDeclaration -> "struct"
    ErrorDeclaration -> "error"
    EventDeclaration -> "event"
    UnknownDeclaration -> "unknown"
  }
}

pub type NodeReference {
  NodeReference(title: String, topic_id: String)
}

pub fn enumerate_declarations(declarations, in ast: AST) {
  list.fold(ast.nodes, declarations, fn(declarations, node) {
    do_enumerate_node_declarations(declarations, node, ast.absolute_path)
  })
}

fn do_enumerate_node_declarations(declarations, node: Node, parent: String) {
  case node {
    Node(id:, nodes:, ..) -> {
      let title = "n" <> int.to_string(id)
      dict.insert(
        declarations,
        id,
        NodeDeclaration(
          title:,
          topic_id: parent <> ":" <> title,
          kind: UnknownDeclaration,
          references: [],
        ),
      )
      |> list.fold(nodes, _, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, parent)
      })
    }
    NamedNode(id:, nodes:, ..) -> {
      let title = "n" <> int.to_string(id)
      dict.insert(
        declarations,
        id,
        NodeDeclaration(
          title:,
          topic_id: parent <> ":" <> title,
          kind: UnknownDeclaration,
          references: [],
        ),
      )
      |> list.fold(nodes, _, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, parent)
      })
    }
    ImportDirectiveNode(..) | StructuredDocumentationNode(..) -> declarations
    ContractDefinitionNode(id:, name:, nodes:, contract_kind:, ..) -> {
      let title =
        audit_metadata.contract_kind_to_string(contract_kind) <> " " <> name
      let contract_id = parent <> "#" <> name

      dict.insert(
        declarations,
        id,
        NodeDeclaration(
          title:,
          topic_id: contract_id,
          kind: ContractDeclaration,
          references: [],
        ),
      )
      |> list.fold(nodes, _, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, contract_id)
      })
    }
    FunctionDefinitionNode(
      id:,
      name:,
      nodes:,
      function_kind:,
      parameters:,
      return_parameters:,
      body:,
      ..,
    ) -> {
      let title = case function_kind {
        audit_metadata.Function -> "function " <> name
        audit_metadata.Constructor -> "constructor"
        audit_metadata.Fallback -> "fallback function"
        audit_metadata.Receive -> "receive function"
      }
      let function_id =
        parent
        <> ":"
        <> case function_kind {
          audit_metadata.Function -> name
          audit_metadata.Constructor -> "constructor"
          audit_metadata.Fallback -> "fallback"
          audit_metadata.Receive -> "receive"
        }

      let declarations =
        dict.insert(
          declarations,
          id,
          NodeDeclaration(
            title:,
            topic_id: function_id,
            kind: case function_kind {
              audit_metadata.Function -> FunctionDeclaration
              audit_metadata.Constructor -> ConstructorDeclaration
              audit_metadata.Fallback -> FallbackDeclaration
              audit_metadata.Receive -> ReceiveDeclaration
            },
            references: [],
          ),
        )
        |> list.fold(nodes, _, fn(declarations, node) {
          do_enumerate_node_declarations(declarations, node, function_id)
        })
        |> do_enumerate_node_declarations(parameters, function_id)
        |> do_enumerate_node_declarations(return_parameters, function_id)

      case body {
        Some(body) ->
          do_enumerate_node_declarations(declarations, body, function_id)
        option.None -> declarations
      }
    }
    ModifierDefinitionNode(id:, parameters:, nodes:, body:, name:, ..) -> {
      let title = "modifier " <> name
      let modifier_id = parent <> ":" <> name

      let declarations =
        dict.insert(
          declarations,
          id,
          NodeDeclaration(
            title:,
            topic_id: modifier_id,
            kind: ModifierDeclaration,
            references: [],
          ),
        )
        |> list.fold(nodes, _, fn(declarations, node) {
          do_enumerate_node_declarations(declarations, node, title)
        })
        |> do_enumerate_node_declarations(parameters, title)

      case body {
        Some(body) -> do_enumerate_node_declarations(declarations, body, title)
        option.None -> declarations
      }
    }
    ParameterListNode(parameters:, ..) -> {
      list.fold(parameters, declarations, fn(declarations, parameter) {
        do_enumerate_node_declarations(declarations, parameter, parent)
      })
    }
    ErrorDefinitionNode(id:, name:, nodes:, parameters:, ..) -> {
      let title = "error " <> name

      declarations
      |> dict.insert(
        id,
        NodeDeclaration(
          title:,
          topic_id: parent <> ":" <> name,
          kind: ErrorDeclaration,
          references: [],
        ),
      )
      |> list.fold(nodes, _, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, parent)
      })
      |> do_enumerate_node_declarations(parameters, parent)
    }
    EventDefinitionNode(id:, name:, nodes:, parameters:, ..) -> {
      let title = "event " <> name

      declarations
      |> dict.insert(
        id,
        NodeDeclaration(
          title:,
          topic_id: parent <> ":" <> name,
          kind: EventDeclaration,
          references: [],
        ),
      )
      |> list.fold(nodes, _, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, parent)
      })
      |> do_enumerate_node_declarations(parameters, parent)
    }
    VariableDeclarationNode(id:, name:, constant:, type_string:, ..) -> {
      let title =
        case constant {
          True -> "constant "
          False -> ""
        }
        <> type_string
        <> " "
        <> name

      dict.insert(
        declarations,
        id,
        NodeDeclaration(
          title:,
          topic_id: parent <> ":" <> name,
          kind: case constant {
            True -> ConstantDeclaration
            False -> VariableDeclaration
          },
          references: [],
        ),
      )
    }
    BlockNode(nodes:, statements:, ..) -> {
      list.fold(nodes, declarations, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, parent)
      })
      |> list.fold(statements, _, fn(declarations, statement) {
        do_enumerate_node_declarations(declarations, statement, parent)
      })
    }
    VariableDeclarationStatementNode(declarations: declaration_nodes, ..) ->
      list.fold(declaration_nodes, declarations, fn(declarations, declaration) {
        case declaration {
          Some(declaration) ->
            do_enumerate_node_declarations(declarations, declaration, parent)
          option.None -> declarations
        }
      })
    IfStatementNode(true_body:, false_body:, ..) -> {
      let declarations =
        do_enumerate_node_declarations(declarations, true_body, parent)

      case false_body {
        Some(false_body) ->
          do_enumerate_node_declarations(declarations, false_body, parent)
        option.None -> declarations
      }
    }
    ForStatementNode(initialization_expression:, body:, ..) -> {
      let declarations = case initialization_expression {
        option.Some(init) ->
          do_enumerate_node_declarations(declarations, init, parent)
        option.None -> declarations
      }

      do_enumerate_node_declarations(declarations, body, parent)
    }
    EnumDefinition(id:, name:, members:, nodes:, ..) -> {
      let title = "enum " <> name
      let enum_id = parent <> ":" <> name
      dict.insert(
        declarations,
        id,
        NodeDeclaration(
          title:,
          topic_id: enum_id,
          kind: EnumDeclaration,
          references: [],
        ),
      )
      |> list.fold(nodes, _, fn(declarations, statement) {
        do_enumerate_node_declarations(declarations, statement, enum_id)
      })
      |> list.fold(members, _, fn(declarations, statement) {
        do_enumerate_node_declarations(declarations, statement, enum_id)
      })
    }
    EnumValue(id:, name:, ..) -> {
      let title = "enum value " <> name

      dict.insert(
        declarations,
        id,
        NodeDeclaration(
          title:,
          topic_id: parent <> ":" <> name,
          kind: EnumValueDeclaration,
          references: [],
        ),
      )
    }
    StructDefinition(id:, name:, members:, nodes:, ..) -> {
      let title = "struct " <> name
      let struct_id = parent <> ":" <> name
      dict.insert(
        declarations,
        id,
        NodeDeclaration(
          title:,
          topic_id: struct_id,
          kind: StructDeclaration,
          references: [],
        ),
      )
      |> list.fold(nodes, _, fn(declarations, statement) {
        do_enumerate_node_declarations(declarations, statement, struct_id)
      })
      |> list.fold(members, _, fn(declarations, statement) {
        do_enumerate_node_declarations(declarations, statement, struct_id)
      })
    }

    _ -> declarations
  }
}

pub fn count_references(declarations, in ast: AST) {
  list.fold(ast.nodes, declarations, fn(declarations, node) {
    do_count_node_references(declarations, node, "", ast.absolute_path)
  })
}

fn do_count_node_references(
  declarations,
  node: Node,
  parent_title: String,
  parent_id: String,
) {
  case node {
    Node(nodes:, ..)
    | NamedNode(nodes:, ..)
    | ParameterListNode(parameters: nodes, ..)
    | ErrorDefinitionNode(nodes:, ..)
    | TupleExpression(nodes:, ..)
    | EnumDefinition(nodes:, ..)
    | StructDefinition(nodes:, ..)
    | EventDefinitionNode(nodes:, ..) ->
      list.fold(nodes, declarations, fn(declarations, node) {
        do_count_node_references(declarations, node, parent_title, parent_id)
      })

    ImportDirectiveNode(..)
    | VariableDeclarationNode(..)
    | StructuredDocumentationNode(..)
    | ElementaryTypeNameExpression(..)
    | EnumValue(..)
    | Literal(..) -> declarations

    ContractDefinitionNode(nodes:, base_contracts:, name:, contract_kind:, ..) -> {
      let title =
        audit_metadata.contract_kind_to_string(contract_kind) <> " " <> name
      let contract_id = parent_id <> "#" <> name

      list.fold(nodes, declarations, fn(declarations, base_contract) {
        do_count_node_references(
          declarations,
          base_contract,
          title,
          contract_id,
        )
      })
      |> list.fold(base_contracts, _, fn(declarations, base_contract) {
        do_count_node_references(
          declarations,
          base_contract,
          title,
          contract_id,
        )
      })
    }

    FunctionDefinitionNode(
      nodes:,
      parameters:,
      modifiers:,
      return_parameters:,
      body:,
      function_kind:,
      name:,
      ..,
    ) -> {
      let title = case function_kind {
        audit_metadata.Function -> "function " <> name
        audit_metadata.Constructor -> "constructor"
        audit_metadata.Fallback -> "fallback function"
        audit_metadata.Receive -> "receive function"
      }
      let function_id =
        parent_id
        <> ":"
        <> case function_kind {
          audit_metadata.Function -> name
          audit_metadata.Constructor -> "constructor"
          audit_metadata.Fallback -> "fallback"
          audit_metadata.Receive -> "receive"
        }

      let declarations =
        list.fold(nodes, declarations, fn(declarations, node) {
          do_count_node_references(declarations, node, title, function_id)
        })
        |> do_count_node_references(parameters, title, function_id)
        |> do_count_node_references(return_parameters, title, function_id)
        |> list.fold(modifiers, _, fn(declarations, modifier) {
          do_count_node_references(declarations, modifier, title, function_id)
        })

      case body {
        Some(body) ->
          do_count_node_references(declarations, body, title, function_id)
        option.None -> declarations
      }
    }
    ModifierDefinitionNode(nodes:, parameters:, body:, name:, ..) -> {
      let title = "modifier " <> name
      let modifier_id = parent_id <> ":" <> name

      let declarations =
        list.fold(nodes, declarations, fn(declarations, node) {
          do_count_node_references(declarations, node, title, modifier_id)
        })
        |> do_count_node_references(parameters, title, modifier_id)

      case body {
        Some(body) ->
          do_count_node_references(declarations, body, title, modifier_id)
        option.None -> declarations
      }
    }
    BlockNode(nodes:, statements:, ..) -> {
      list.fold(nodes, declarations, fn(declarations, node) {
        do_count_node_references(declarations, node, parent_title, parent_id)
      })
      |> list.fold(statements, _, fn(declarations, statement) {
        do_count_node_references(
          declarations,
          statement,
          parent_title,
          parent_id,
        )
      })
    }
    ExpressionStatementNode(expression:, ..) ->
      case expression {
        Some(expression) ->
          do_count_node_references(
            declarations,
            expression,
            parent_title,
            parent_id,
          )
        option.None -> declarations
      }
    EmitStatementNode(event_call:, ..) ->
      do_count_node_references(
        declarations,
        event_call,
        parent_title,
        parent_id,
      )

    VariableDeclarationStatementNode(initial_value:, ..) ->
      case initial_value {
        option.Some(initial_value) ->
          do_count_node_references(
            declarations,
            initial_value,
            parent_title,
            parent_id,
          )
        option.None -> declarations
      }
    IfStatementNode(condition:, true_body:, false_body:, ..) -> {
      let declarations =
        do_count_node_references(
          declarations,
          condition,
          parent_title,
          parent_id,
        )
        |> do_count_node_references(true_body, parent_title, parent_id)

      case false_body {
        Some(false_body) ->
          do_count_node_references(
            declarations,
            false_body,
            parent_title,
            parent_id,
          )
        option.None -> declarations
      }
    }
    ForStatementNode(
      initialization_expression:,
      condition:,
      loop_expression:,
      body:,
      ..,
    ) ->
      case initialization_expression {
        option.Some(init) ->
          do_count_node_references(declarations, init, parent_title, parent_id)
        option.None -> declarations
      }
      |> fn(declarations) {
        case condition {
          option.Some(condition) ->
            do_count_node_references(
              declarations,
              condition,
              parent_title,
              parent_id,
            )
          option.None -> declarations
        }
      }
      |> fn(declarations) {
        case loop_expression {
          option.Some(loop) ->
            do_count_node_references(
              declarations,
              loop,
              parent_title,
              parent_id,
            )
          option.None -> declarations
        }
      }
      |> do_count_node_references(body, parent_title, parent_id)
    RevertStatementNode(expression:, ..) ->
      case expression {
        Some(expression) ->
          do_count_node_references(
            declarations,
            expression,
            parent_title,
            parent_id,
          )
        option.None -> declarations
      }

    Expression(expression:, ..) ->
      case expression {
        Some(expression) ->
          do_count_node_references(
            declarations,
            expression,
            parent_title,
            parent_id,
          )
        option.None -> declarations
      }

    Identifier(reference_id:, expression:, ..) ->
      case expression {
        Some(expression) ->
          do_count_node_references(
            declarations,
            expression,
            parent_title,
            parent_id,
          )
        option.None -> declarations
      }
      |> add_reference(
        reference_id,
        NodeReference(title: parent_title, topic_id: parent_id),
      )

    MemberAccess(reference_id:, expression:, ..) ->
      case reference_id {
        option.Some(reference_id) ->
          add_reference(
            declarations,
            reference_id,
            NodeReference(title: parent_title, topic_id: parent_id),
          )
        option.None -> declarations
      }
      |> fn(declarations) {
        case expression {
          Some(expression) ->
            do_count_node_references(
              declarations,
              expression,
              parent_title,
              parent_id,
            )
          option.None -> declarations
        }
      }

    FunctionCall(reference_id:, arguments:, expression:, ..) ->
      case expression {
        Some(expression) ->
          do_count_node_references(
            declarations,
            expression,
            parent_title,
            parent_id,
          )
        option.None -> declarations
      }
      |> list.fold(arguments, _, fn(declarations, argument) {
        do_count_node_references(
          declarations,
          argument,
          parent_title,
          parent_id,
        )
      })
      |> add_reference(
        reference_id,
        NodeReference(title: parent_title, topic_id: parent_id),
      )

    Assignment(left_hand_side:, right_hand_side:, ..) ->
      do_count_node_references(
        declarations,
        left_hand_side,
        parent_title,
        parent_id,
      )
      |> do_count_node_references(right_hand_side, parent_title, parent_id)

    BinaryOperation(left_expression:, right_expression:, ..) ->
      do_count_node_references(
        declarations,
        left_expression,
        parent_title,
        parent_id,
      )
      |> do_count_node_references(right_expression, parent_title, parent_id)

    UnaryOperation(expression:, ..) ->
      do_count_node_references(
        declarations,
        expression,
        parent_title,
        parent_id,
      )

    IndexAccess(base:, index:, ..) ->
      case index {
        option.Some(index) ->
          do_count_node_references(declarations, index, parent_title, parent_id)
        option.None -> declarations
      }
      |> do_count_node_references(base, parent_title, parent_id)

    Modifier(reference_id:, arguments:, ..) ->
      add_reference(
        declarations,
        reference_id,
        NodeReference(title: parent_title, topic_id: parent_id),
      )
      |> fn(declarations) {
        case arguments {
          Some(arguments) ->
            list.fold(arguments, declarations, fn(declarations, argument) {
              do_count_node_references(
                declarations,
                argument,
                parent_title,
                parent_id,
              )
            })
          option.None -> declarations
        }
      }
    IdentifierPath(reference_id:, ..) ->
      add_reference(
        declarations,
        reference_id,
        NodeReference(title: parent_title, topic_id: parent_id),
      )
    BaseContract(reference_id:, ..) ->
      add_reference(
        declarations,
        reference_id,
        NodeReference(title: parent_title, topic_id: parent_id),
      )
    Conditional(condition:, true_expression:, false_expression:, ..) ->
      do_count_node_references(declarations, condition, parent_title, parent_id)
      |> do_count_node_references(true_expression, parent_title, parent_id)
      |> do_count_node_references(false_expression, parent_title, parent_id)
    UserDefinedTypeName(path_node:, ..) ->
      do_count_node_references(declarations, path_node, parent_title, parent_id)
  }
}

fn add_reference(declarations, declaration_id: Int, reference: NodeReference) {
  dict.upsert(declarations, declaration_id, with: fn(dec) {
    case dec {
      Some(node_declaration) ->
        NodeDeclaration(..node_declaration, references: [
          reference,
          ..node_declaration.references
        ])

      option.None -> {
        io.println(
          "No declaration for "
          <> int.to_string(declaration_id)
          <> " found, there is an issue with finding all declarations",
        )
        NodeDeclaration(
          title: "unknown",
          topic_id: "",
          kind: UnknownDeclaration,
          references: [reference],
        )
      }
    }
  })
}

pub fn read_asts(for audit_name: String) {
  // The AST is stored in a file called "out/<FileName>.sol/<ContractName>.json, ..."
  let out_dir = config.get_audit_path(for: audit_name) |> filepath.join("out")

  use build_dirs <- result.try(
    simplifile.read_directory(out_dir)
    |> snag.map_error(simplifile.describe_error)
    |> snag.context("Failed to read build files for " <> audit_name),
  )

  let build_dirs =
    list.filter(build_dirs, fn(file_name) {
      case filepath.extension(file_name) {
        Ok("sol") -> True
        _ -> False
      }
    })

  let res = {
    use file_name <- list.map(build_dirs)
    let build_dir = out_dir |> filepath.join(file_name)

    let build_files =
      build_dir
      |> simplifile.read_directory
      |> result.unwrap([])

    use build_file <- list.map(build_files)

    use source_file_contents <- result.try(
      filepath.join(build_dir, build_file)
      |> simplifile.read
      |> snag.map_error(simplifile.describe_error)
      |> snag.context(
        "Failed to read build file " <> build_file <> " for " <> file_name,
      ),
    )

    use ast <- result.try(
      json.parse(
        source_file_contents,
        decode.at(["ast"], ast_decoder(audit_name)),
      )
      |> snag.map_error(string.inspect)
      |> snag.context("Failed to parse build file for " <> file_name),
    )

    #(ast.absolute_path, ast) |> Ok
  }

  res
  |> list.flatten
  |> snagx.collect_errors
}

pub type AST {
  AST(id: Int, absolute_path: String, nodes: List(Node))
}

pub fn ast_decoder(for audit_name) -> decode.Decoder(AST) {
  use id <- decode.field("id", decode.int)
  echo id
  use absolute_path <- decode.field("absolutePath", decode.string)
  use nodes <- decode.field("nodes", decode.list(node_decoder()))
  decode.success(AST(
    id:,
    absolute_path: filepath.join(audit_name, absolute_path),
    nodes:,
  ))
}

pub const empty_ast = AST(id: -1, absolute_path: "", nodes: [])

pub type Node {
  Node(id: Int, source_map: SourceMap, node_type: String, nodes: List(Node))
  NamedNode(id: Int, source_map: SourceMap, name: String, nodes: List(Node))
  ImportDirectiveNode(
    id: Int,
    source_map: SourceMap,
    file: String,
    absolute_path: String,
  )
  ContractDefinitionNode(
    id: Int,
    source_map: SourceMap,
    name: String,
    contract_kind: audit_metadata.ContractKind,
    base_contracts: List(Node),
    nodes: List(Node),
  )
  VariableDeclarationNode(
    id: Int,
    source_map: SourceMap,
    name: String,
    constant: Bool,
    mutability: String,
    visibility: String,
    type_string: String,
    type_name: option.Option(Node),
    value: option.Option(Node),
  )
  ErrorDefinitionNode(
    id: Int,
    source_map: SourceMap,
    name: String,
    nodes: List(Node),
    parameters: Node,
  )
  EventDefinitionNode(
    id: Int,
    source_map: SourceMap,
    name: String,
    parameters: Node,
    nodes: List(Node),
  )
  FunctionDefinitionNode(
    id: Int,
    source_map: SourceMap,
    name: String,
    function_kind: audit_metadata.FunctionKind,
    parameters: Node,
    modifiers: List(Node),
    return_parameters: Node,
    nodes: List(Node),
    body: option.Option(Node),
    documentation: option.Option(Node),
  )
  ModifierDefinitionNode(
    id: Int,
    source_map: SourceMap,
    name: String,
    parameters: Node,
    nodes: List(Node),
    body: option.Option(Node),
    documentation: option.Option(Node),
  )
  ParameterListNode(id: Int, source_map: SourceMap, parameters: List(Node))
  BlockNode(
    id: Int,
    source_map: SourceMap,
    nodes: List(Node),
    statements: List(Node),
    expression: option.Option(Node),
  )
  StructuredDocumentationNode(id: Int, source_map: SourceMap, text: String)
  ExpressionStatementNode(
    id: Int,
    source_map: SourceMap,
    expression: option.Option(Node),
  )
  EmitStatementNode(id: Int, source_map: SourceMap, event_call: Node)
  VariableDeclarationStatementNode(
    id: Int,
    source_map: SourceMap,
    declarations: List(option.Option(Node)),
    initial_value: option.Option(Node),
  )
  IfStatementNode(
    id: Int,
    source_map: SourceMap,
    condition: Node,
    true_body: Node,
    false_body: option.Option(Node),
  )
  ForStatementNode(
    id: Int,
    source_map: SourceMap,
    initialization_expression: option.Option(Node),
    condition: option.Option(Node),
    loop_expression: option.Option(Node),
    body: Node,
  )
  RevertStatementNode(
    id: Int,
    source_map: SourceMap,
    expression: option.Option(Node),
  )
  Expression(id: Int, source_map: SourceMap, expression: option.Option(Node))
  Identifier(
    id: Int,
    source_map: SourceMap,
    name: String,
    reference_id: Int,
    expression: option.Option(Node),
  )
  FunctionCall(
    id: Int,
    source_map: SourceMap,
    name: String,
    reference_id: Int,
    arguments: List(Node),
    kind: FunctionCallKind,
    expression: option.Option(Node),
  )
  Assignment(
    id: Int,
    source_map: SourceMap,
    left_hand_side: Node,
    right_hand_side: Node,
  )
  BinaryOperation(
    id: Int,
    source_map: SourceMap,
    left_expression: Node,
    right_expression: Node,
    operator: String,
  )
  UnaryOperation(
    id: Int,
    source_map: SourceMap,
    expression: Node,
    operator: String,
  )
  IndexAccess(
    id: Int,
    source_map: SourceMap,
    base: Node,
    index: option.Option(Node),
  )
  Modifier(
    id: Int,
    source_map: SourceMap,
    name: String,
    kind: ModifierKind,
    reference_id: Int,
    arguments: option.Option(List(Node)),
  )
  IdentifierPath(
    id: Int,
    source_map: SourceMap,
    name: String,
    reference_id: Int,
  )
  BaseContract(id: Int, source_map: SourceMap, name: String, reference_id: Int)
  TupleExpression(id: Int, source_map: SourceMap, nodes: List(Node))
  ElementaryTypeNameExpression(id: Int, source_map: SourceMap, name: String)
  Literal(id: Int, source_map: SourceMap, kind: LiteralKind, value: String)
  MemberAccess(
    id: Int,
    source_map: SourceMap,
    name: String,
    is_global_access: Bool,
    reference_id: option.Option(Int),
    expression: option.Option(Node),
  )
  Conditional(
    id: Int,
    source_map: SourceMap,
    condition: Node,
    false_expression: Node,
    true_expression: Node,
  )
  EnumDefinition(
    id: Int,
    source_map: SourceMap,
    name: String,
    nodes: List(Node),
    members: List(Node),
  )
  EnumValue(id: Int, source_map: SourceMap, name: String)
  StructDefinition(
    id: Int,
    source_map: SourceMap,
    name: String,
    nodes: List(Node),
    members: List(Node),
  )
  UserDefinedTypeName(id: Int, source_map: SourceMap, path_node: Node)
}

pub type SourceMap {
  SourceMap(start: Int, length: Int)
}

fn get_source_map_end(source_map: SourceMap) {
  source_map.start + source_map.length
}

fn source_map_from_string(source_map_string) {
  case string.split(source_map_string, on: ":") {
    [start_string, length_string, _] -> {
      let start = int.parse(start_string)
      let length = int.parse(length_string)

      case start, length {
        Ok(start), Ok(length) -> SourceMap(start, length)
        Error(..), _ -> panic as "Failed to parse source map start"
        _, Error(..) -> panic as "Failed to parse source map length"
      }
    }
    _ -> SourceMap(-1, -1)
    // panic as { "Failed to split source map string" <> source_map_string }
  }
}

pub type ModifierKind {
  BaseConstructorSpecifier
  ModifierInvocation
}

fn modifier_kind_from_string(kind) {
  case kind {
    "baseConstructorSpecifier" -> BaseConstructorSpecifier
    "modifierInvocation" -> ModifierInvocation
    _ -> panic as "Invalid modifier kind given"
  }
}

pub type LiteralKind {
  NumberLiteral
  StringLiteral
  HexStringLiteral
  BoolLiteral
}

fn literal_kind_from_string(kind) {
  case kind {
    "number" -> NumberLiteral
    "string" -> StringLiteral
    "hexString" -> HexStringLiteral
    "bool" -> BoolLiteral
    _ -> panic as "Invalid literal kind given"
  }
}

pub type FunctionCallKind {
  Call
  TypeConversion
  StructConstructorCall
}

fn function_call_kind_from_string(kind) {
  case kind {
    "functionCall" -> Call
    "typeConversion" -> TypeConversion
    "structConstructorCall" -> StructConstructorCall
    _ -> panic as "Invalid function call kind given"
  }
}

fn node_decoder() -> decode.Decoder(Node) {
  use <- decode.recursive
  use variant <- decode.field("nodeType", decode.string)
  case variant {
    "ImportDirective" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use file <- decode.field("file", decode.string)
      use absolute_path <- decode.field("absolutePath", decode.string)
      decode.success(ImportDirectiveNode(
        id:,
        source_map: source_map_from_string(src),
        file:,
        absolute_path: absolute_path,
      ))
    }
    "ContractDefinition" -> {
      use id <- decode.field("id", decode.int)
      use name <- decode.field("name", decode.string)
      use name_location <- decode.field("nameLocation", decode.string)
      use contract_kind <- decode.field("contractKind", decode.string)
      use abstract <- decode.field("abstract", decode.bool)
      use base_contracts <- decode.field(
        "baseContracts",
        decode.list(node_decoder()),
      )
      use nodes <- decode.optional_field(
        "nodes",
        [],
        decode.list(node_decoder()),
      )
      let contract_kind = case abstract {
        True -> "abstract contract"
        False -> contract_kind
      }
      decode.success(ContractDefinitionNode(
        id:,
        source_map: source_map_from_string(name_location),
        name:,
        contract_kind: audit_metadata.contract_kind_from_string(contract_kind),
        base_contracts:,
        nodes:,
      ))
    }
    "VariableDeclaration" -> {
      use id <- decode.field("id", decode.int)
      use name <- decode.field("name", decode.string)
      use name_location <- decode.field("nameLocation", decode.string)
      use constant <- decode.field("constant", decode.bool)
      use mutability <- decode.field("mutability", decode.string)
      use visibility <- decode.field("visibility", decode.string)
      use type_string <- decode.subfield(
        ["typeDescriptions", "typeString"],
        decode.string,
      )
      // use type_name <- decode.optional_field(
      //   "typeName",
      //   option.None,
      //   decode.optional(node_decoder()),
      // )
      use value <- decode.optional_field(
        "value",
        option.None,
        decode.optional(node_decoder()),
      )
      decode.success(VariableDeclarationNode(
        id:,
        source_map: source_map_from_string(name_location),
        name:,
        constant:,
        mutability:,
        visibility:,
        type_string:,
        type_name: option.None,
        value:,
      ))
    }
    "ErrorDefinition" -> {
      use id <- decode.field("id", decode.int)
      use name <- decode.field("name", decode.string)
      use name_location <- decode.field("nameLocation", decode.string)
      use nodes <- decode.optional_field(
        "nodes",
        [],
        decode.list(node_decoder()),
      )
      use parameters <- decode.field("parameters", node_decoder())

      decode.success(ErrorDefinitionNode(
        id:,
        source_map: source_map_from_string(name_location),
        name:,
        nodes:,
        parameters:,
      ))
    }
    "EventDefinition" -> {
      use id <- decode.field("id", decode.int)
      use name <- decode.field("name", decode.string)
      use name_location <- decode.field("nameLocation", decode.string)
      use parameters <- decode.field("parameters", node_decoder())
      use nodes <- decode.optional_field(
        "nodes",
        [],
        decode.list(node_decoder()),
      )

      decode.success(EventDefinitionNode(
        id:,
        source_map: source_map_from_string(name_location),
        name:,
        parameters:,
        nodes:,
      ))
    }
    "FunctionDefinition" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use name_location <- decode.field("nameLocation", decode.string)
      use name <- decode.field("name", decode.string)
      use kind <- decode.field("kind", decode.string)
      use parameters <- decode.field("parameters", node_decoder())
      use modifiers <- decode.field("modifiers", decode.list(node_decoder()))
      use return_parameters <- decode.field("returnParameters", node_decoder())
      use nodes <- decode.optional_field(
        "nodes",
        [],
        decode.list(node_decoder()),
      )
      use body <- decode.optional_field(
        "body",
        option.None,
        decode.optional(node_decoder()),
      )
      use documentation <- decode.optional_field(
        "documentation",
        option.None,
        decode.optional(node_decoder()),
      )
      let function_kind = audit_metadata.function_kind_from_string(kind)

      let location = source_map_from_string(src)
      let name_location = source_map_from_string(name_location)

      let #(name, source_map) = case function_kind {
        audit_metadata.Constructor -> #(
          "constructor",
          SourceMap(location.start, 11),
        )
        audit_metadata.Function -> #(name, name_location)
        audit_metadata.Fallback -> #("fallback", SourceMap(location.start, 8))
        audit_metadata.Receive -> #("receive", SourceMap(location.start, 7))
      }

      decode.success(FunctionDefinitionNode(
        id:,
        source_map:,
        name:,
        function_kind:,
        parameters:,
        modifiers:,
        return_parameters:,
        nodes:,
        body:,
        documentation:,
      ))
    }
    "ModifierDefinition" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("nameLocation", decode.string)
      use name <- decode.field("name", decode.string)
      use parameters <- decode.field("parameters", node_decoder())
      use nodes <- decode.optional_field(
        "nodes",
        [],
        decode.list(node_decoder()),
      )
      use body <- decode.optional_field(
        "body",
        option.None,
        decode.optional(node_decoder()),
      )
      use documentation <- decode.optional_field(
        "documentation",
        option.None,
        decode.optional(node_decoder()),
      )
      decode.success(ModifierDefinitionNode(
        id:,
        source_map: source_map_from_string(src),
        name:,
        parameters:,
        nodes:,
        body:,
        documentation:,
      ))
    }
    "ParameterList" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use parameters <- decode.field("parameters", decode.list(node_decoder()))
      decode.success(ParameterListNode(
        id:,
        source_map: source_map_from_string(src),
        parameters:,
      ))
    }
    "Block" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use nodes <- decode.optional_field(
        "nodes",
        [],
        decode.list(node_decoder()),
      )

      use statements <- decode.optional_field(
        "statements",
        [],
        decode.list(node_decoder()),
      )
      use expression <- decode.optional_field(
        "expression",
        option.None,
        decode.optional(node_decoder()),
      )
      decode.success(BlockNode(
        id:,
        source_map: source_map_from_string(src),
        nodes:,
        statements:,
        expression:,
      ))
    }
    "StructuredDocumentation" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)

      use text <- decode.field("text", decode.string)
      decode.success(StructuredDocumentationNode(
        id:,
        source_map: source_map_from_string(src),
        text:,
      ))
    }
    "EmitStatement" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use event_call <- decode.field("eventCall", node_decoder())
      decode.success(EmitStatementNode(
        id:,
        source_map: source_map_from_string(src),
        event_call:,
      ))
    }
    "VariableDeclarationStatement" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use declarations <- decode.field(
        "declarations",
        decode.list(decode.optional(node_decoder())),
      )
      use initial_value <- decode.optional_field(
        "initialValue",
        option.None,
        decode.optional(node_decoder()),
      )
      decode.success(VariableDeclarationStatementNode(
        id:,
        source_map: source_map_from_string(src),
        declarations:,
        initial_value:,
      ))
    }
    "IfStatement" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use condition <- decode.field("condition", node_decoder())
      use true_body <- decode.field("trueBody", node_decoder())
      use false_body <- decode.optional_field(
        "falseBody",
        option.None,
        decode.optional(node_decoder()),
      )
      decode.success(IfStatementNode(
        id:,
        source_map: source_map_from_string(src),
        condition:,
        true_body:,
        false_body:,
      ))
    }
    "ForStatement" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use initialization_expression <- decode.optional_field(
        "initializationExpression",
        option.None,
        decode.optional(node_decoder()),
      )
      use condition <- decode.optional_field(
        "condition",
        option.None,
        decode.optional(node_decoder()),
      )
      use loop_expression <- decode.optional_field(
        "loopExpression",
        option.None,
        decode.optional(node_decoder()),
      )
      use body <- decode.field("body", node_decoder())
      decode.success(ForStatementNode(
        id:,
        source_map: source_map_from_string(src),
        initialization_expression:,
        condition:,
        loop_expression:,
        body:,
      ))
    }
    "RevertStatement" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use expression <- decode.optional_field(
        "errorCall",
        option.None,
        decode.optional(node_decoder()),
      )
      decode.success(RevertStatementNode(
        id:,
        source_map: source_map_from_string(src),
        expression:,
      ))
    }
    "ExpressionStatement" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use expression <- decode.optional_field(
        "expression",
        option.None,
        decode.optional(node_decoder()),
      )
      decode.success(ExpressionStatementNode(
        id:,
        source_map: source_map_from_string(src),
        expression:,
      ))
    }
    "FunctionCall" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use arguments <- decode.field("arguments", decode.list(node_decoder()))
      use kind <- decode.field("kind", decode.string)
      use expression <- decode.optional_field(
        "expression",
        option.None,
        decode.optional(node_decoder()),
      )
      // We want to tie the name of the function being called to the function
      // call node, but it is stored in an optional expression field. So, try
      // and pull the values out of the expression field if it exists and add
      // them directly to the function call node.
      let #(source_map, name, reference_id, expression) = case expression {
        Some(Identifier(source_map:, name:, reference_id:, expression:, ..)) -> #(
          source_map,
          name,
          reference_id,
          expression,
        )
        Some(MemberAccess(
          source_map:,
          name:,
          reference_id: option.Some(reference_id),
          expression:,
          ..,
        )) -> #(source_map, name, reference_id, expression)
        _ -> #(source_map_from_string(src), "", -1, option.None)
      }
      decode.success(FunctionCall(
        id:,
        source_map:,
        name:,
        reference_id:,
        arguments:,
        kind: function_call_kind_from_string(kind),
        expression:,
      ))
    }
    "Assignment" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use left_hand_side <- decode.field("leftHandSide", node_decoder())
      use right_hand_side <- decode.field("rightHandSide", node_decoder())
      decode.success(Assignment(
        id:,
        source_map: source_map_from_string(src),
        left_hand_side:,
        right_hand_side:,
      ))
    }
    "BinaryOperation" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use left_expression <- decode.field("leftExpression", node_decoder())
      use right_expression <- decode.field("rightExpression", node_decoder())
      use operator <- decode.field("operator", decode.string)
      decode.success(BinaryOperation(
        id:,
        source_map: source_map_from_string(src),
        left_expression:,
        right_expression:,
        operator:,
      ))
    }
    "UnaryOperation" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use expression <- decode.field("subExpression", node_decoder())
      use operator <- decode.field("operator", decode.string)
      decode.success(UnaryOperation(
        id:,
        source_map: source_map_from_string(src),
        expression:,
        operator:,
      ))
    }
    "IndexAccess" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use base <- decode.field("baseExpression", node_decoder())
      use index <- decode.optional_field(
        "indexExpression",
        option.None,
        decode.optional(node_decoder()),
      )
      decode.success(IndexAccess(
        id:,
        source_map: source_map_from_string(src),
        base:,
        index:,
      ))
    }
    "Identifier" | "IdentifierPath" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use name <- decode.field("name", decode.string)
      use reference_id <- decode.field("referencedDeclaration", decode.int)
      decode.success(Identifier(
        id:,
        source_map: source_map_from_string(src),
        name:,
        reference_id:,
        expression: option.None,
      ))
    }
    "ModifierInvocation" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.subfield(["modifierName", "src"], decode.string)
      use name <- decode.subfield(["modifierName", "name"], decode.string)
      use reference_id <- decode.subfield(
        ["modifierName", "referencedDeclaration"],
        decode.int,
      )
      use kind <- decode.field("kind", decode.string)
      use arguments <- decode.optional_field(
        "arguments",
        option.None,
        decode.optional(decode.list(node_decoder())),
      )
      decode.success(Modifier(
        id:,
        source_map: source_map_from_string(src),
        name:,
        reference_id:,
        kind: modifier_kind_from_string(kind),
        arguments:,
      ))
    }
    "InheritanceSpecifier" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use name <- decode.subfield(["baseName", "name"], decode.string)
      use reference_id <- decode.subfield(
        ["baseName", "referencedDeclaration"],
        decode.int,
      )
      decode.success(BaseContract(
        id:,
        source_map: source_map_from_string(src),
        name:,
        reference_id:,
      ))
    }
    "TupleExpression" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use nodes <- decode.field("components", decode.list(node_decoder()))
      decode.success(TupleExpression(
        id:,
        source_map: source_map_from_string(src),
        nodes:,
      ))
    }
    "ElementaryTypeNameExpression" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.subfield(["typeName", "src"], decode.string)
      use name <- decode.subfield(["typeName", "name"], decode.string)
      decode.success(ElementaryTypeNameExpression(
        id:,
        source_map: source_map_from_string(src),
        name:,
      ))
    }
    "Literal" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use kind <- decode.field("kind", decode.string)
      use value <- decode.field("value", decode.string)
      decode.success(Literal(
        id:,
        source_map: source_map_from_string(src),
        kind: literal_kind_from_string(kind),
        value:,
      ))
    }
    "MemberAccess" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("memberLocation", decode.string)
      use name <- decode.field("memberName", decode.string)
      use reference_id <- decode.optional_field(
        "referencedDeclaration",
        option.None,
        decode.optional(decode.int),
      )
      use expression <- decode.optional_field(
        "expression",
        option.None,
        decode.optional(node_decoder()),
      )
      let is_global_access = case expression {
        option.Some(Identifier(reference_id:, ..)) if reference_id < 0 -> True
        _ -> False
      }
      decode.success(MemberAccess(
        id:,
        source_map: source_map_from_string(src),
        name:,
        reference_id:,
        is_global_access:,
        expression:,
      ))
    }
    "Conditional" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use condition <- decode.field("condition", node_decoder())
      use true_expression <- decode.field("trueExpression", node_decoder())
      use false_expression <- decode.field("falseExpression", node_decoder())
      decode.success(Conditional(
        id:,
        source_map: source_map_from_string(src),
        condition:,
        true_expression:,
        false_expression:,
      ))
    }
    "EnumDefinition" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("nameLocation", decode.string)
      use name <- decode.field("name", decode.string)
      use nodes <- decode.field("nodes", decode.list(node_decoder()))
      use members <- decode.field("members", decode.list(node_decoder()))
      decode.success(EnumDefinition(
        id:,
        source_map: source_map_from_string(src),
        name:,
        nodes:,
        members:,
      ))
    }
    "EnumValue" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("nameLocation", decode.string)
      use name <- decode.field("name", decode.string)
      decode.success(EnumValue(
        id:,
        source_map: source_map_from_string(src),
        name:,
      ))
    }
    "StructDefinition" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("nameLocation", decode.string)
      use name <- decode.field("name", decode.string)
      use nodes <- decode.field("nodes", decode.list(node_decoder()))
      use members <- decode.field("members", decode.list(node_decoder()))
      decode.success(StructDefinition(
        id:,
        source_map: source_map_from_string(src),
        name:,
        nodes:,
        members:,
      ))
    }
    "UserDefinedTypeName" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("nameLocation", decode.string)
      use path_node <- decode.field("path", node_decoder())
      decode.success(UserDefinedTypeName(
        id:,
        source_map: source_map_from_string(src),
        path_node:,
      ))
    }
    _ -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use node_type <- decode.field("nodeType", decode.string)
      use nodes <- decode.optional_field(
        "nodes",
        [],
        decode.list(node_decoder()),
      )
      use name <- decode.optional_field(
        "name",
        option.None,
        decode.optional(decode.string),
      )
      use name_location <- decode.optional_field(
        "nameLocation",
        option.None,
        decode.optional(decode.string),
      )
      use expression <- decode.optional_field(
        "expression",
        option.None,
        decode.optional(node_decoder()),
      )

      case expression {
        Some(expression) ->
          decode.success(Expression(
            id:,
            source_map: source_map_from_string(src),
            expression: Some(expression),
          ))
        option.None ->
          case name, name_location {
            option.Some(name), option.Some(name_location) ->
              decode.success(NamedNode(
                id:,
                source_map: source_map_from_string(name_location),
                name:,
                nodes:,
              ))
            _, _ ->
              decode.success(Node(
                id:,
                source_map: source_map_from_string(src),
                node_type:,
                nodes:,
              ))
          }
      }
    }
  }
}

pub fn find_contract_id(
  audit_metadata: audit_metadata.AuditMetaData,
  named contract_name,
  in imports,
) {
  list.find_map(imports, fn(import_path) {
    use file_metadata <- result.try(dict.get(
      audit_metadata.source_files_sol,
      import_path |> filepath.base_name,
    ))

    case dict.get(file_metadata.contracts, contract_name) {
      Ok(contract_meta_data) ->
        Ok(#(import_path <> "#" <> contract_name, contract_meta_data.kind))
      Error(Nil) -> Error(Nil)
    }
  })
}

pub fn preprocess_source_old(
  for page_path,
  with audit_metadata: audit_metadata.AuditMetaData,
) {
  use source <- result.try(
    config.get_full_page_path(for: page_path)
    |> simplifile.read,
  )

  use source_file_metadata <- given.ok(
    dict.get(audit_metadata.source_files_sol, page_path |> filepath.base_name),
    else_return: fn(_) { Ok([]) },
  )

  let vals = {
    use line_text, line_number <- list.index_map(
      source |> string.split(on: "\n"),
    )

    let line_number = line_number + 1
    let line_number_text = int.to_string(line_number)
    let line_tag = "L" <> line_number_text
    let line_id = page_path <> "#" <> line_tag
    let leading_spaces = enumerate.get_leading_spaces(line_text)

    let sigificance = classify_line(line_text)

    let preprocessed_line = case sigificance {
      Empty -> line_text |> PreprocessedLine
      Regular -> line_text |> style_code_tokens |> PreprocessedLine
      License -> line_text |> style_license_line |> PreprocessedLine
      PragmaDeclaration -> line_text |> style_pragma_line |> PreprocessedLine
      Import ->
        line_text
        |> process_import_line(source_file_metadata)
        |> PreprocessedLine
      ContractDefinition(contract_kind:) ->
        line_text
        |> process_contract_definition_line(
          contract_kind:,
          page_path:,
          audit_metadata:,
          source_file_metadata:,
        )
      LibraryDirective -> line_text |> style_code_tokens |> PreprocessedLine
      ConstructorDefinition ->
        line_text |> style_code_tokens |> PreprocessedLine
      FallbackFunctionDefinition ->
        line_text |> style_code_tokens |> PreprocessedLine
      ReceiveFunctionDefinition ->
        line_text |> style_code_tokens |> PreprocessedLine
      FunctionDefinition -> line_text |> process_function_definition_line
      StorageVariableDefinition ->
        line_text |> style_code_tokens |> PreprocessedLine
      EventDefinition -> line_text |> style_code_tokens |> PreprocessedLine
      ErrorDefinition -> line_text |> style_code_tokens |> PreprocessedLine
      LocalVariableDefinition ->
        line_text |> style_code_tokens |> PreprocessedLine
    }

    PreprocessedSourceLine(
      line_number:,
      line_number_text:,
      line_tag:,
      line_id:,
      line_text_raw: line_text,
      leading_spaces:,
      preprocessed_line:,
      sigificance:,
    )
  }
  Ok(vals)
}

pub type PreprocessedSourceLine(msg) {
  PreprocessedSourceLine(
    line_number: Int,
    line_number_text: String,
    line_tag: String,
    line_id: String,
    line_text_raw: String,
    leading_spaces: String,
    preprocessed_line: PreprocessedLineElement(msg),
    sigificance: LineSigificance,
  )
}

pub type PreprocessedLineElement(msg) {
  PreprocessedLine(preprocessed_line_text: String)
  PreprocessedContractDefinition(
    contract_id: String,
    contract_name: String,
    contract_kind: audit_metadata.ContractKind,
    contract_inheritances: List(ExternalContractReference),
    process_line: fn(element.Element(msg), List(element.Element(msg))) ->
      element.Element(msg),
  )
  PreprocessedFunctionDefinition(
    function_id: String,
    function_name: String,
    process_line: fn(element.Element(msg)) -> element.Element(msg),
  )
}

pub type ExternalContractReference {
  ExternalReference(name: String, id: String, kind: audit_metadata.ContractKind)
}

pub type LineSigificance {
  Empty
  Regular
  License
  PragmaDeclaration
  Import
  ContractDefinition(contract_kind: audit_metadata.ContractKind)
  LibraryDirective
  ConstructorDefinition
  FallbackFunctionDefinition
  ReceiveFunctionDefinition
  FunctionDefinition
  StorageVariableDefinition
  EventDefinition
  ErrorDefinition
  LocalVariableDefinition
}

fn classify_line(line_text) {
  let trimmed_line_text = line_text |> string.trim

  use <- bool.guard(trimmed_line_text == "", Empty)
  use <- bool.guard(trimmed_line_text == "}", Empty)
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("// SPDX-License-Identifier"),
    License,
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("pragma"),
    PragmaDeclaration,
  )
  use <- bool.guard(trimmed_line_text |> string.starts_with("import"), Import)
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("contract"),
    ContractDefinition(contract_kind: audit_metadata.Contract),
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("abstract contract"),
    ContractDefinition(contract_kind: audit_metadata.Abstract),
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("interface"),
    ContractDefinition(contract_kind: audit_metadata.Interface),
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("library"),
    ContractDefinition(contract_kind: audit_metadata.Library),
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("using"),
    LibraryDirective,
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("constructor"),
    ConstructorDefinition,
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("fallback"),
    FallbackFunctionDefinition,
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("receive"),
    ReceiveFunctionDefinition,
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("function"),
    FunctionDefinition,
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("event"),
    EventDefinition,
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("error"),
    ErrorDefinition,
  )
  // todo classify storage variables
  Regular
}

pub fn style_license_line(line_text) {
  html.span([attribute.class("comment")], [html.text(line_text)])
  |> element.to_string
}

pub fn process_import_line(
  line_text,
  source_file_metadata: audit_metadata.SourceFileMetaData,
) {
  let #(import_statement_base, import_path) =
    line_text
    |> string.split_once("\"")
    |> result.unwrap(#(line_text, ""))

  // Remove the "import " that is always present
  let import_statement_base = import_statement_base |> string_drop_start(7)
  // Remove the trailing "";"
  let import_path = import_path |> string_drop_end(2)

  let assert Ok(capitalized_word_regex) = regexp.from_string("\\b[A-Z]\\w+\\b")

  html.span([attribute.class("keyword")], [html.text("import")])
  |> element.to_string
  <> " "
  <> regexp.match_map(capitalized_word_regex, import_statement_base, fn(match) {
    html.span([attribute.class("contract")], [html.text(match.content)])
    |> element.to_string
  })
  |> string.replace(
    "from",
    html.span([attribute.class("keyword")], [html.text("from")])
      |> element.to_string,
  )
  <> html.span([attribute.class("string")], [
    html.text("\""),
    html.a(
      [
        attribute.class("import-path"),
        attribute.href(
          dict.get(source_file_metadata.imports, import_path)
          |> result.map(fn(abs_import) { "/" <> abs_import })
          |> result.unwrap(""),
        ),
      ],
      [html.text(import_path)],
    ),
    html.text("\""),
  ])
  |> element.to_string
  <> ";"
}

pub fn process_contract_definition_line(
  page_path page_path,
  contract_kind contract_kind: audit_metadata.ContractKind,
  line_text line_text,
  audit_metadata audit_metadata,
  source_file_metadata source_file_metadata: audit_metadata.SourceFileMetaData,
) {
  case string.split_once(line_text, " is ") {
    Ok(#(line_base, contract_inheritance)) -> {
      let contract_name = case contract_kind {
        // Remove "contract "
        audit_metadata.Contract -> line_base |> string_drop_start(9)
        // Remove "abstract contract "
        audit_metadata.Abstract -> line_base |> string_drop_start(18)
        // Remove "interface "
        audit_metadata.Interface -> line_base |> string_drop_start(10)
        // Remove "library "
        audit_metadata.Library -> line_base |> string_drop_start(8)
      }

      let contract_inheritances =
        contract_inheritance
        // Remove " {" 
        |> string_drop_end(2)
        |> string.split(on: ", ")
        |> list.map(fn(inheritance) {
          let #(id, kind) =
            find_contract_id(
              audit_metadata,
              named: inheritance,
              in: dict.values(source_file_metadata.imports),
            )
            |> result.unwrap(#("", audit_metadata.Contract))
          ExternalReference(name: inheritance, id:, kind:)
        })

      let process_line = fn(contract_discussion, inheritances) {
        element.fragment([
          html.span([attribute.class("keyword")], [
            html.text(audit_metadata.contract_kind_to_string(contract_kind)),
          ]),
          html.text("\u{a0}"),
          html.span(
            [
              attribute.id(contract_name),
              attribute.class("contract contract-definition"),
            ],
            [html.text(contract_name), contract_discussion],
          ),
          html.text("\u{a0}"),
          html.span([attribute.class("keyword")], [html.text("is")]),
          html.text("\u{a0}"),
          element.fragment(list.intersperse(inheritances, html.text(", "))),
          html.text(" {"),
        ])
      }

      PreprocessedContractDefinition(
        contract_id: page_path <> "#" <> contract_name,
        contract_name:,
        contract_kind:,
        contract_inheritances:,
        process_line:,
      )
    }
    Error(Nil) -> {
      let contract_name =
        case contract_kind {
          // Remove "contract "
          audit_metadata.Contract -> line_text |> string_drop_start(9)
          // Remove "abstract contract "
          audit_metadata.Abstract -> line_text |> string_drop_start(18)
          // Remove "interface "
          audit_metadata.Interface -> line_text |> string_drop_start(10)
          // Remove "library "
          audit_metadata.Library -> line_text |> string_drop_start(8)
        }
        // Remove " {"
        |> string_drop_end(2)

      let process_line = fn(contract_discussion, _inheritances) {
        element.fragment([
          html.span([attribute.class("keyword")], [
            html.text(
              audit_metadata.contract_kind_to_string(contract_kind) <> " ",
            ),
          ]),
          html.span(
            [
              attribute.id(contract_name),
              attribute.class("contract contract-definition"),
            ],
            [html.text(contract_name), contract_discussion],
          ),
          html.text(" {"),
        ])
      }

      PreprocessedContractDefinition(
        contract_id: page_path <> "#" <> contract_name,
        contract_name:,
        contract_kind:,
        contract_inheritances: [],
        process_line:,
      )
    }
  }
}

pub fn process_function_definition_line(line_text) {
  let #(function_name, rest) =
    string.split_once(line_text, "(")
    |> result.unwrap(#(line_text, ""))

  // Remove "function "
  let function_name = string_drop_start(function_name, 9)

  let #(args, attributes) =
    string.split_once(rest, ")")
    |> result.unwrap(#(rest, ""))

  // Remove " " and trailing " {"
  let attributes =
    string_drop_start(attributes, 1)
    |> string_drop_end(2)

  let process_line = fn(function_discussion) {
    element.fragment([
      html.span([attribute.class("keyword")], [html.text("function ")]),
      html.span(
        [
          attribute.id(function_name),
          attribute.class("function function-definition"),
        ],
        [html.text(function_name), function_discussion],
      ),
      html.text("("),
      style_arguments(args),
      html.text(")"),
      style_fuction_attributes(attributes),
      html.text(" {"),
    ])
  }

  PreprocessedFunctionDefinition(
    function_id: line_text,
    function_name:,
    process_line:,
  )
}

fn style_arguments(args_text) {
  string.split(args_text, on: ", ")
  |> list.map(fn(arg) {
    let #(arg_type, arg_name) =
      string.split_once(arg, on: " ")
      |> result.unwrap(#("", arg))

    [
      html.span([attribute.class("type")], [html.text(arg_type)]),
      html.text(" " <> arg_name),
    ]
  })
  |> list.intersperse([html.text(", ")])
  |> list.flatten
  |> element.fragment
}

fn style_fuction_attributes(attributes_text) {
  string.split(attributes_text, on: " ")
  |> list.map(fn(attribute) {
    case attribute {
      "public"
      | "private"
      | "internal"
      | "external"
      | "view"
      | "pure"
      | "payable"
      | "virtual"
      | "override"
      | "abstract"
      | "returns" -> [
        html.span([attribute.class("keyword")], [html.text(" " <> attribute)]),
      ]
      _ ->
        case string.starts_with(attribute, "(") {
          // Return variables
          True ->
            attribute
            |> string_drop_start(1)
            |> string_drop_end(1)
            |> style_return_variables
            |> fn(return_variables) {
              [html.text(" ("), return_variables, html.text(")")]
            }
          // Modifiers
          False -> [style_function_modifier(attribute)]
        }
    }
  })
  // |> list.intersperse([html.text(" ")])
  |> list.flatten
  |> element.fragment
}

fn style_return_variables(return_variables_text) {
  string.split(return_variables_text, on: ", ")
  |> list.map(fn(arg) {
    let #(arg_type, arg_name) =
      string.split_once(arg, on: " ")
      |> result.unwrap(#(arg, ""))

    [
      html.span([attribute.class("type")], [html.text(arg_type)]),
      case arg_name != "" {
        True -> html.text(" " <> arg_name)
        False -> element.fragment([])
      },
    ]
  })
  |> list.intersperse([html.text(", ")])
  |> list.flatten
  |> element.fragment
}

fn style_function_modifier(modifiers_text) {
  let #(modifier, args) =
    string.split_once(modifiers_text, on: "(")
    |> result.unwrap(#(modifiers_text, ""))

  let args = string_drop_end(args, 1)

  element.fragment([
    html.span([attribute.class("function")], [html.text(" " <> modifier)]),
    html.text("("),
    style_arguments(args),
    html.text(")"),
  ])
}

pub fn style_code_tokens(line_text) {
  let styled_line = line_text

  // Strings really conflict with the html source code ahh. Just ignore them
  // for now, they are not common enough
  // let assert Ok(string_regex) = regexp.from_string("\".*\"")

  // let styled_line =
  //   regexp.match_map(string_regex, styled_line, fn(match) {
  //     html.span([attribute.class("string")], [html.text(match.content)])
  //     |> element.to_string
  //   })

  // First cut out the comments so they don't get any formatting

  let assert Ok(comment_regex) =
    regexp.from_string(
      "(?:\\/\\/.*|^\\s{2,}\\*\\*.*|^\\s{2,}\\*.*|^\\s{2,}\\*\\/.*|\\/\\*.*?\\*\\/)",
    )

  let comments = regexp.scan(comment_regex, styled_line)

  let styled_line = regexp.replace(comment_regex, styled_line, "")

  let assert Ok(operator_regex) =
    regexp.from_string(
      "\\+|\\-|\\*|(?!/)\\/(?!/)|\\={1,2}|\\<(?!span)|(?!span)\\>|\\&|\\!|\\|",
    )

  let styled_line =
    regexp.match_map(operator_regex, styled_line, fn(match) {
      html.span([attribute.class("operator")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(keyword_regex) =
    regexp.from_string(
      "\\b(constructor|contract|continue|break|modifier|fallback|indexed|override|mapping|immutable|interface|virtual|constant|library|abstract|event|error|require|revert|using|for|emit|function|if|else|returns|return|memory|calldata|public|private|external|view|pure|payable|internal|import|enum|struct|storage|is)\\b",
    )

  let styled_line =
    regexp.match_map(keyword_regex, styled_line, fn(match) {
      html.span([attribute.class("keyword")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(global_variable_regex) =
    regexp.from_string(
      "\\b(super|this|msg\\.sender|msg\\.value|tx\\.origin|block\\.timestamp|block\\.chainid)\\b",
    )

  let styled_line =
    regexp.match_map(global_variable_regex, styled_line, fn(match) {
      html.span([attribute.class("global-variable")], [html.text(match.content)])
      |> element.to_string
    })

  // A word with a capital letter at the beginning
  let assert Ok(capitalized_word_regex) = regexp.from_string("\\b[A-Z]\\w+\\b")

  let styled_line =
    regexp.match_map(capitalized_word_regex, styled_line, fn(match) {
      html.span([attribute.class("contract")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(function_regex) = regexp.from_string("\\b(\\w+)\\(")

  let styled_line =
    regexp.match_map(function_regex, styled_line, fn(match) {
      case match.submatches {
        [Some(function_name), ..] ->
          string.replace(
            match.content,
            each: function_name,
            with: element.to_string(
              html.span([attribute.class("function")], [
                html.text(function_name),
              ]),
            ),
          )
        _ -> line_text
      }
    })

  let assert Ok(type_regex) =
    regexp.from_string(
      "\\b(address|bool|bytes|bytes\\d+|string|int|uint|int\\d+|uint\\d+)\\b",
    )

  let styled_line =
    regexp.match_map(type_regex, styled_line, fn(match) {
      html.span([attribute.class("type")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(number_regex) =
    regexp.from_string(
      "(?<!\\w)(?:\\d+(?:[_ \\.]\\d+)*(?:\\s+(?:days|ether|finney|wei))?|0x[0-9a-fA-F]+|\\d+[eE][+-]?\\d+)(?!\\w)",
    )

  let styled_line =
    regexp.match_map(number_regex, styled_line, fn(match) {
      html.span([attribute.class("number")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(literal_regex) = regexp.from_string("\\b(true|false)\\b")

  let styled_line =
    regexp.match_map(literal_regex, styled_line, fn(match) {
      html.span([attribute.class("number")], [html.text(match.content)])
      |> element.to_string
    })

  styled_line
  <> case comments {
    [regexp.Match(match_content, ..), ..] ->
      html.span([attribute.class("comment")], [html.text(match_content)])
      |> element.to_string
    _ -> ""
  }
}

fn string_drop_start(string, num) {
  string.slice(string, num, length: string.length(string) - num)
}

fn string_drop_end(string, num) {
  string.slice(string, 0, length: string.length(string) - num)
}
