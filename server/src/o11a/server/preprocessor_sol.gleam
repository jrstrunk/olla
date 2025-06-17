import filepath
import given
import gleam/bit_array
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
import o11a/config
import o11a/preprocessor
import o11a/topic
import simplifile
import snag

pub fn preprocess_source(
  source source: String,
  nodes nodes: List(Node),
  max_topic_id max_topic_id,
  merged_topics merged_topics: dict.Dict(String, String),
  page_path page_path: String,
  audit_name audit_name: String,
) {
  let data = {
    use acc, line <- list.fold(consume_source(source:, nodes:, audit_name:), #(
      0,
      max_topic_id,
      [],
      [],
      merged_topics,
    ))
    let #(
      index,
      max_topic_id,
      preprocessed_lines,
      addressable_lines,
      merged_topics,
    ) = acc

    let new_index = index + 1

    let line_number = new_index
    let line_number_text = int.to_string(line_number)
    let line_tag = "L" <> line_number_text
    let leading_spaces = case line {
      [preprocessor.PreProcessedGapNode(leading_spaces:, ..), ..] ->
        leading_spaces
      _ -> 0
    }

    let declaration_count =
      list.count(line, fn(decl) {
        case decl {
          preprocessor.PreProcessedDeclaration(..) -> True
          _ -> False
        }
      })

    let reference_count =
      list.count(line, fn(ref) {
        case ref {
          preprocessor.PreProcessedReference(..) -> True
          _ -> False
        }
      })

    let #(new_max_topic_id, topic_id, new_addressable_lines, merged_topics) = case
      declaration_count,
      reference_count
    {
      1, _ -> {
        let new_max_topic_id = max_topic_id + 1

        let assert Ok(preprocessor.PreProcessedDeclaration(topic_id:, ..)) =
          list.find(line, fn(decl) {
            case decl {
              preprocessor.PreProcessedDeclaration(..) -> True
              _ -> False
            }
          })

        let line_topic_id =
          preprocessor.node_id_to_topic_id(
            new_max_topic_id,
            preprocessor.Solidity,
          )

        // Merge this line with the declaration's topic so that we see the
        // declaration's topic when interacting with the line
        let merged_topics = dict.insert(merged_topics, line_topic_id, topic_id)

        #(
          new_max_topic_id,
          option.Some(line_topic_id),
          [
            topic.SourceDeclaration(
              id: new_max_topic_id,
              topic_id: line_topic_id,
              name: "L" <> line_number_text,
              scope: preprocessor.Scope(
                file: filepath.base_name(page_path),
                contract: option.None,
                member: option.None,
              ),
              signature: [
                preprocessor.TextSnippetLine(elements: [
                  preprocessor.PreProcessedNode(
                    element: "Line " <> line_number_text,
                  ),
                ]),
              ],
              kind: preprocessor.LineDeclaration,
              source_map: preprocessor.SourceMap(-1, -1),
              references: [],
              calls: [],
              errors: [],
            ),
          ],
          merged_topics,
        )
      }

      0, 0 -> #(max_topic_id, option.None, [], merged_topics)

      _, _ -> {
        let new_max_topic_id = max_topic_id + 1
        #(
          new_max_topic_id,
          option.Some(preprocessor.node_id_to_topic_id(
            new_max_topic_id,
            preprocessor.Solidity,
          )),
          [
            topic.SourceDeclaration(
              id: new_max_topic_id,
              topic_id: preprocessor.node_id_to_topic_id(
                new_max_topic_id,
                preprocessor.Solidity,
              ),
              name: "L" <> line_number_text,
              scope: preprocessor.Scope(
                file: filepath.base_name(page_path),
                contract: option.None,
                member: option.None,
              ),
              signature: [
                preprocessor.TextSnippetLine(elements: [
                  preprocessor.PreProcessedNode(
                    element: "Line " <> line_number_text,
                  ),
                ]),
              ],
              kind: preprocessor.LineDeclaration,
              source_map: preprocessor.SourceMap(-1, -1),
              references: [],
              calls: [],
              errors: [],
            ),
          ],
          merged_topics,
        )
      }
    }

    let columns =
      list.fold(line, 0, fn(acc, node) {
        case node {
          preprocessor.PreProcessedDeclaration(..)
          | preprocessor.PreProcessedReference(..) -> acc + 1

          preprocessor.PreProcessedNode(..)
          | preprocessor.PreProcessedGapNode(..)
          | preprocessor.FormatterNewline
          | preprocessor.FormatterHeader(..)
          | preprocessor.FormatterBlock(..) -> acc
        }
      })

    #(
      new_index,
      new_max_topic_id,
      [
        preprocessor.PreProcessedLine(
          topic_id:,
          line_number:,
          line_number_text:,
          line_tag:,
          level: leading_spaces,
          elements: line,
          columns:,
          kind: preprocessor.Solidity,
        ),
        ..preprocessed_lines
      ],
      list.append(new_addressable_lines, addressable_lines),
      merged_topics,
    )
  }

  let #(_index, max_topic_id, lines, addressable_lines, merged_topics) = data
  #(max_topic_id, lines |> list.reverse, addressable_lines, merged_topics)
}

pub fn consume_source(
  source source: String,
  nodes nodes: List(Node),
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
        | EnumValue(id:, ..) -> {
          preprocessor.PreProcessedDeclaration(
            topic_id: preprocessor.node_id_to_topic_id(
              id,
              preprocessor.Solidity,
            ),
            tokens: _,
          )
        }

        BaseContract(reference_id:, ..) | Modifier(reference_id:, ..) -> {
          preprocessor.PreProcessedReference(
            topic_id: preprocessor.node_id_to_topic_id(
              reference_id,
              preprocessor.Solidity,
            ),
            tokens: _,
          )
        }

        Identifier(reference_id:, ..) | IdentifierPath(reference_id:, ..) ->
          case reference_id < 0 {
            True -> style_tokens(_, class: "global-variable")
            False -> {
              preprocessor.PreProcessedReference(
                topic_id: preprocessor.node_id_to_topic_id(
                  reference_id,
                  preprocessor.Solidity,
                ),
                tokens: _,
              )
            }
          }

        MemberAccess(reference_id:, is_global_access:, ..) ->
          case reference_id, is_global_access {
            option.Some(reference_id), _ -> {
              preprocessor.PreProcessedReference(
                topic_id: preprocessor.node_id_to_topic_id(
                  reference_id,
                  preprocessor.Solidity,
                ),
                tokens: _,
              )
            }
            option.None, True -> style_tokens(_, class: "global-variable")
            option.None, False -> style_tokens(_, class: "text")
          }

        ElementaryTypeNameExpression(..) -> style_tokens(_, class: "type")

        Literal(kind:, ..) ->
          case kind {
            StringLiteral -> style_tokens(_, class: "string")
            NumberLiteral | BoolLiteral | HexStringLiteral -> style_tokens(
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
  current_line current_line,
  processed processed,
  rest rest,
  style_node_tokens style_node_tokens,
) {
  use <- given.that(
    node.source_map == preprocessor.SourceMap(-1, -1),
    return: fn() { #(total_consumed_count, current_line, processed, rest) },
  )

  let gap_to_consume =
    int.min(node.source_map.start - total_consumed_count, string.length(rest))

  let node_to_consume =
    int.min(
      preprocessor.get_source_map_end(node.source_map) - total_consumed_count,
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
      let node_end = preprocessor.get_source_map_end(node.source_map)
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

  preprocessor.PreProcessedNode(element: styled_line)
}

fn style_tokens(tokens, class class) {
  html.span([attribute.class(class)], [html.text(tokens)])
  |> element.to_string
  |> preprocessor.PreProcessedNode
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

  preprocessor.PreProcessedGapNode(element: styled_gap_tokens, leading_spaces:)
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
      case expression {
        option.Some(expression) ->
          do_linearize_nodes(linearized_nodes, expression)
        option.None -> linearized_nodes
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
    VariableDeclarationNode(type_name:, value:, ..) ->
      [node, ..linearized_nodes]
      |> fn(linearized_nodes) {
        case value {
          option.Some(value) -> do_linearize_nodes(linearized_nodes, value)
          option.None -> linearized_nodes
        }
      }
      |> do_linearize_nodes(type_name)
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
    NewExpression(type_name:, arguments:, ..) ->
      case arguments {
        option.Some(arguments) ->
          do_linearize_nodes_multi(linearized_nodes, arguments)
        option.None -> linearized_nodes
      }
      |> do_linearize_nodes(type_name)
    ArrayTypeName(base_type:, ..) ->
      do_linearize_nodes(linearized_nodes, base_type)
    FunctionCallOptions(options:, expression:, ..) ->
      case expression {
        option.Some(expression) ->
          do_linearize_nodes(linearized_nodes, expression)
        option.None -> linearized_nodes
      }
      |> do_linearize_nodes_multi(options)
    Mapping(key_type:, value_type:, ..) ->
      do_linearize_nodes(linearized_nodes, key_type)
      |> do_linearize_nodes(value_type)
    UsingForDirective(library_name:, type_name:, ..) ->
      do_linearize_nodes(linearized_nodes, library_name)
      |> do_linearize_nodes(type_name)
  }
}

fn do_linearize_nodes_multi(linearized_nodes: List(Node), nodes: List(Node)) {
  list.fold(nodes, linearized_nodes, do_linearize_nodes)
}

pub fn enumerate_declarations(declarations, in ast: AST) {
  list.fold(ast.nodes, declarations, fn(declarations, node) {
    do_enumerate_node_declarations(
      declarations,
      node,
      parent_scope: preprocessor.Scope(
        file: ast.absolute_path,
        contract: option.None,
        member: option.None,
      ),
    )
  })
}

fn do_enumerate_node_declarations(
  declarations: #(
    Int,
    dict.Dict(String, topic.Topic),
    dict.Dict(String, String),
  ),
  node: Node,
  parent_scope parent_scope: preprocessor.Scope,
) {
  case node {
    Node(nodes:, ..) ->
      list.fold(nodes, declarations, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, parent_scope)
      })
    NamedNode(nodes:, ..) ->
      list.fold(nodes, declarations, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, parent_scope)
      })
    ImportDirectiveNode(..) | StructuredDocumentationNode(..) -> declarations
    ContractDefinitionNode(id:, name:, nodes:, contract_kind:, source_map:, ..) -> {
      let children_scope =
        preprocessor.Scope(..parent_scope, contract: option.Some(name))

      let #(signature, calls, errors) = analyze_node_body(node)

      let #(id_acc, declarations, merged_topics) = declarations
      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)
      let declarations = #(
        int.max(id_acc, id + 1),
        dict.insert(
          declarations,
          topic_id,
          topic.SourceDeclaration(
            id:,
            topic_id:,
            name:,
            // The parent of a contract is the file it is defined in
            scope: parent_scope,
            signature:,
            kind: preprocessor.ContractDeclaration(contract_kind),
            source_map:,
            references: [],
            calls:,
            errors:,
          ),
        ),
        merged_topics,
      )

      list.fold(nodes, declarations, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, children_scope)
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
      source_map:,
      ..,
    ) -> {
      let name = case function_kind {
        preprocessor.Function -> name
        preprocessor.Constructor -> "constructor"
        preprocessor.Fallback -> "fallback"
        preprocessor.Receive -> "receive"
      }
      let children_scope =
        preprocessor.Scope(..parent_scope, member: option.Some(name))

      let #(signature, calls, errors) = analyze_node_body(node)

      let #(id_acc, declarations, merged_topics) = declarations
      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)
      let declarations = #(
        int.max(id_acc, id + 1),
        dict.insert(
          declarations,
          topic_id,
          topic.SourceDeclaration(
            id:,
            topic_id:,
            name:,
            scope: parent_scope,
            signature:,
            kind: preprocessor.FunctionDeclaration(function_kind),
            source_map:,
            references: [],
            calls:,
            errors:,
          ),
        ),
        merged_topics,
      )

      let declarations =
        list.fold(nodes, declarations, fn(declarations, node) {
          do_enumerate_node_declarations(declarations, node, children_scope)
        })
        |> do_enumerate_node_declarations(parameters, children_scope)
        |> do_enumerate_node_declarations(return_parameters, children_scope)

      case body {
        Some(body) ->
          do_enumerate_node_declarations(declarations, body, children_scope)
        option.None -> declarations
      }
    }
    ModifierDefinitionNode(
      id:,
      parameters:,
      nodes:,
      body:,
      name:,
      source_map:,
      ..,
    ) -> {
      let children_scope =
        preprocessor.Scope(..parent_scope, member: option.Some(name))

      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)

      let #(signature, calls, errors) = analyze_node_body(node)

      let #(id_acc, declarations, merged_topics) = declarations
      let declarations = #(
        int.max(id_acc, id + 1),
        dict.insert(
          declarations,
          topic_id,
          topic.SourceDeclaration(
            id:,
            topic_id:,
            name:,
            scope: parent_scope,
            signature:,
            kind: preprocessor.ModifierDeclaration,
            source_map:,
            references: [],
            calls:,
            errors:,
          ),
        ),
        merged_topics,
      )

      let declarations =
        list.fold(nodes, declarations, fn(declarations, node) {
          do_enumerate_node_declarations(declarations, node, children_scope)
        })
        |> do_enumerate_node_declarations(parameters, children_scope)

      case body {
        Some(body) ->
          do_enumerate_node_declarations(declarations, body, children_scope)
        option.None -> declarations
      }
    }
    ParameterListNode(parameters:, ..) -> {
      list.fold(parameters, declarations, fn(declarations, parameter) {
        do_enumerate_node_declarations(declarations, parameter, parent_scope)
      })
    }
    ErrorDefinitionNode(id:, name:, nodes:, parameters:, source_map:) -> {
      let childern_scope =
        preprocessor.Scope(..parent_scope, member: option.Some(name))

      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)

      let #(signature, calls, errors) = analyze_node_body(node)

      let #(id_acc, declarations, merged_topics) = declarations
      let declarations = #(
        int.max(id_acc, id + 1),
        dict.insert(
          declarations,
          topic_id,
          topic.SourceDeclaration(
            id:,
            topic_id:,
            name:,
            scope: parent_scope,
            signature:,
            kind: preprocessor.ErrorDeclaration,
            source_map:,
            references: [],
            calls:,
            errors:,
          ),
        ),
        merged_topics,
      )

      list.fold(nodes, declarations, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, childern_scope)
      })
      |> do_enumerate_node_declarations(parameters, childern_scope)
    }
    EventDefinitionNode(id:, name:, nodes:, parameters:, source_map:) -> {
      let childern_scope =
        preprocessor.Scope(..parent_scope, member: option.Some(name))

      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)

      let #(signature, calls, errors) = analyze_node_body(node)

      let #(id_acc, declarations, merged_topics) = declarations
      let declarations = #(
        int.max(id_acc, id + 1),
        dict.insert(
          declarations,
          topic_id,
          topic.SourceDeclaration(
            id:,
            topic_id:,
            name:,
            scope: parent_scope,
            signature:,
            kind: preprocessor.EventDeclaration,
            source_map:,
            references: [],
            calls:,
            errors:,
          ),
        ),
        merged_topics,
      )

      list.fold(nodes, declarations, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, childern_scope)
      })
      |> do_enumerate_node_declarations(parameters, childern_scope)
    }
    VariableDeclarationNode(id:, name:, constant:, source_map:, ..) -> {
      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)

      let #(signature, calls, errors) = analyze_node_body(node)

      let #(id_acc, declarations, merged_topics) = declarations
      #(
        int.max(id_acc, id + 1),
        dict.insert(
          declarations,
          topic_id,
          topic.SourceDeclaration(
            id:,
            topic_id:,
            name:,
            scope: parent_scope,
            signature:,
            kind: case constant {
              True -> preprocessor.ConstantDeclaration
              False -> preprocessor.VariableDeclaration
            },
            source_map:,
            references: [],
            calls:,
            errors:,
          ),
        ),
        merged_topics,
      )
    }
    BlockNode(nodes:, statements:, ..) -> {
      list.fold(nodes, declarations, fn(declarations, node) {
        do_enumerate_node_declarations(declarations, node, parent_scope)
      })
      |> list.fold(statements, _, fn(declarations, statement) {
        do_enumerate_node_declarations(declarations, statement, parent_scope)
      })
    }
    VariableDeclarationStatementNode(declarations: declaration_nodes, ..) ->
      list.fold(declaration_nodes, declarations, fn(declarations, declaration) {
        case declaration {
          Some(declaration) ->
            do_enumerate_node_declarations(
              declarations,
              declaration,
              parent_scope,
            )
          option.None -> declarations
        }
      })
    IfStatementNode(true_body:, false_body:, ..) -> {
      let declarations =
        do_enumerate_node_declarations(declarations, true_body, parent_scope)

      case false_body {
        Some(false_body) ->
          do_enumerate_node_declarations(declarations, false_body, parent_scope)
        option.None -> declarations
      }
    }
    ForStatementNode(initialization_expression:, body:, ..) -> {
      let declarations = case initialization_expression {
        option.Some(init) ->
          do_enumerate_node_declarations(declarations, init, parent_scope)
        option.None -> declarations
      }

      do_enumerate_node_declarations(declarations, body, parent_scope)
    }
    EnumDefinition(id:, name:, members:, nodes:, source_map:) -> {
      let children_scope =
        preprocessor.Scope(..parent_scope, member: option.Some(name))

      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)

      let #(signature, calls, errors) = analyze_node_body(node)

      let #(id_acc, declarations, merged_topics) = declarations
      let declarations = #(
        int.max(id_acc, id + 1),
        dict.insert(
          declarations,
          topic_id,
          topic.SourceDeclaration(
            id:,
            topic_id:,
            name:,
            scope: parent_scope,
            signature:,
            kind: preprocessor.EnumDeclaration,
            source_map:,
            references: [],
            calls:,
            errors:,
          ),
        ),
        merged_topics,
      )

      list.fold(nodes, declarations, fn(declarations, statement) {
        do_enumerate_node_declarations(declarations, statement, children_scope)
      })
      |> list.fold(members, _, fn(declarations, statement) {
        do_enumerate_node_declarations(declarations, statement, children_scope)
      })
    }
    EnumValue(id:, name:, source_map:) -> {
      let #(signature, calls, errors) = analyze_node_body(node)

      let #(id_acc, declarations, merged_topics) = declarations
      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)
      #(
        int.max(id_acc, id + 1),
        dict.insert(
          declarations,
          topic_id,
          topic.SourceDeclaration(
            id:,
            topic_id:,
            name:,
            scope: parent_scope,
            signature:,
            kind: preprocessor.EnumValueDeclaration,
            source_map:,
            references: [],
            calls:,
            errors:,
          ),
        ),
        merged_topics,
      )
    }
    StructDefinition(id:, name:, members:, nodes:, source_map:) -> {
      let children_scope =
        preprocessor.Scope(..parent_scope, member: option.Some(name))

      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)

      let #(signature, calls, errors) = analyze_node_body(node)

      let #(id_acc, declarations, merged_topics) = declarations
      let declarations = #(
        int.max(id_acc, id + 1),
        dict.insert(
          declarations,
          topic_id,
          topic.SourceDeclaration(
            id:,
            topic_id:,
            name:,
            scope: parent_scope,
            signature:,
            kind: preprocessor.StructDeclaration,
            source_map:,
            references: [],
            calls:,
            errors:,
          ),
        ),
        merged_topics,
      )

      list.fold(nodes, declarations, fn(declarations, statement) {
        do_enumerate_node_declarations(declarations, statement, children_scope)
      })
      |> list.fold(members, _, fn(declarations, statement) {
        do_enumerate_node_declarations(declarations, statement, children_scope)
      })
    }

    _ -> declarations
  }
}

pub fn enumerate_references(declarations, in ast: AST) {
  list.fold(ast.nodes, declarations, fn(declarations, node) {
    do_enumerate_node_references(
      declarations,
      node,
      preprocessor.Scope(
        file: ast.absolute_path,
        contract: option.None,
        member: option.None,
      ),
      "",
      preprocessor.AccessReference,
    )
  })
}

fn do_enumerate_node_references(
  declarations,
  node: Node,
  parent_scope: preprocessor.Scope,
  parent_topic_id: String,
  parent_reference_kind: preprocessor.NodeReferenceKind,
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
      do_count_node_references_multi(
        declarations,
        nodes,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )

    ImportDirectiveNode(..)
    | VariableDeclarationNode(..)
    | StructuredDocumentationNode(..)
    | ElementaryTypeNameExpression(..)
    | EnumValue(..)
    | Literal(..) -> declarations

    ContractDefinitionNode(id:, nodes:, base_contracts:, name:, ..) -> {
      let children_scope =
        preprocessor.Scope(..parent_scope, contract: option.Some(name))

      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)

      do_count_node_references_multi(
        declarations,
        nodes,
        children_scope,
        topic_id,
        parent_reference_kind,
      )
      |> do_count_node_references_multi(
        base_contracts,
        children_scope,
        topic_id,
        parent_reference_kind,
      )
    }

    FunctionDefinitionNode(
      id:,
      nodes:,
      parameters:,
      modifiers:,
      return_parameters:,
      body:,
      function_kind:,
      name:,
      ..,
    ) -> {
      let children_scope =
        preprocessor.Scope(
          ..parent_scope,
          member: option.Some(case function_kind {
            preprocessor.Function -> name
            preprocessor.Constructor -> "constructor"
            preprocessor.Fallback -> "fallback"
            preprocessor.Receive -> "receive"
          }),
        )

      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)

      let declarations =
        list.fold(nodes, declarations, fn(declarations, node) {
          do_enumerate_node_references(
            declarations,
            node,
            children_scope,
            topic_id,
            parent_reference_kind,
          )
        })
        |> do_enumerate_node_references(
          parameters,
          children_scope,
          topic_id,
          parent_reference_kind,
        )
        |> do_enumerate_node_references(
          return_parameters,
          children_scope,
          topic_id,
          parent_reference_kind,
        )
        |> do_count_node_references_multi(
          modifiers,
          children_scope,
          topic_id,
          parent_reference_kind,
        )

      case body {
        Some(body) ->
          do_enumerate_node_references(
            declarations,
            body,
            children_scope,
            topic_id,
            parent_reference_kind,
          )
        option.None -> declarations
      }
    }
    ModifierDefinitionNode(id:, nodes:, parameters:, body:, name:, ..) -> {
      let children_scope =
        preprocessor.Scope(..parent_scope, member: option.Some(name))

      let topic_id = preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)

      let declarations =
        do_count_node_references_multi(
          declarations,
          nodes,
          children_scope,
          topic_id,
          parent_reference_kind,
        )
        |> do_enumerate_node_references(
          parameters,
          children_scope,
          topic_id,
          parent_reference_kind,
        )

      case body {
        Some(body) ->
          do_enumerate_node_references(
            declarations,
            body,
            children_scope,
            topic_id,
            parent_reference_kind,
          )
        option.None -> declarations
      }
    }
    BlockNode(nodes:, statements:, ..) -> {
      do_count_node_references_multi(
        declarations,
        nodes,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )
      |> do_count_node_references_multi(
        statements,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )
    }
    ExpressionStatementNode(expression:, ..) ->
      case expression {
        Some(expression) ->
          do_enumerate_node_references(
            declarations,
            expression,
            parent_scope,
            parent_topic_id,
            parent_reference_kind,
          )
        option.None -> declarations
      }
    EmitStatementNode(event_call:, ..) ->
      do_enumerate_node_references(
        declarations,
        event_call,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )

    VariableDeclarationStatementNode(initial_value:, ..) ->
      case initial_value {
        option.Some(initial_value) ->
          do_enumerate_node_references(
            declarations,
            initial_value,
            parent_scope,
            parent_topic_id,
            parent_reference_kind,
          )
        option.None -> declarations
      }
    IfStatementNode(condition:, true_body:, false_body:, ..) -> {
      let declarations =
        do_enumerate_node_references(
          declarations,
          condition,
          parent_scope,
          parent_topic_id,
          parent_reference_kind,
        )
        |> do_enumerate_node_references(
          true_body,
          parent_scope,
          parent_topic_id,
          parent_reference_kind,
        )

      case false_body {
        Some(false_body) ->
          do_enumerate_node_references(
            declarations,
            false_body,
            parent_scope,
            parent_topic_id,
            parent_reference_kind,
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
          do_enumerate_node_references(
            declarations,
            init,
            parent_scope,
            parent_topic_id,
            parent_reference_kind,
          )
        option.None -> declarations
      }
      |> fn(declarations) {
        case condition {
          option.Some(condition) ->
            do_enumerate_node_references(
              declarations,
              condition,
              parent_scope,
              parent_topic_id,
              parent_reference_kind,
            )
          option.None -> declarations
        }
      }
      |> fn(declarations) {
        case loop_expression {
          option.Some(loop) ->
            do_enumerate_node_references(
              declarations,
              loop,
              parent_scope,
              parent_topic_id,
              parent_reference_kind,
            )
          option.None -> declarations
        }
      }
      |> do_enumerate_node_references(
        body,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )
    RevertStatementNode(expression:, ..) ->
      case expression {
        Some(expression) ->
          do_enumerate_node_references(
            declarations,
            expression,
            parent_scope,
            parent_topic_id,
            parent_reference_kind,
          )
        option.None -> declarations
      }

    Expression(expression:, ..) ->
      case expression {
        Some(expression) ->
          do_enumerate_node_references(
            declarations,
            expression,
            parent_scope,
            parent_topic_id,
            parent_reference_kind,
          )
        option.None -> declarations
      }

    Identifier(reference_id:, expression:, ..) ->
      case expression {
        Some(expression) ->
          do_enumerate_node_references(
            declarations,
            expression,
            parent_scope,
            parent_topic_id,
            parent_reference_kind,
          )
        option.None -> declarations
      }
      |> add_reference(
        reference_id,
        preprocessor.Reference(
          parent_topic_id:,
          scope: parent_scope,
          kind: parent_reference_kind,
          source: preprocessor.Solidity,
        ),
      )

    MemberAccess(reference_id:, expression:, ..) ->
      case reference_id {
        option.Some(reference_id) ->
          add_reference(
            declarations,
            reference_id,
            preprocessor.Reference(
              scope: parent_scope,
              parent_topic_id:,
              kind: parent_reference_kind,
              source: preprocessor.Solidity,
            ),
          )
        option.None -> declarations
      }
      |> fn(declarations) {
        case expression {
          Some(expression) ->
            do_enumerate_node_references(
              declarations,
              expression,
              parent_scope,
              parent_topic_id,
              parent_reference_kind,
            )
          option.None -> declarations
        }
      }

    FunctionCall(arguments:, expression:, ..) ->
      case expression {
        Some(expression) ->
          do_enumerate_node_references(
            declarations,
            expression,
            parent_scope,
            parent_topic_id,
            preprocessor.CallReference,
          )
        option.None -> declarations
      }
      |> do_count_node_references_multi(
        arguments,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )
    Assignment(left_hand_side:, right_hand_side:, ..) ->
      do_enumerate_node_references(
        declarations,
        left_hand_side,
        parent_scope,
        parent_topic_id,
        preprocessor.MutationReference,
      )
      |> do_enumerate_node_references(
        right_hand_side,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )

    BinaryOperation(left_expression:, right_expression:, ..) ->
      do_enumerate_node_references(
        declarations,
        left_expression,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )
      |> do_enumerate_node_references(
        right_expression,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )

    UnaryOperation(expression:, ..) ->
      do_enumerate_node_references(
        declarations,
        expression,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )

    IndexAccess(base:, index:, ..) ->
      case index {
        option.Some(index) ->
          do_enumerate_node_references(
            declarations,
            index,
            parent_scope,
            parent_topic_id,
            parent_reference_kind,
          )
        option.None -> declarations
      }
      |> do_enumerate_node_references(
        base,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )

    Modifier(reference_id:, arguments:, ..) ->
      add_reference(
        declarations,
        reference_id,
        preprocessor.Reference(
          scope: parent_scope,
          parent_topic_id:,
          kind: preprocessor.CallReference,
          source: preprocessor.Solidity,
        ),
      )
      |> fn(declarations) {
        case arguments {
          Some(arguments) ->
            do_count_node_references_multi(
              declarations,
              arguments,
              parent_scope,
              parent_topic_id,
              parent_reference_kind,
            )
          option.None -> declarations
        }
      }
    IdentifierPath(reference_id:, ..) ->
      add_reference(
        declarations,
        reference_id,
        preprocessor.Reference(
          scope: parent_scope,
          parent_topic_id:,
          kind: parent_reference_kind,
          source: preprocessor.Solidity,
        ),
      )
    BaseContract(reference_id:, ..) ->
      add_reference(
        declarations,
        reference_id,
        preprocessor.Reference(
          scope: parent_scope,
          parent_topic_id:,
          kind: preprocessor.InheritanceReference,
          source: preprocessor.Solidity,
        ),
      )
    Conditional(condition:, true_expression:, false_expression:, ..) ->
      do_enumerate_node_references(
        declarations,
        condition,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )
      |> do_enumerate_node_references(
        true_expression,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )
      |> do_enumerate_node_references(
        false_expression,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )
    UserDefinedTypeName(path_node:, ..) ->
      do_enumerate_node_references(
        declarations,
        path_node,
        parent_scope,
        parent_topic_id,
        preprocessor.TypeReference,
      )
    NewExpression(type_name:, arguments:, ..) ->
      do_enumerate_node_references(
        declarations,
        type_name,
        parent_scope,
        parent_topic_id,
        preprocessor.TypeReference,
      )
      |> fn(declarations) {
        case arguments {
          Some(arguments) ->
            do_count_node_references_multi(
              declarations,
              arguments,
              parent_scope,
              parent_topic_id,
              parent_reference_kind,
            )
          option.None -> declarations
        }
      }
    ArrayTypeName(base_type:, ..) ->
      do_enumerate_node_references(
        declarations,
        base_type,
        parent_scope,
        parent_topic_id,
        preprocessor.TypeReference,
      )
    FunctionCallOptions(options:, expression:, ..) ->
      case expression {
        option.Some(expression) ->
          do_enumerate_node_references(
            declarations,
            expression,
            parent_scope,
            parent_topic_id,
            preprocessor.CallReference,
          )
        option.None -> declarations
      }
      |> do_count_node_references_multi(
        options,
        parent_scope,
        parent_topic_id,
        parent_reference_kind,
      )
    Mapping(key_type:, value_type:, ..) ->
      do_enumerate_node_references(
        declarations,
        key_type,
        parent_scope,
        parent_topic_id,
        preprocessor.TypeReference,
      )
      |> do_enumerate_node_references(
        value_type,
        parent_scope,
        parent_topic_id,
        preprocessor.TypeReference,
      )
    UsingForDirective(library_name:, ..) ->
      do_enumerate_node_references(
        declarations,
        library_name,
        parent_scope,
        parent_topic_id,
        preprocessor.UsingReference,
      )
  }
}

fn add_reference(
  declarations,
  declaration_id: Int,
  reference: preprocessor.Reference,
) {
  dict.upsert(
    declarations,
    preprocessor.node_id_to_topic_id(declaration_id, preprocessor.Solidity),
    with: fn(dec) {
      case dec {
        Some(topic.SourceDeclaration(..) as node_declaration) ->
          topic.SourceDeclaration(..node_declaration, references: [
            reference,
            ..node_declaration.references
          ])

        _ -> {
          io.println(
            "No declaration for "
            <> int.to_string(declaration_id)
            <> " found, there is an issue with finding all declarations",
          )
          topic.Unknown(topic_id: preprocessor.node_id_to_topic_id(
            declaration_id,
            preprocessor.Solidity,
          ))
        }
      }
    },
  )
}

fn do_count_node_references_multi(
  declarations,
  nodes: List(Node),
  parent_scope,
  parent_topic_id: String,
  parent_reference_kind: preprocessor.NodeReferenceKind,
) {
  list.fold(nodes, declarations, fn(declarations, node) {
    do_enumerate_node_references(
      declarations,
      node,
      parent_scope,
      parent_topic_id,
      parent_reference_kind,
    )
  })
}

pub fn enumerate_errors(declarations: dict.Dict(String, topic.Topic)) {
  list.fold(dict.values(declarations), declarations, fn(declarations, dec) {
    let all_errors = case dec {
      topic.SourceDeclaration(calls: [_, ..] as calls, errors:, ..) -> {
        list.fold(calls, errors, fn(errors, call) {
          case dict.get(declarations, call) {
            Ok(topic.SourceDeclaration(errors: new_errors, ..)) ->
              list.append(new_errors, errors)
            _ -> errors
          }
        })
      }
      topic.SourceDeclaration(calls: [], errors:, ..) -> errors
      _ -> []
    }

    case all_errors {
      [] -> declarations
      _ -> {
        let error_signature =
          [
            preprocessor.PreProcessedNode(
              element: html.span([attribute.class("keyword")], [
                html.text("reverts"),
              ])
              |> element.to_string,
            ),
            preprocessor.PreProcessedNode(" ("),
            preprocessor.FormatterNewline,
            preprocessor.FormatterBlock(
              list.map(all_errors, fn(topic_id) {
                let name =
                  topic.get_topic(declarations, topic_id:)
                  |> topic.topic_name

                preprocessor.PreProcessedReference(topic_id, tokens: name)
              })
              |> list.intersperse(preprocessor.FormatterNewline),
            ),
            preprocessor.PreProcessedNode(")"),
          ]
          |> split_lines(indent_num: 0)

        dict.insert(declarations, dec.topic_id, case dec {
          topic.SourceDeclaration(..) ->
            topic.SourceDeclaration(
              ..dec,
              errors: all_errors,
              signature: dec.signature |> list.append(error_signature),
            )
          _ -> dec
        })
      }
    }
  })
}

type BlockLevel {
  TopLevel
  Nested
}

pub type CalledFunctionKind {
  CalledError
  CalledEvent
  CalledFunction
  CalledConstructor
}

fn analyze_node_body(node) {
  let signature_lines =
    do_node_to_signature_nodes(node, top_level: TopLevel)
    |> split_lines(indent_num: 0)

  case node {
    FunctionDefinitionNode(body: option.Some(body), ..)
    | ModifierDefinitionNode(body: option.Some(body), ..) -> {
      let calls = enumerate_function_calls(body)

      let errors =
        list.filter_map(calls, fn(call) {
          case call {
            #(reference_id, CalledError) -> Ok(reference_id)
            _ -> Error(Nil)
          }
        })

      let other =
        list.filter_map(calls, fn(call) {
          case call {
            #(reference_id, CalledFunction) -> Ok(reference_id)
            #(reference_id, CalledConstructor) -> Ok(reference_id)
            _ -> Error(Nil)
          }
        })

      #(signature_lines, other, errors)
    }
    _ -> #(signature_lines, [], [])
  }
}

fn do_node_to_signature_nodes(node, top_level top_level: BlockLevel) {
  case node {
    ErrorDefinitionNode(id:, name:, parameters:, ..) ->
      [
        preprocessor.PreProcessedNode(
          element: html.span([attribute.class("keyword")], [html.text("error ")])
          |> element.to_string,
        ),
        preprocessor.PreProcessedDeclaration(
          topic_id: preprocessor.node_id_to_topic_id(id, preprocessor.Solidity),
          tokens: name,
        ),
        preprocessor.PreProcessedNode(element: "("),
      ]
      |> list.append(do_node_to_signature_nodes(parameters, top_level: Nested))
      |> list.append([preprocessor.PreProcessedNode(element: ")")])

    StructDefinition(id:, name:, members:, ..) ->
      [
        preprocessor.PreProcessedNode(
          element: html.span([attribute.class("keyword")], [
            html.text("struct "),
          ])
          |> element.to_string,
        ),
        preprocessor.PreProcessedDeclaration(
          topic_id: preprocessor.node_id_to_topic_id(id, preprocessor.Solidity),
          tokens: name,
        ),
        preprocessor.PreProcessedNode(element: " {"),
        preprocessor.FormatterNewline,
      ]
      |> list.append([
        preprocessor.FormatterBlock(
          list.map(members, do_node_to_signature_nodes(_, top_level: Nested))
          |> list.intersperse([
            preprocessor.PreProcessedNode(element: ";"),
            preprocessor.FormatterNewline,
          ])
          |> list.flatten,
        ),
      ])
      |> list.append([preprocessor.PreProcessedNode(element: "}")])

    EnumDefinition(id:, name:, members:, ..) ->
      [
        preprocessor.PreProcessedNode(
          element: html.span([attribute.class("keyword")], [html.text("enum ")])
          |> element.to_string,
        ),
        preprocessor.PreProcessedDeclaration(
          topic_id: preprocessor.node_id_to_topic_id(id, preprocessor.Solidity),
          tokens: name,
        ),
        preprocessor.PreProcessedNode(element: " {"),
        preprocessor.FormatterNewline,
      ]
      |> list.append([
        preprocessor.FormatterBlock(
          list.map(members, do_node_to_signature_nodes(_, top_level: Nested))
          |> list.intersperse([
            preprocessor.PreProcessedNode(element: ","),
            preprocessor.FormatterNewline,
          ])
          |> list.flatten,
        ),
      ])
      |> list.append([preprocessor.PreProcessedNode(element: "}")])

    EnumValue(id:, name:, ..) ->
      case top_level {
        TopLevel -> [
          preprocessor.PreProcessedNode(
            element: html.span([attribute.class("keyword")], [
              html.text("enum value "),
            ])
            |> element.to_string,
          ),
          preprocessor.PreProcessedDeclaration(
            topic_id: preprocessor.node_id_to_topic_id(
              id,
              preprocessor.Solidity,
            ),
            tokens: name,
          ),
        ]
        Nested -> [
          preprocessor.PreProcessedReference(
            topic_id: preprocessor.node_id_to_topic_id(
              id,
              preprocessor.Solidity,
            ),
            tokens: name,
          ),
        ]
      }

    FunctionDefinitionNode(
      id:,
      name:,
      function_kind:,
      parameters:,
      return_parameters:,
      visibility:,
      state_mutability:,
      modifiers:,
      ..,
    ) ->
      case function_kind {
        preprocessor.Function -> [
          preprocessor.PreProcessedNode(
            element: html.span([attribute.class("keyword")], [
              html.text("function "),
            ])
            |> element.to_string,
          ),
          preprocessor.PreProcessedDeclaration(
            topic_id: preprocessor.node_id_to_topic_id(
              id,
              preprocessor.Solidity,
            ),
            tokens: name,
          ),
        ]
        preprocessor.Constructor | preprocessor.Fallback | preprocessor.Receive -> [
          preprocessor.PreProcessedDeclaration(
            topic_id: preprocessor.node_id_to_topic_id(
              id,
              preprocessor.Solidity,
            ),
            tokens: name,
          ),
        ]
      }
      |> list.append([preprocessor.PreProcessedNode(element: "(")])
      |> list.append(do_node_to_signature_nodes(parameters, top_level: Nested))
      |> list.append([
        preprocessor.PreProcessedNode(
          element: element.fragment([
            html.text(") "),
            html.span([attribute.class("keyword")], [
              html.text(visibility <> " "),
            ]),
            html.span([attribute.class("keyword")], [
              html.text(state_mutability),
            ]),
          ])
          |> element.to_string,
        ),
      ])
      |> list.append(case list.length(modifiers) > 0 {
        True ->
          [preprocessor.FormatterNewline]
          |> list.append(
            list.map(modifiers, do_node_to_signature_nodes(_, top_level: Nested))
            |> list.intersperse([preprocessor.FormatterNewline])
            |> list.flatten,
          )
        False -> []
      })
      |> list.append(case return_parameters {
        ParameterListNode(parameters: [_, ..], ..) ->
          [
            preprocessor.PreProcessedNode(
              element: element.fragment([
                html.span([attribute.class("keyword")], [html.text(" returns ")]),
                html.text("("),
              ])
              |> element.to_string,
            ),
          ]
          |> list.append(do_node_to_signature_nodes(return_parameters, Nested))
          |> list.append([preprocessor.PreProcessedNode(element: ")")])
        _ -> []
      })

    ModifierDefinitionNode(id:, name:, parameters:, ..) ->
      [
        preprocessor.PreProcessedNode(
          element: html.span([attribute.class("keyword")], [
            html.text("modifier "),
          ])
          |> element.to_string,
        ),
        preprocessor.PreProcessedDeclaration(
          topic_id: preprocessor.node_id_to_topic_id(id, preprocessor.Solidity),
          tokens: name,
        ),
        preprocessor.PreProcessedNode(element: "("),
      ]
      |> list.append(do_node_to_signature_nodes(parameters, top_level: Nested))
      |> list.append([preprocessor.PreProcessedNode(element: ")")])

    ContractDefinitionNode(id:, name:, contract_kind:, base_contracts:, ..) -> [
      preprocessor.PreProcessedNode(
        element: html.span([attribute.class("keyword")], [
          html.text(preprocessor.contract_kind_to_string(contract_kind) <> " "),
        ])
        |> element.to_string,
      ),
      preprocessor.PreProcessedDeclaration(
        topic_id: preprocessor.node_id_to_topic_id(id, preprocessor.Solidity),
        tokens: name,
      ),
      ..case base_contracts {
        [] -> []
        _ -> [
          preprocessor.PreProcessedNode(
            element: html.span([attribute.class("keyword")], [html.text(" is ")])
            |> element.to_string,
          ),
          ..{
            list.map(base_contracts, do_node_to_signature_nodes(
              _,
              top_level: Nested,
            ))
            |> list.intersperse([preprocessor.PreProcessedNode(element: ", ")])
            |> list.flatten
          }
        ]
      }
    ]

    BaseContract(reference_id:, name:, ..) -> [
      preprocessor.PreProcessedReference(
        topic_id: preprocessor.node_id_to_topic_id(
          reference_id,
          preprocessor.Solidity,
        ),
        tokens: name,
      ),
    ]

    EventDefinitionNode(id:, name:, parameters:, ..) ->
      [
        preprocessor.PreProcessedNode(
          element: html.span([attribute.class("keyword")], [html.text("event ")])
          |> element.to_string,
        ),
        preprocessor.PreProcessedDeclaration(
          topic_id: preprocessor.node_id_to_topic_id(id, preprocessor.Solidity),
          tokens: name,
        ),
        preprocessor.PreProcessedNode(element: "("),
      ]
      |> list.append(do_node_to_signature_nodes(parameters, top_level: Nested))
      |> list.append([preprocessor.PreProcessedNode(element: ")")])

    ParameterListNode(parameters:, ..) ->
      case parameters {
        [] -> []
        _ -> [
          preprocessor.FormatterNewline,
          preprocessor.FormatterBlock(
            list.map(parameters, do_node_to_signature_nodes(
              _,
              top_level: Nested,
            ))
            |> list.intersperse([
              preprocessor.PreProcessedNode(element: ","),
              preprocessor.FormatterNewline,
            ])
            |> list.flatten,
          ),
        ]
      }

    VariableDeclarationNode(
      id:,
      type_string:,
      visibility:,
      mutability:,
      constant:,
      name:,
      value:,
      ..,
    ) -> {
      [
        preprocessor.PreProcessedNode(
          element: element.fragment([
            element.unsafe_raw_html(
              "type",
              "span",
              [],
              style_type_string(type_string),
            ),
            case visibility {
              "internal" -> element.fragment([])
              _ ->
                html.span([attribute.class("keyword")], [
                  html.text(" " <> visibility),
                ])
            },
            case mutability {
              "mutable" -> element.fragment([])
              _ ->
                html.span([attribute.class("keyword")], [
                  html.text(" " <> mutability),
                ])
            },
            html.text(" "),
          ])
          |> element.to_string,
        ),
      ]
      |> list.append([
        {
          let topic_id =
            preprocessor.node_id_to_topic_id(id, preprocessor.Solidity)

          case top_level {
            TopLevel ->
              preprocessor.PreProcessedDeclaration(topic_id:, tokens: name)

            Nested ->
              preprocessor.PreProcessedReference(topic_id:, tokens: name)
          }
        },
      ])
      |> list.append(case constant, value {
        True, option.Some(value) -> [
          preprocessor.PreProcessedNode(
            element: html.span([attribute.class("operator")], [html.text(" = ")])
            |> element.to_string,
          ),
          ..do_node_to_signature_nodes(value, Nested)
        ]

        _, _ -> []
      })
    }

    Literal(kind:, value:, ..) -> [
      preprocessor.PreProcessedNode(
        element: case kind {
          StringLiteral ->
            html.span([attribute.class("string")], [
              html.text("\"" <> value <> "\""),
            ])
          NumberLiteral | BoolLiteral | HexStringLiteral ->
            html.span([attribute.class("number")], [html.text(value)])
        }
        |> element.to_string,
      ),
    ]

    FunctionCall(expression: option.Some(expr), arguments:, ..) ->
      do_node_to_signature_nodes(expr, Nested)
      |> list.append([preprocessor.PreProcessedNode(element: "(")])
      |> list.append(
        list.map(arguments, do_node_to_signature_nodes(_, top_level: Nested))
        |> list.intersperse([preprocessor.PreProcessedNode(element: ", ")])
        |> list.flatten,
      )
      |> list.append([preprocessor.PreProcessedNode(element: ")")])

    Identifier(reference_id:, name:, ..) ->
      case reference_id < 0 {
        True -> [
          preprocessor.PreProcessedNode(
            element: html.span([attribute.class("global-variable")], [
              html.text(name),
            ])
            |> element.to_string,
          ),
        ]
        False -> {
          let topic_id =
            preprocessor.node_id_to_topic_id(
              reference_id,
              preprocessor.Solidity,
            )

          case top_level {
            TopLevel -> [
              preprocessor.PreProcessedDeclaration(topic_id:, tokens: name),
            ]
            Nested -> [
              preprocessor.PreProcessedReference(topic_id:, tokens: name),
            ]
          }
        }
      }

    Modifier(reference_id:, name:, arguments:, ..) ->
      [
        preprocessor.PreProcessedReference(
          topic_id: preprocessor.node_id_to_topic_id(
            reference_id,
            preprocessor.Solidity,
          ),
          tokens: case top_level {
            Nested -> "  " <> name
            TopLevel -> name
          },
        ),
      ]
      |> list.append(case arguments {
        Some(args) ->
          [preprocessor.PreProcessedNode(element: "(")]
          |> list.append(
            list.map(args, do_node_to_signature_nodes(_, top_level: Nested))
            |> list.intersperse([preprocessor.PreProcessedNode(element: ", ")])
            |> list.flatten,
          )
          |> list.append([preprocessor.PreProcessedNode(element: ")")])

        option.None -> []
      })

    _ -> [preprocessor.PreProcessedNode(element: "...")]
  }
}

fn split_lines(nodes, indent_num indent_num) {
  let #(current_line, block_lines) =
    list.fold(nodes, #([], []), fn(acc, node) {
      let #(current_line, block_lines) = acc

      case node {
        preprocessor.FormatterNewline -> {
          let new_line =
            preprocessor.SourceSnippetLine(
              topic_id: get_signature_line_significance(current_line),
              leading_spaces: indent_num,
              elements: list.reverse(current_line),
            )
          #([], [new_line, ..block_lines])
        }
        preprocessor.FormatterBlock(nodes) -> #(
          [],
          list.append(
            split_lines(nodes, indent_num: indent_num + 2) |> list.reverse,
            block_lines,
          ),
        )

        _ -> #([node, ..current_line], block_lines)
      }
    })

  let new_line =
    preprocessor.SourceSnippetLine(
      topic_id: get_signature_line_significance(current_line),
      leading_spaces: indent_num,
      elements: list.reverse(current_line),
    )

  [new_line, ..block_lines]
  |> list.reverse
}

fn get_signature_line_significance(
  line_nodes: List(preprocessor.PreProcessedNode),
) {
  let topic_count =
    list.count(line_nodes, fn(node) {
      case node {
        preprocessor.PreProcessedDeclaration(..)
        | preprocessor.PreProcessedReference(..) -> True
        _ -> False
      }
    })

  case topic_count == 1 {
    True -> {
      let assert Ok(topic_id) =
        list.find_map(line_nodes, fn(node) {
          case node {
            preprocessor.PreProcessedDeclaration(topic_id, ..)
            | preprocessor.PreProcessedReference(topic_id, ..) ->
              Ok(option.Some(topic_id))
            _ -> Error(Nil)
          }
        })
      topic_id
    }
    False -> option.None
  }
}

fn enumerate_function_calls(node) {
  do_enumerate_function_calls([], node, CalledFunction)
}

fn do_enumerate_function_calls(acc, node, kind) {
  case node {
    BlockNode(nodes:, statements:, expression:, ..) ->
      case expression {
        option.Some(expression) ->
          do_enumerate_function_calls(acc, expression, kind)
        option.None -> acc
      }
      |> list.fold(nodes, _, fn(acc, node) {
        do_enumerate_function_calls(acc, node, kind)
      })
      |> list.reverse
      |> list.fold(statements, _, fn(acc, statement) {
        do_enumerate_function_calls(acc, statement, kind)
      })
      |> list.reverse

    IfStatementNode(true_body:, false_body:, ..) -> {
      case false_body {
        option.Some(false_body) ->
          do_enumerate_function_calls(acc, true_body, kind)
          |> do_enumerate_function_calls(false_body, kind)
        option.None -> do_enumerate_function_calls(acc, true_body, kind)
      }
    }

    ForStatementNode(loop_expression: option.Some(loop_expression), ..) ->
      do_enumerate_function_calls(acc, loop_expression, kind)

    RevertStatementNode(expression: option.Some(expression), ..) ->
      do_enumerate_function_calls(acc, expression, CalledError)

    EmitStatementNode(event_call:, ..) ->
      do_enumerate_function_calls(acc, event_call, CalledEvent)

    NewExpression(type_name:, ..) ->
      do_enumerate_function_calls(acc, type_name, CalledConstructor)

    FunctionCall(expression: option.Some(expression), ..) ->
      do_enumerate_function_calls(acc, expression, kind)

    ExpressionStatementNode(expression: option.Some(expression), ..) ->
      do_enumerate_function_calls(acc, expression, kind)

    Expression(expression: option.Some(expression), ..) ->
      do_enumerate_function_calls(acc, expression, kind)

    MemberAccess(expression: option.Some(expression), ..) ->
      do_enumerate_function_calls(acc, expression, kind)

    Identifier(reference_id:, ..) | IdentifierPath(reference_id:, ..) -> [
      #(
        preprocessor.node_id_to_topic_id(reference_id, preprocessor.Solidity),
        kind,
      ),
      ..acc
    ]

    _ -> acc
  }
}

fn style_type_string(typename) {
  let assert Ok(operator_regex) = regexp.from_string("\\=\\>")

  let typename =
    regexp.match_map(operator_regex, typename, fn(match) {
      html.span([attribute.class("operator")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(keyword_regex) =
    regexp.from_string(
      "\\b(constructor|contract|modifier|new|fallback|indexed|override|mapping|immutable|interface|virtual|constant|library|abstract|event|error|require|revert|using|for|emit|function|if|else|returns|return|memory|calldata|public|private|external|view|pure|payable|internal|import|enum|struct|storage|is)\\b",
    )

  let typename =
    regexp.match_map(keyword_regex, typename, fn(match) {
      html.span([attribute.class("keyword")], [html.text(match.content)])
      |> element.to_string
    })

  // A word with a capital letter at the beginning
  let assert Ok(capitalized_word_regex) = regexp.from_string("\\b[A-Z]\\w+\\b")

  let typename =
    regexp.match_map(capitalized_word_regex, typename, fn(match) {
      html.span([attribute.class("contract")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(type_regex) =
    regexp.from_string(
      "\\b(address|bool|bytes|bytes\\d+|string|int|uint|int\\d+|uint\\d+)\\b",
    )

  let typename =
    regexp.match_map(type_regex, typename, fn(match) {
      html.span([attribute.class("type")], [html.text(match.content)])
      |> element.to_string
    })

  typename
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

    json.parse(
      source_file_contents,
      decode.at(["ast"], ast_decoder(audit_name)),
    )
    |> snag.map_error(string.inspect)
    |> snag.context("Failed to parse build file for " <> file_name)
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
  Node(
    id: Int,
    source_map: preprocessor.SourceMap,
    node_type: String,
    nodes: List(Node),
  )
  NamedNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    nodes: List(Node),
  )
  ImportDirectiveNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    file: String,
    absolute_path: String,
  )
  ContractDefinitionNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    contract_kind: preprocessor.ContractKind,
    base_contracts: List(Node),
    nodes: List(Node),
  )
  VariableDeclarationNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    constant: Bool,
    mutability: String,
    visibility: String,
    type_string: String,
    type_name: Node,
    value: option.Option(Node),
  )
  ErrorDefinitionNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    nodes: List(Node),
    parameters: Node,
  )
  EventDefinitionNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    parameters: Node,
    nodes: List(Node),
  )
  FunctionDefinitionNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    function_kind: preprocessor.FunctionKind,
    parameters: Node,
    modifiers: List(Node),
    return_parameters: Node,
    base_functions: List(Int),
    nodes: List(Node),
    body: option.Option(Node),
    documentation: option.Option(Node),
    visibility: String,
    state_mutability: String,
  )
  ModifierDefinitionNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    parameters: Node,
    nodes: List(Node),
    body: option.Option(Node),
    documentation: option.Option(Node),
  )
  ParameterListNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    parameters: List(Node),
  )
  BlockNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    nodes: List(Node),
    statements: List(Node),
    expression: option.Option(Node),
  )
  StructuredDocumentationNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    text: String,
  )
  ExpressionStatementNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    expression: option.Option(Node),
  )
  EmitStatementNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    event_call: Node,
  )
  VariableDeclarationStatementNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    declarations: List(option.Option(Node)),
    initial_value: option.Option(Node),
  )
  IfStatementNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    condition: Node,
    true_body: Node,
    false_body: option.Option(Node),
  )
  ForStatementNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    initialization_expression: option.Option(Node),
    condition: option.Option(Node),
    loop_expression: option.Option(Node),
    body: Node,
  )
  RevertStatementNode(
    id: Int,
    source_map: preprocessor.SourceMap,
    expression: option.Option(Node),
  )
  Expression(
    id: Int,
    source_map: preprocessor.SourceMap,
    expression: option.Option(Node),
  )
  Identifier(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    reference_id: Int,
    expression: option.Option(Node),
  )
  FunctionCall(
    id: Int,
    source_map: preprocessor.SourceMap,
    arguments: List(Node),
    kind: FunctionCallKind,
    expression: option.Option(Node),
  )
  Assignment(
    id: Int,
    source_map: preprocessor.SourceMap,
    left_hand_side: Node,
    right_hand_side: Node,
  )
  BinaryOperation(
    id: Int,
    source_map: preprocessor.SourceMap,
    left_expression: Node,
    right_expression: Node,
    operator: String,
  )
  UnaryOperation(
    id: Int,
    source_map: preprocessor.SourceMap,
    expression: Node,
    operator: String,
  )
  IndexAccess(
    id: Int,
    source_map: preprocessor.SourceMap,
    base: Node,
    index: option.Option(Node),
  )
  Modifier(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    kind: ModifierKind,
    reference_id: Int,
    arguments: option.Option(List(Node)),
  )
  IdentifierPath(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    reference_id: Int,
  )
  BaseContract(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    reference_id: Int,
  )
  TupleExpression(
    id: Int,
    source_map: preprocessor.SourceMap,
    nodes: List(Node),
  )
  ElementaryTypeNameExpression(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
  )
  Literal(
    id: Int,
    source_map: preprocessor.SourceMap,
    kind: LiteralKind,
    value: String,
  )
  MemberAccess(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    is_global_access: Bool,
    reference_id: option.Option(Int),
    expression: option.Option(Node),
  )
  Conditional(
    id: Int,
    source_map: preprocessor.SourceMap,
    condition: Node,
    false_expression: Node,
    true_expression: Node,
  )
  EnumDefinition(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    nodes: List(Node),
    members: List(Node),
  )
  EnumValue(id: Int, source_map: preprocessor.SourceMap, name: String)
  StructDefinition(
    id: Int,
    source_map: preprocessor.SourceMap,
    name: String,
    nodes: List(Node),
    members: List(Node),
  )
  UserDefinedTypeName(
    id: Int,
    source_map: preprocessor.SourceMap,
    path_node: Node,
  )
  ArrayTypeName(id: Int, source_map: preprocessor.SourceMap, base_type: Node)
  NewExpression(
    id: Int,
    source_map: preprocessor.SourceMap,
    type_name: Node,
    arguments: option.Option(List(Node)),
  )
  FunctionCallOptions(
    id: Int,
    source_map: preprocessor.SourceMap,
    expression: option.Option(Node),
    options: List(Node),
  )
  Mapping(
    id: Int,
    source_map: preprocessor.SourceMap,
    key_type: Node,
    value_type: Node,
  )
  UsingForDirective(
    id: Int,
    source_map: preprocessor.SourceMap,
    library_name: Node,
    type_name: Node,
  )
}

fn source_map_from_string(source_map_string) {
  case string.split(source_map_string, on: ":") {
    [start_string, length_string, _] -> {
      let start = int.parse(start_string)
      let length = int.parse(length_string)

      case start, length {
        Ok(start), Ok(length) -> preprocessor.SourceMap(start, length)
        Error(..), _ -> panic as "Failed to parse source map start"
        _, Error(..) -> panic as "Failed to parse source map length"
      }
    }
    _ -> preprocessor.SourceMap(-1, -1)
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
        contract_kind: preprocessor.contract_kind_from_string(contract_kind),
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
      use type_name <- decode.field("typeName", node_decoder())
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
        type_name:,
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
      use base_functions <- decode.optional_field(
        "baseFunctions",
        [],
        decode.list(decode.int),
      )
      use visibility <- decode.field("visibility", decode.string)
      use state_mutability <- decode.field("stateMutability", decode.string)
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
      let function_kind = preprocessor.function_kind_from_string(kind)

      let location = source_map_from_string(src)
      let name_location = source_map_from_string(name_location)

      let #(name, source_map) = case function_kind {
        preprocessor.Constructor -> #(
          "constructor",
          preprocessor.SourceMap(location.start, 11),
        )
        preprocessor.Function -> #(name, name_location)
        preprocessor.Fallback -> #(
          "fallback",
          preprocessor.SourceMap(location.start, 8),
        )
        preprocessor.Receive -> #(
          "receive",
          preprocessor.SourceMap(location.start, 7),
        )
      }

      decode.success(FunctionDefinitionNode(
        id:,
        source_map:,
        name:,
        function_kind:,
        parameters:,
        modifiers:,
        return_parameters:,
        base_functions:,
        nodes:,
        body:,
        documentation:,
        visibility:,
        state_mutability:,
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
      decode.success(FunctionCall(
        id:,
        source_map: source_map_from_string(src),
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
      use components <- decode.field(
        "components",
        decode.list(decode.optional(node_decoder())),
      )
      decode.success(TupleExpression(
        id:,
        source_map: source_map_from_string(src),
        nodes: components
          |> list.filter_map(fn(node) {
            case node {
              option.Some(node) -> Ok(node)
              option.None -> Error(Nil)
            }
          }),
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
      use src <- decode.field("src", decode.string)
      use path_node <- decode.field("pathNode", node_decoder())
      decode.success(UserDefinedTypeName(
        id:,
        source_map: source_map_from_string(src),
        path_node:,
      ))
    }
    "ArrayTypeName" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use base_type <- decode.field("baseType", node_decoder())
      decode.success(ArrayTypeName(
        id:,
        source_map: source_map_from_string(src),
        base_type:,
      ))
    }
    "NewExpression" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use type_name <- decode.field("typeName", node_decoder())
      use arguments <- decode.optional_field(
        "arguments",
        option.None,
        decode.optional(decode.list(node_decoder())),
      )
      decode.success(NewExpression(
        id:,
        source_map: source_map_from_string(src),
        type_name:,
        arguments:,
      ))
    }
    "FunctionCallOptions" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use expression <- decode.optional_field(
        "expression",
        option.None,
        decode.optional(node_decoder()),
      )
      use options <- decode.field("options", decode.list(node_decoder()))
      decode.success(FunctionCallOptions(
        id:,
        source_map: source_map_from_string(src),
        expression:,
        options:,
      ))
    }
    "Mapping" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use key_type <- decode.field("keyType", node_decoder())
      use value_type <- decode.field("valueType", node_decoder())
      decode.success(Mapping(
        id:,
        source_map: source_map_from_string(src),
        key_type:,
        value_type:,
      ))
    }
    "UsingForDirective" -> {
      use id <- decode.field("id", decode.int)
      use src <- decode.field("src", decode.string)
      use library_name <- decode.field("libraryName", node_decoder())
      use type_name <- decode.field("typeName", node_decoder())
      decode.success(UsingForDirective(
        id:,
        source_map: source_map_from_string(src),
        library_name:,
        type_name:,
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
      "\\b(constructor|contract|continue|break|modifier|new|fallback|indexed|override|mapping|immutable|interface|virtual|constant|library|abstract|event|error|require|revert|using|for|emit|function|if|else|returns|return|memory|calldata|public|private|external|view|pure|payable|internal|import|enum|struct|storage|is)\\b",
    )

  let styled_line =
    regexp.match_map(keyword_regex, styled_line, fn(match) {
      html.span([attribute.class("keyword")], [html.text(match.content)])
      |> element.to_string
    })

  // let assert Ok(global_variable_regex) =
  //   regexp.from_string(
  //     "\\b(super|this|msg\\.sender|msg\\.value|tx\\.origin|block\\.timestamp|block\\.chainid)\\b",
  //   )

  // let styled_line =
  //   regexp.match_map(global_variable_regex, styled_line, fn(match) {
  //     html.span([attribute.class("global-variable")], [html.text(match.content)])
  //     |> element.to_string
  //   })

  // A word with a capital letter at the beginning
  // let assert Ok(capitalized_word_regex) = regexp.from_string("\\b[A-Z]\\w+\\b")

  // let styled_line =
  //   regexp.match_map(capitalized_word_regex, styled_line, fn(match) {
  //     html.span([attribute.class("contract")], [html.text(match.content)])
  //     |> element.to_string
  //   })

  // let assert Ok(function_regex) = regexp.from_string("\\b(\\w+)\\(")

  // let styled_line =
  //   regexp.match_map(function_regex, styled_line, fn(match) {
  //     case match.submatches {
  //       [Some(function_name), ..] ->
  //         string.replace(
  //           match.content,
  //           each: function_name,
  //           with: element.to_string(
  //             html.span([attribute.class("function")], [
  //               html.text(function_name),
  //             ]),
  //           ),
  //         )
  //       _ -> line_text
  //     }
  //   })

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
