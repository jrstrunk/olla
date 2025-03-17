import filepath
import given
import gleam/bool
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/regexp
import gleam/result
import gleam/string
import lib/enumerate
import lustre/attribute
import lustre/element
import lustre/element/html
import o11a/audit_metadata
import o11a/config
import simplifile
import snag

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

    use build_file <- result.try(
      build_dir
      |> simplifile.read_directory
      |> result.unwrap([])
      |> list.first
      |> result.replace_error(snag.new(
        "Failed to find build file for " <> file_name <> " in " <> out_dir,
      ))
      |> result.map(filepath.join(build_dir, _)),
    )

    use source_file_contents <- result.try(
      simplifile.read(build_file)
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

    #(file_name, ast) |> Ok
  }

  echo "Finished reading asts"

  result.all(res)
}

pub type AST {
  AST(absolute_path: String, nodes: List(Node))
}

fn ast_decoder(for audit_name) -> decode.Decoder(AST) {
  use absolute_path <- decode.field("absolutePath", decode.string)
  use nodes <- decode.field("nodes", decode.list(node_decoder()))
  decode.success(AST(
    absolute_path: filepath.join(audit_name, absolute_path),
    nodes:,
  ))
}

pub type Node {
  Node(id: Int, node_type: String, source_map: SourceMap, nodes: List(Node))
  NamedNode(
    id: Int,
    source_map: SourceMap,
    name: String,
    name_source_map: SourceMap,
    nodes: List(Node),
  )
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
    name_source_map: SourceMap,
    contract_kind: audit_metadata.ContractKind,
    base_contracts: List(BaseContract),
    nodes: List(Node),
  )
  VariableDeclarationNode(
    id: Int,
    source_map: SourceMap,
    name: String,
    name_source_map: SourceMap,
    constant: Bool,
    mutability: String,
    visibility: String,
    type_string: String,
  )
  ErrorDefinitionNode(
    id: Int,
    source_map: SourceMap,
    name: String,
    name_source_map: SourceMap,
    nodes: List(Node),
  )
  EventDefinitionNode(
    id: Int,
    source_map: SourceMap,
    name: String,
    name_source_map: SourceMap,
    parameters: Node,
    nodes: List(Node),
  )
  FunctionDefinitionNode(
    id: Int,
    source_map: SourceMap,
    name: String,
    name_source_map: SourceMap,
    function_kind: audit_metadata.FunctionKind,
    parameters: Node,
    modifiers: List(Modifier),
    return_parameters: Node,
    nodes: List(Node),
    body: option.Option(BlockNode),
    documentation: option.Option(FunctionDocumentation),
  )
  ParameterListNode(id: Int, source_map: SourceMap, parameters: List(Node))
}

pub type SourceMap {
  SourceMap(start: Int, length: Int)
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

pub type BlockNode {
  BlockNode(
    id: Int,
    source_map: SourceMap,
    nodes: List(Node),
    statements: List(StatementNode),
    expression: option.Option(Expression),
  )
}

fn block_node_decoder() -> decode.Decoder(BlockNode) {
  use id <- decode.field("id", decode.int)
  echo id
  use src <- decode.field("src", decode.string)
  use nodes <- decode.optional_field("nodes", [], decode.list(node_decoder()))

  use statements <- decode.optional_field(
    "statements",
    [],
    decode.list(statement_node_decoder()),
  )
  use expression <- decode.optional_field(
    "expression",
    option.None,
    decode.optional(expression_decoder()),
  )
  decode.success(BlockNode(
    id:,
    source_map: source_map_from_string(src),
    nodes:,
    statements:,
    expression:,
  ))
}

pub type FunctionDocumentation {
  FunctionDocumentation(id: Int, source_map: SourceMap, text: String)
}

fn function_documentation_decoder() -> decode.Decoder(FunctionDocumentation) {
  use id <- decode.field("id", decode.int)
  echo id
  use src <- decode.field("src", decode.string)

  use text <- decode.field("text", decode.string)
  decode.success(FunctionDocumentation(
    id:,
    source_map: source_map_from_string(src),
    text:,
  ))
}

fn node_decoder() -> decode.Decoder(Node) {
  use <- decode.recursive
  use variant <- decode.field("nodeType", decode.string)
  case variant {
    "ImportDirective" -> {
      use id <- decode.field("id", decode.int)
      echo id
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
      echo id
      use src <- decode.field("src", decode.string)
      use name <- decode.field("name", decode.string)
      use name_location <- decode.field("nameLocation", decode.string)
      use contract_kind <- decode.field("contractKind", decode.string)
      use abstract <- decode.field("abstract", decode.bool)
      use base_contracts <- decode.field(
        "baseContracts",
        decode.list(base_contract_decoder()),
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
        source_map: source_map_from_string(src),
        name:,
        name_source_map: source_map_from_string(name_location),
        contract_kind: audit_metadata.contract_kind_from_string(contract_kind),
        base_contracts:,
        nodes:,
      ))
    }
    "VariableDeclaration" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use name <- decode.field("name", decode.string)
      use name_location <- decode.field("nameLocation", decode.string)
      use constant <- decode.field("constant", decode.bool)
      use mutability <- decode.field("mutability", decode.string)
      use visibility <- decode.field("visibility", decode.string)
      use type_string <- decode.subfield(
        ["typeDescriptions", "typeString"],
        decode.string,
      )
      decode.success(VariableDeclarationNode(
        id:,
        source_map: source_map_from_string(src),
        name:,
        name_source_map: source_map_from_string(name_location),
        constant:,
        mutability: mutability,
        visibility: visibility,
        type_string:,
      ))
    }
    "ErrorDefinition" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use name <- decode.field("name", decode.string)
      use name_location <- decode.field("nameLocation", decode.string)
      use nodes <- decode.optional_field(
        "nodes",
        [],
        decode.list(node_decoder()),
      )

      decode.success(ErrorDefinitionNode(
        id:,
        source_map: source_map_from_string(src),
        name:,
        name_source_map: source_map_from_string(name_location),
        nodes:,
      ))
    }
    "EventDefinition" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
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
        source_map: source_map_from_string(src),
        name:,
        name_source_map: source_map_from_string(name_location),
        parameters:,
        nodes:,
      ))
    }
    "FunctionDefinition" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use name <- decode.field("name", decode.string)
      use name_location <- decode.field("nameLocation", decode.string)
      use kind <- decode.field("kind", decode.string)
      use parameters <- decode.field("parameters", node_decoder())
      use modifiers <- decode.field(
        "modifiers",
        decode.list(modifier_decoder()),
      )
      use return_parameters <- decode.field("returnParameters", node_decoder())
      use nodes <- decode.optional_field(
        "nodes",
        [],
        decode.list(node_decoder()),
      )
      use body <- decode.optional_field(
        "body",
        option.None,
        decode.optional(block_node_decoder()),
      )
      use documentation <- decode.optional_field(
        "documentation",
        option.None,
        decode.optional(function_documentation_decoder()),
      )
      decode.success(FunctionDefinitionNode(
        id:,
        source_map: source_map_from_string(src),
        name:,
        name_source_map: source_map_from_string(name_location),
        function_kind: audit_metadata.function_kind_from_string(kind),
        parameters:,
        modifiers:,
        return_parameters:,
        nodes:,
        body:,
        documentation:,
      ))
    }
    "ParameterList" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use parameters <- decode.field("parameters", decode.list(node_decoder()))
      decode.success(ParameterListNode(
        id:,
        source_map: source_map_from_string(src),
        parameters:,
      ))
    }
    _ -> {
      use id <- decode.field("id", decode.int)
      echo id
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
      case name, name_location {
        option.Some(name), option.Some(name_location) ->
          decode.success(NamedNode(
            id:,
            source_map: source_map_from_string(src),
            name:,
            name_source_map: source_map_from_string(name_location),
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

pub type StatementNode {
  ExpressionStatementNode(
    id: Int,
    source_map: SourceMap,
    expression: option.Option(Expression),
  )
  EmitStatementNode(
    id: Int,
    source_map: SourceMap,
    expression: option.Option(Expression),
  )
  VariableDeclarationStatementNode(
    id: Int,
    source_map: SourceMap,
    declarations: List(option.Option(Node)),
  )
  IfStatementNode(
    id: Int,
    source_map: SourceMap,
    condition: Expression,
    true_body: BlockNode,
    false_body: option.Option(BlockNode),
  )
  RevertStatementNode(
    id: Int,
    source_map: SourceMap,
    expression: option.Option(Expression),
  )
}

fn statement_node_decoder() -> decode.Decoder(StatementNode) {
  use variant <- decode.field("nodeType", decode.string)
  case variant {
    "EmitStatement" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use expression <- decode.optional_field(
        "expression",
        option.None,
        decode.optional(expression_decoder()),
      )
      decode.success(EmitStatementNode(
        id:,
        source_map: source_map_from_string(src),
        expression:,
      ))
    }
    "VariableDeclarationStatement" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use declarations <- decode.field(
        "declarations",
        decode.list(decode.optional(node_decoder())),
      )
      decode.success(VariableDeclarationStatementNode(
        id:,
        source_map: source_map_from_string(src),
        declarations:,
      ))
    }
    "IfStatement" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use condition <- decode.field("condition", expression_decoder())
      use true_body <- decode.field("trueBody", block_node_decoder())
      use false_body <- decode.optional_field(
        "falseBody",
        option.None,
        decode.optional(block_node_decoder()),
      )
      decode.success(IfStatementNode(
        id:,
        source_map: source_map_from_string(src),
        condition:,
        true_body:,
        false_body:,
      ))
    }
    "RevertStatement" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use expression <- decode.optional_field(
        "errorCall",
        option.None,
        decode.optional(expression_decoder()),
      )
      decode.success(RevertStatementNode(
        id:,
        source_map: source_map_from_string(src),
        expression:,
      ))
    }
    _ -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use expression <- decode.optional_field(
        "expression",
        option.None,
        decode.optional(expression_decoder()),
      )
      decode.success(ExpressionStatementNode(
        id:,
        source_map: source_map_from_string(src),
        expression:,
      ))
    }
  }
}

pub type Expression {
  Expression(
    id: Int,
    source_map: SourceMap,
    expression: option.Option(Expression),
  )
  Identifier(
    id: Int,
    source_map: SourceMap,
    name: String,
    reference_id: Int,
    expression: option.Option(Expression),
  )
  FunctionCall(
    id: Int,
    source_map: SourceMap,
    arguments: List(Expression),
    expression: option.Option(Expression),
  )
  Assignment(
    id: Int,
    source_map: SourceMap,
    left_hand_side: Expression,
    right_hand_side: Expression,
  )
  BinaryOperation(
    id: Int,
    source_map: SourceMap,
    left_expression: Expression,
    right_expression: Expression,
    operator: String,
  )
  UnaryOperation(
    id: Int,
    source_map: SourceMap,
    expression: Expression,
    operator: String,
  )
  IndexAccess(
    id: Int,
    source_map: SourceMap,
    base: Expression,
    index: Expression,
  )
}

fn expression_decoder() -> decode.Decoder(Expression) {
  use <- decode.recursive
  use variant <- decode.field("nodeType", decode.string)
  case variant {
    "FunctionCall" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use arguments <- decode.field(
        "arguments",
        decode.list(expression_decoder()),
      )
      use expression <- decode.optional_field(
        "expression",
        option.None,
        decode.optional(expression_decoder()),
      )
      decode.success(FunctionCall(
        id:,
        source_map: source_map_from_string(src),
        arguments:,
        expression:,
      ))
    }
    "Assignment" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use left_hand_side <- decode.field("leftHandSide", expression_decoder())
      use right_hand_side <- decode.field("rightHandSide", expression_decoder())
      decode.success(Assignment(
        id:,
        source_map: source_map_from_string(src),
        left_hand_side:,
        right_hand_side:,
      ))
    }
    "BinaryOperation" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use left_expression <- decode.field(
        "leftExpression",
        expression_decoder(),
      )
      use right_expression <- decode.field(
        "rightExpression",
        expression_decoder(),
      )
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
      echo id
      use src <- decode.field("src", decode.string)
      use expression <- decode.field("subExpression", expression_decoder())
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
      echo id
      use src <- decode.field("src", decode.string)
      use base <- decode.field("baseExpression", expression_decoder())
      use index <- decode.field("indexExpression", expression_decoder())
      decode.success(IndexAccess(
        id:,
        source_map: source_map_from_string(src),
        base:,
        index:,
      ))
    }
    "Identifier" -> {
      use id <- decode.field("id", decode.int)
      echo id
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
    _ -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use expression <- decode.optional_field(
        "expression",
        option.None,
        decode.optional(expression_decoder()),
      )
      decode.success(Expression(
        id:,
        source_map: source_map_from_string(src),
        expression:,
      ))
    }
  }
}

pub type Modifier {
  BaseContructorSpecifier(
    id: Int,
    source_map: SourceMap,
    name: String,
    name_source_map: SourceMap,
    reference_id: Int,
    arguments: option.Option(List(Expression)),
  )
  ModifierInvocation(
    id: Int,
    source_map: SourceMap,
    name: String,
    name_source_map: SourceMap,
    reference_id: Int,
    arguments: option.Option(List(Expression)),
  )
}

fn modifier_decoder() -> decode.Decoder(Modifier) {
  use variant <- decode.field("kind", decode.string)
  case variant {
    "baseConstructorSpecifier" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use name <- decode.subfield(["modifierName", "name"], decode.string)
      use name_location <- decode.subfield(
        ["modifierName", "src"],
        decode.string,
      )
      use reference_id <- decode.subfield(
        ["modifierName", "referencedDeclaration"],
        decode.int,
      )
      use arguments <- decode.optional_field(
        "arguments",
        option.None,
        decode.optional(decode.list(expression_decoder())),
      )
      decode.success(BaseContructorSpecifier(
        id:,
        source_map: source_map_from_string(src),
        name:,
        name_source_map: source_map_from_string(name_location),
        reference_id:,
        arguments:,
      ))
    }
    "modifierInvocation" -> {
      use id <- decode.field("id", decode.int)
      echo id
      use src <- decode.field("src", decode.string)
      use name <- decode.subfield(["modifierName", "name"], decode.string)
      use name_location <- decode.subfield(
        ["modifierName", "src"],
        decode.string,
      )
      use reference_id <- decode.subfield(
        ["modifierName", "referencedDeclaration"],
        decode.int,
      )
      use arguments <- decode.optional_field(
        "arguments",
        option.None,
        decode.optional(decode.list(expression_decoder())),
      )
      decode.success(ModifierInvocation(
        id:,
        source_map: source_map_from_string(src),
        name:,
        name_source_map: source_map_from_string(name_location),
        reference_id:,
        arguments:,
      ))
    }
    _ -> panic as "Invalid modifier type"
  }
}

pub type BaseContract {
  BaseContract(id: Int, source_map: SourceMap, name: String, reference_id: Int)
}

fn base_contract_decoder() -> decode.Decoder(BaseContract) {
  use id <- decode.field("id", decode.int)
  echo id
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

pub fn preprocess_source(
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
      StructDefinition -> line_text |> style_code_tokens |> PreprocessedLine
      EnumDefinition -> line_text |> style_code_tokens |> PreprocessedLine
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
  StructDefinition
  EnumDefinition
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
    trimmed_line_text |> string.starts_with("struct"),
    StructDefinition,
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("enum"),
    EnumDefinition,
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
      "(?:\\/\\/.*|^\\s*\\/\\*\\*.*|^\\s*\\*.*|^\\s*\\*\\/.*|\\/\\*.*?\\*\\/)",
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
      "\\b(constructor|contract|fallback|override|mapping|immutable|interface|constant|library|abstract|event|error|require|revert|using|for|emit|function|if|else|returns|return|memory|calldata|public|private|external|view|pure|payable|internal|import|enum|struct|storage|is)\\b",
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
      "\\b(address|bool|bytes|string|int|uint|int\\d+|uint\\d+)\\b",
    )

  let styled_line =
    regexp.match_map(type_regex, styled_line, fn(match) {
      html.span([attribute.class("type")], [html.text(match.content)])
      |> element.to_string
    })

  let assert Ok(number_regex) =
    regexp.from_string(
      "(?<!\\w)\\d+(?:[_ \\.]\\d+)*(?:\\s+(?:days|ether|finney|wei))?(?!\\w)",
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
