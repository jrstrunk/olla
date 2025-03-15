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

pub fn process_asts(asts: List(#(String, AST))) {
  list.map(asts, fn(ast_data) {
    let #(source_file, ast) = ast_data

    let imports =
      ast.nodes
      |> list.filter_map(fn(node) {
        case node {
          ImportDirectiveNode(id: _, file:, absolute_path:) -> {
            Ok(#(file, absolute_path))
          }
          _ -> Error(Nil)
        }
      })
      |> dict.from_list

    let contracts =
      ast.nodes
      |> list.filter_map(fn(node) {
        case node {
          ContractDefinitionNode(id: _, name:, contract_kind:, nodes: _) -> {
            Ok(#(
              name,
              audit_metadata.ContractMetaData(
                name:,
                kind: audit_metadata.contract_kind_from_string(contract_kind),
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
      json.parse(source_file_contents, decode.at(["ast"], ast_decoder()))
      |> snag.map_error(string.inspect)
      |> snag.context("Failed to parse build file for " <> file_name),
    )

    #(file_name, ast) |> Ok
  }

  result.all(res)
}

pub type AST {
  AST(absolute_path: String, nodes: List(Node))
}

fn ast_decoder() -> decode.Decoder(AST) {
  use absolute_path <- decode.field("absolutePath", decode.string)
  use nodes <- decode.field("nodes", decode.list(node_decoder()))
  decode.success(AST(absolute_path:, nodes:))
}

pub type Node {
  Node(id: Int, node_type: String, nodes: List(Node))
  ImportDirectiveNode(id: Int, file: String, absolute_path: String)
  ContractDefinitionNode(
    id: Int,
    name: String,
    contract_kind: String,
    nodes: List(Node),
  )
  FunctionDefinitionNode(id: Int, name: String, kind: String, nodes: List(Node))
}

fn node_decoder() -> decode.Decoder(Node) {
  use variant <- decode.field("nodeType", decode.string)
  case variant {
    "ImportDirective" -> {
      use id <- decode.field("id", decode.int)
      use file <- decode.field("file", decode.string)
      use absolute_path <- decode.field("absolutePath", decode.string)
      decode.success(ImportDirectiveNode(id:, file:, absolute_path:))
    }
    "ContractDefinition" -> {
      use id <- decode.field("id", decode.int)
      use name <- decode.field("name", decode.string)
      use contract_kind <- decode.field("contractKind", decode.string)
      use nodes <- decode.field("nodes", decode.list(node_decoder()))
      decode.success(ContractDefinitionNode(id:, name:, contract_kind:, nodes:))
    }
    "FunctionDefinition" -> {
      use id <- decode.field("id", decode.int)
      use name <- decode.field("name", decode.string)
      use kind <- decode.field("kind", decode.string)
      use nodes <- decode.field("nodes", decode.list(node_decoder()))
      decode.success(FunctionDefinitionNode(id:, name:, kind:, nodes:))
    }
    _ -> {
      use id <- decode.field("id", decode.int)
      use node_type <- decode.field("nodeType", decode.string)
      use nodes <- decode.field("nodes", decode.list(node_decoder()))
      decode.success(Node(id:, node_type:, nodes:))
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

    case dict.has_key(file_metadata.contracts, contract_name) {
      True -> Ok(import_path <> "#" <> contract_name)
      False -> Error(Nil)
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
        |> process_import_line(audit_metadata.audit_name, source_file_metadata)
        |> PreprocessedLine
      ContractDefinition ->
        line_text
        |> process_contract_definition_line(
          page_path:,
          audit_metadata:,
          source_file_metadata:,
        )
      LibraryDeclaration -> line_text |> style_code_tokens |> PreprocessedLine
      ConstructorDefinition ->
        line_text |> style_code_tokens |> PreprocessedLine
      FallbackFunctionDefinition ->
        line_text |> style_code_tokens |> PreprocessedLine
      ReceiveFunctionDefinition ->
        line_text |> style_code_tokens |> PreprocessedLine
      FunctionDefinition -> line_text |> style_code_tokens |> PreprocessedLine
      StorageVariableDefinition ->
        line_text |> style_code_tokens |> PreprocessedLine
      EventDefinition -> line_text |> style_code_tokens |> PreprocessedLine
      ErrorDefinition -> line_text |> style_code_tokens |> PreprocessedLine
      StructDefinition -> line_text |> style_code_tokens |> PreprocessedLine
      EnumDefinition -> line_text |> style_code_tokens |> PreprocessedLine
      InterfaceDefinition -> line_text |> style_code_tokens |> PreprocessedLine
      LibraryDefinition -> line_text |> style_code_tokens |> PreprocessedLine
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
    contract_inheritances: List(ExternalReference),
    process_line: fn(element.Element(msg), List(element.Element(msg))) ->
      element.Element(msg),
  )
}

pub type ExternalReference {
  ExternalReference(name: String, id: String)
}

pub type LineSigificance {
  Empty
  Regular
  License
  PragmaDeclaration
  Import
  ContractDefinition
  LibraryDeclaration
  ConstructorDefinition
  FallbackFunctionDefinition
  ReceiveFunctionDefinition
  FunctionDefinition
  StorageVariableDefinition
  EventDefinition
  ErrorDefinition
  StructDefinition
  EnumDefinition
  InterfaceDefinition
  LibraryDefinition
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
    ContractDefinition,
  )
  use <- bool.guard(
    trimmed_line_text |> string.starts_with("using"),
    LibraryDeclaration,
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
    trimmed_line_text |> string.starts_with("interface"),
    InterfaceDefinition,
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
  audit_name: String,
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
          |> result.map(fn(abs_import) {
            "/" <> audit_name <> "/" <> abs_import
          })
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
  line_text line_text,
  audit_metadata audit_metadata,
  source_file_metadata source_file_metadata: audit_metadata.SourceFileMetaData,
) {
  case string.split_once(line_text, " is ") {
    Ok(#(contract_name, contract_inheritance)) -> {
      let contract_name =
        contract_name
        // Remove "contract "
        |> string_drop_start(9)

      let contract_inheritances =
        contract_inheritance
        // Remove " {" 
        |> string_drop_end(2)
        |> string.split(on: ", ")
        |> list.map(fn(inheritance) {
          ExternalReference(
            name: inheritance,
            id: find_contract_id(
              audit_metadata,
              named: inheritance,
              in: dict.values(source_file_metadata.imports),
            )
              |> result.unwrap(""),
          )
        })

      let process_line = fn(contract_discussion, inheritances) {
        element.fragment([
          html.span([attribute.class("keyword")], [html.text("contract ")]),
          html.span(
            [
              attribute.id(contract_name),
              attribute.class("contract contract-definition"),
            ],
            [html.text(contract_name), contract_discussion],
          ),
          html.span([attribute.class("keyword")], [html.text(" is ")]),
          element.fragment(list.intersperse(inheritances, html.text(", "))),
          html.text(" {"),
        ])
      }

      PreprocessedContractDefinition(
        contract_id: page_path <> "#" <> contract_name,
        contract_name:,
        contract_inheritances:,
        process_line:,
      )
    }
    Error(Nil) -> {
      let contract_name =
        line_text
        // Remove "contract "
        |> string_drop_start(9)
        // Remove " {"
        |> string_drop_end(2)

      let process_line = fn(contract_discussion, _inheritances) {
        element.fragment([
          html.span([attribute.class("keyword")], [html.text("contract ")]),
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
        contract_inheritances: [],
        process_line:,
      )
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
