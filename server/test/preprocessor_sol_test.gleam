import gleam/dict
import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/list
import gleeunit/should
import o11a/server/preprocessor_sol
import simplifile

pub fn style_code_tokens_operator_test() {
  preprocessor_sol.style_code_tokens("if (hi < hello == world) {")
  |> should.equal(
    "<span class=\"keyword\">if</span> (hi <span class=\"operator\">&lt;</span> hello <span class=\"operator\">==</span> world) {",
  )
}

pub fn style_code_tokens_function_definition_test() {
  preprocessor_sol.style_code_tokens("function hello(string memory world) {")
  |> should.equal(
    "<span class=\"keyword\">function</span> <span class=\"function\">hello</span>(<span class=\"type\">string</span> <span class=\"keyword\">memory</span> world) {",
  )
}

pub fn style_code_tokens_comment_test() {
  preprocessor_sol.style_code_tokens("return vr; // hello world")
  |> should.equal(
    "<span class=\"keyword\">return</span> vr; <span class=\"comment\">// hello world</span>",
  )
}

pub fn style_code_tokens_contract_test() {
  preprocessor_sol.style_code_tokens("using SafeERC20 for IERC20;")
  |> should.equal(
    "<span class=\"keyword\">using</span> <span class=\"contract\">SafeERC20</span> <span class=\"keyword\">for</span> <span class=\"contract\">IERC20</span>;",
  )
}

pub fn style_code_tokens_number_test() {
  preprocessor_sol.style_code_tokens("uint256 hello = 10;")
  |> should.equal(
    "<span class=\"type\">uint256</span> hello <span class=\"operator\">=</span> <span class=\"number\">10</span>;",
  )
}

pub fn consume_line_over_test() {
  preprocessor_sol.consume_line("hello world", for: 12)
  |> should.equal(#("hello world", 11, "", False))
}

pub fn consume_line_under_test() {
  preprocessor_sol.consume_line("hello world", for: 5)
  |> should.equal(#("hello", 5, " world", False))
}

pub fn consume_line_newline_test() {
  preprocessor_sol.consume_line("hello\nworld\nagain", for: 20)
  |> should.equal(#("hello", 6, "world\nagain", True))
}

pub fn consume_only_newline_test() {
  preprocessor_sol.consume_line("\n", for: 1)
  |> should.equal(#("", 1, "", True))
}

pub fn preprocess_source_test() {
  let assert Ok(src_ast) =
    simplifile.read("priv/audits/thorwallet/out/Titn.sol/Titn.json")
  let assert Ok(ast) =
    json.parse(
      src_ast,
      decode.at(["ast"], preprocessor_sol.ast_decoder("thorwallet")),
    )

  let nodes = preprocessor_sol.linearize_nodes(ast)

  preprocessor_sol.preprocess_source2(src, nodes, dict.new())
  |> list.map(io.debug)
}

const src = "// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from \"@openzeppelin/contracts/access/Ownable.sol\";
import {OFT} from \"@layerzerolabs/oft-evm/contracts/OFT.sol\";

contract Titn is OFT {
    // Bridged token holder may have transfer restricted
    mapping(address => bool) public isBridgedTokenHolder;
    bool private isBridgedTokensTransferLocked;
    address public transferAllowedContract;
    address private lzEndpoint;

    error BridgedTokensTransferLocked();

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate,
        uint256 initialMintAmount
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_delegate) {
        _mint(msg.sender, initialMintAmount);
        lzEndpoint = _lzEndpoint;
        isBridgedTokensTransferLocked = true;
    }

    //////////////////////////////
    //  External owner setters  //
    //////////////////////////////

    event TransferAllowedContractUpdated(address indexed transferAllowedContract);
    function setTransferAllowedContract(address _transferAllowedContract) external onlyOwner {
        transferAllowedContract = _transferAllowedContract;
        emit TransferAllowedContractUpdated(_transferAllowedContract);
    }

    function getTransferAllowedContract() external view returns (address) {
        return transferAllowedContract;
    }

    event BridgedTokenTransferLockUpdated(bool isLocked);
    function setBridgedTokenTransferLocked(bool _isLocked) external onlyOwner {
        isBridgedTokensTransferLocked = _isLocked;
        emit BridgedTokenTransferLockUpdated(_isLocked);
    }

    function getBridgedTokenTransferLocked() external view returns (bool) {
        return isBridgedTokensTransferLocked;
    }

    //////////////////////////////
    //         Overrides        //
    //////////////////////////////

    function transfer(address to, uint256 amount) public override returns (bool) {
        _validateTransfer(msg.sender, to);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _validateTransfer(from, to);
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Validates transfer restrictions.
     * @param from The sender's address.
     * @param to The recipient's address.
     */
    function _validateTransfer(address from, address to) internal view {
        // Arbitrum chain ID
        uint256 arbitrumChainId = 42161;

        // Check if the transfer is restricted
        if (
            from != owner() && // Exclude owner from restrictions
            from != transferAllowedContract && // Allow transfers to the transferAllowedContract
            to != transferAllowedContract && // Allow transfers to the transferAllowedContract
            isBridgedTokensTransferLocked && // Check if bridged transfers are locked
            // Restrict bridged token holders OR apply Arbitrum-specific restriction
            (isBridgedTokenHolder[from] || block.chainid == arbitrumChainId) &&
            to != lzEndpoint // Allow transfers to LayerZero endpoint
        ) {
            revert BridgedTokensTransferLocked();
        }
    }

    /**
     * @dev Credits tokens to the specified address.
     * @param _to The address to credit the tokens to.
     * @param _amountLD The amount of tokens to credit in local decimals.
     * @dev _srcEid The source chain ID.
     * @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
     */
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal virtual override returns (uint256 amountReceivedLD) {
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        // Default OFT mints on dst.
        _mint(_to, _amountLD);

        // Addresses that bridged tokens have some transfer restrictions
        if (!isBridgedTokenHolder[_to]) {
            isBridgedTokenHolder[_to] = true;
        }

        // In the case of NON-default OFT, the _amountLD MIGHT not be == amountReceivedLD.
        return _amountLD;
    }
}"

const ast = "{
\"ast\": {
  \"absolutePath\": \"contracts/Titn.sol\",
  \"id\": 884,
  \"exportedSymbols\": {
    \"OFT\": [
      3753
    ],
    \"Ownable\": [
      4997
    ],
    \"Titn\": [
      883
    ]
  },
  \"nodeType\": \"SourceUnit\",
  \"src\": \"32:4207:1\",
  \"nodes\": [
    {
      \"id\": 630,
      \"nodeType\": \"PragmaDirective\",
      \"src\": \"32:24:1\",
      \"nodes\": [],
      \"literals\": [
        \"solidity\",
        \"^\",
        \"0.8\",
        \".22\"
      ]
    },
    {
      \"id\": 632,
      \"nodeType\": \"ImportDirective\",
      \"src\": \"58:67:1\",
      \"nodes\": [],
      \"absolutePath\": \"dependencies/@openzeppelin-contracts-5.2.0/access/Ownable.sol\",
      \"file\": \"@openzeppelin/contracts/access/Ownable.sol\",
      \"nameLocation\": \"-1:-1:-1\",
      \"scope\": 884,
      \"sourceUnit\": 4998,
      \"symbolAliases\": [
        {
          \"foreign\": {
            \"id\": 631,
            \"name\": \"Ownable\",
            \"nodeType\": \"Identifier\",
            \"overloadedDeclarations\": [],
            \"referencedDeclaration\": 4997,
            \"src\": \"66:7:1\",
            \"typeDescriptions\": {}
          },
          \"nameLocation\": \"-1:-1:-1\"
        }
      ],
      \"unitAlias\": \"\"
    },
    {
      \"id\": 634,
      \"nodeType\": \"ImportDirective\",
      \"src\": \"126:61:1\",
      \"nodes\": [],
      \"absolutePath\": \"dependencies/@layerzerolabs-oft-evm-3.1.3/contracts/OFT.sol\",
      \"file\": \"@layerzerolabs/oft-evm/contracts/OFT.sol\",
      \"nameLocation\": \"-1:-1:-1\",
      \"scope\": 884,
      \"sourceUnit\": 3754,
      \"symbolAliases\": [
        {
          \"foreign\": {
            \"id\": 633,
            \"name\": \"OFT\",
            \"nodeType\": \"Identifier\",
            \"overloadedDeclarations\": [],
            \"referencedDeclaration\": 3753,
            \"src\": \"134:3:1\",
            \"typeDescriptions\": {}
          },
          \"nameLocation\": \"-1:-1:-1\"
        }
      ],
      \"unitAlias\": \"\"
    },
    {
      \"id\": 883,
      \"nodeType\": \"ContractDefinition\",
      \"src\": \"189:4049:1\",
      \"nodes\": [
        {
          \"id\": 640,
          \"nodeType\": \"VariableDeclaration\",
          \"src\": \"273:52:1\",
          \"nodes\": [],
          \"constant\": false,
          \"functionSelector\": \"6b5fb0d6\",
          \"mutability\": \"mutable\",
          \"name\": \"isBridgedTokenHolder\",
          \"nameLocation\": \"305:20:1\",
          \"scope\": 883,
          \"stateVariable\": true,
          \"storageLocation\": \"default\",
          \"typeDescriptions\": {
            \"typeIdentifier\": \"t_mapping$_t_address_$_t_bool_$\",
            \"typeString\": \"mapping(address => bool)\"
          },
          \"typeName\": {
            \"id\": 639,
            \"keyName\": \"\",
            \"keyNameLocation\": \"-1:-1:-1\",
            \"keyType\": {
              \"id\": 637,
              \"name\": \"address\",
              \"nodeType\": \"ElementaryTypeName\",
              \"src\": \"281:7:1\",
              \"typeDescriptions\": {
                \"typeIdentifier\": \"t_address\",
                \"typeString\": \"address\"
              }
            },
            \"nodeType\": \"Mapping\",
            \"src\": \"273:24:1\",
            \"typeDescriptions\": {
              \"typeIdentifier\": \"t_mapping$_t_address_$_t_bool_$\",
              \"typeString\": \"mapping(address => bool)\"
            },
            \"valueName\": \"\",
            \"valueNameLocation\": \"-1:-1:-1\",
            \"valueType\": {
              \"id\": 638,
              \"name\": \"bool\",
              \"nodeType\": \"ElementaryTypeName\",
              \"src\": \"292:4:1\",
              \"typeDescriptions\": {
                \"typeIdentifier\": \"t_bool\",
                \"typeString\": \"bool\"
              }
            }
          },
          \"visibility\": \"public\"
        },
        {
          \"id\": 642,
          \"nodeType\": \"VariableDeclaration\",
          \"src\": \"331:42:1\",
          \"nodes\": [],
          \"constant\": false,
          \"mutability\": \"mutable\",
          \"name\": \"isBridgedTokensTransferLocked\",
          \"nameLocation\": \"344:29:1\",
          \"scope\": 883,
          \"stateVariable\": true,
          \"storageLocation\": \"default\",
          \"typeDescriptions\": {
            \"typeIdentifier\": \"t_bool\",
            \"typeString\": \"bool\"
          },
          \"typeName\": {
            \"id\": 641,
            \"name\": \"bool\",
            \"nodeType\": \"ElementaryTypeName\",
            \"src\": \"331:4:1\",
            \"typeDescriptions\": {
              \"typeIdentifier\": \"t_bool\",
              \"typeString\": \"bool\"
            }
          },
          \"visibility\": \"private\"
        },
        {
          \"id\": 644,
          \"nodeType\": \"VariableDeclaration\",
          \"src\": \"379:38:1\",
          \"nodes\": [],
          \"constant\": false,
          \"functionSelector\": \"0ab454d7\",
          \"mutability\": \"mutable\",
          \"name\": \"transferAllowedContract\",
          \"nameLocation\": \"394:23:1\",
          \"scope\": 883,
          \"stateVariable\": true,
          \"storageLocation\": \"default\",
          \"typeDescriptions\": {
            \"typeIdentifier\": \"t_address\",
            \"typeString\": \"address\"
          },
          \"typeName\": {
            \"id\": 643,
            \"name\": \"address\",
            \"nodeType\": \"ElementaryTypeName\",
            \"src\": \"379:7:1\",
            \"stateMutability\": \"nonpayable\",
            \"typeDescriptions\": {
              \"typeIdentifier\": \"t_address\",
              \"typeString\": \"address\"
            }
          },
          \"visibility\": \"public\"
        },
        {
          \"id\": 646,
          \"nodeType\": \"VariableDeclaration\",
          \"src\": \"423:26:1\",
          \"nodes\": [],
          \"constant\": false,
          \"mutability\": \"mutable\",
          \"name\": \"lzEndpoint\",
          \"nameLocation\": \"439:10:1\",
          \"scope\": 883,
          \"stateVariable\": true,
          \"storageLocation\": \"default\",
          \"typeDescriptions\": {
            \"typeIdentifier\": \"t_address\",
            \"typeString\": \"address\"
          },
          \"typeName\": {
            \"id\": 645,
            \"name\": \"address\",
            \"nodeType\": \"ElementaryTypeName\",
            \"src\": \"423:7:1\",
            \"stateMutability\": \"nonpayable\",
            \"typeDescriptions\": {
              \"typeIdentifier\": \"t_address\",
              \"typeString\": \"address\"
            }
          },
          \"visibility\": \"private\"
        },
        {
          \"id\": 648,
          \"nodeType\": \"ErrorDefinition\",
          \"src\": \"456:36:1\",
          \"nodes\": [],
          \"errorSelector\": \"9d83e48e\",
          \"name\": \"BridgedTokensTransferLocked\",
          \"nameLocation\": \"462:27:1\",
          \"parameters\": {
            \"id\": 647,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [],
            \"src\": \"489:2:1\"
          }
        },
        {
          \"id\": 685,
          \"nodeType\": \"FunctionDefinition\",
          \"src\": \"498:365:1\",
          \"nodes\": [],
          \"body\": {
            \"id\": 684,
            \"nodeType\": \"Block\",
            \"src\": \"730:133:1\",
            \"nodes\": [],
            \"statements\": [
              {
                \"expression\": {
                  \"arguments\": [
                    {
                      \"expression\": {
                        \"id\": 671,
                        \"name\": \"msg\",
                        \"nodeType\": \"Identifier\",
                        \"overloadedDeclarations\": [],
                        \"referencedDeclaration\": -15,
                        \"src\": \"746:3:1\",
                        \"typeDescriptions\": {
                          \"typeIdentifier\": \"t_magic_message\",
                          \"typeString\": \"msg\"
                        }
                      },
                      \"id\": 672,
                      \"isConstant\": false,
                      \"isLValue\": false,
                      \"isPure\": false,
                      \"lValueRequested\": false,
                      \"memberLocation\": \"750:6:1\",
                      \"memberName\": \"sender\",
                      \"nodeType\": \"MemberAccess\",
                      \"src\": \"746:10:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    {
                      \"id\": 673,
                      \"name\": \"initialMintAmount\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 658,
                      \"src\": \"758:17:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_uint256\",
                        \"typeString\": \"uint256\"
                      }
                    }
                  ],
                  \"expression\": {
                    \"argumentTypes\": [
                      {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      },
                      {
                        \"typeIdentifier\": \"t_uint256\",
                        \"typeString\": \"uint256\"
                      }
                    ],
                    \"id\": 670,
                    \"name\": \"_mint\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 5579,
                    \"src\": \"740:5:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_function_internal_nonpayable$_t_address_$_t_uint256_$returns$__$\",
                      \"typeString\": \"function (address,uint256)\"
                    }
                  },
                  \"id\": 674,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"kind\": \"functionCall\",
                  \"lValueRequested\": false,
                  \"nameLocations\": [],
                  \"names\": [],
                  \"nodeType\": \"FunctionCall\",
                  \"src\": \"740:36:1\",
                  \"tryCall\": false,
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_tuple$__$\",
                    \"typeString\": \"tuple()\"
                  }
                },
                \"id\": 675,
                \"nodeType\": \"ExpressionStatement\",
                \"src\": \"740:36:1\"
              },
              {
                \"expression\": {
                  \"id\": 678,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"lValueRequested\": false,
                  \"leftHandSide\": {
                    \"id\": 676,
                    \"name\": \"lzEndpoint\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 646,
                    \"src\": \"786:10:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_address\",
                      \"typeString\": \"address\"
                    }
                  },
                  \"nodeType\": \"Assignment\",
                  \"operator\": \"=\",
                  \"rightHandSide\": {
                    \"id\": 677,
                    \"name\": \"_lzEndpoint\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 654,
                    \"src\": \"799:11:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_address\",
                      \"typeString\": \"address\"
                    }
                  },
                  \"src\": \"786:24:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"id\": 679,
                \"nodeType\": \"ExpressionStatement\",
                \"src\": \"786:24:1\"
              },
              {
                \"expression\": {
                  \"id\": 682,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"lValueRequested\": false,
                  \"leftHandSide\": {
                    \"id\": 680,
                    \"name\": \"isBridgedTokensTransferLocked\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 642,
                    \"src\": \"820:29:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_bool\",
                      \"typeString\": \"bool\"
                    }
                  },
                  \"nodeType\": \"Assignment\",
                  \"operator\": \"=\",
                  \"rightHandSide\": {
                    \"hexValue\": \"74727565\",
                    \"id\": 681,
                    \"isConstant\": false,
                    \"isLValue\": false,
                    \"isPure\": true,
                    \"kind\": \"bool\",
                    \"lValueRequested\": false,
                    \"nodeType\": \"Literal\",
                    \"src\": \"852:4:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_bool\",
                      \"typeString\": \"bool\"
                    },
                    \"value\": \"true\"
                  },
                  \"src\": \"820:36:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"id\": 683,
                \"nodeType\": \"ExpressionStatement\",
                \"src\": \"820:36:1\"
              }
            ]
          },
          \"implemented\": true,
          \"kind\": \"constructor\",
          \"modifiers\": [
            {
              \"arguments\": [
                {
                  \"id\": 661,
                  \"name\": \"_name\",
                  \"nodeType\": \"Identifier\",
                  \"overloadedDeclarations\": [],
                  \"referencedDeclaration\": 650,
                  \"src\": \"671:5:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_string_memory_ptr\",
                    \"typeString\": \"string memory\"
                  }
                },
                {
                  \"id\": 662,
                  \"name\": \"_symbol\",
                  \"nodeType\": \"Identifier\",
                  \"overloadedDeclarations\": [],
                  \"referencedDeclaration\": 652,
                  \"src\": \"678:7:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_string_memory_ptr\",
                    \"typeString\": \"string memory\"
                  }
                },
                {
                  \"id\": 663,
                  \"name\": \"_lzEndpoint\",
                  \"nodeType\": \"Identifier\",
                  \"overloadedDeclarations\": [],
                  \"referencedDeclaration\": 654,
                  \"src\": \"687:11:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                {
                  \"id\": 664,
                  \"name\": \"_delegate\",
                  \"nodeType\": \"Identifier\",
                  \"overloadedDeclarations\": [],
                  \"referencedDeclaration\": 656,
                  \"src\": \"700:9:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                }
              ],
              \"id\": 665,
              \"kind\": \"baseConstructorSpecifier\",
              \"modifierName\": {
                \"id\": 660,
                \"name\": \"OFT\",
                \"nameLocations\": [
                  \"667:3:1\"
                ],
                \"nodeType\": \"IdentifierPath\",
                \"referencedDeclaration\": 3753,
                \"src\": \"667:3:1\"
              },
              \"nodeType\": \"ModifierInvocation\",
              \"src\": \"667:43:1\"
            },
            {
              \"arguments\": [
                {
                  \"id\": 667,
                  \"name\": \"_delegate\",
                  \"nodeType\": \"Identifier\",
                  \"overloadedDeclarations\": [],
                  \"referencedDeclaration\": 656,
                  \"src\": \"719:9:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                }
              ],
              \"id\": 668,
              \"kind\": \"baseConstructorSpecifier\",
              \"modifierName\": {
                \"id\": 666,
                \"name\": \"Ownable\",
                \"nameLocations\": [
                  \"711:7:1\"
                ],
                \"nodeType\": \"IdentifierPath\",
                \"referencedDeclaration\": 4997,
                \"src\": \"711:7:1\"
              },
              \"nodeType\": \"ModifierInvocation\",
              \"src\": \"711:18:1\"
            }
          ],
          \"name\": \"\",
          \"nameLocation\": \"-1:-1:-1\",
          \"parameters\": {
            \"id\": 659,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 650,
                \"mutability\": \"mutable\",
                \"name\": \"_name\",
                \"nameLocation\": \"533:5:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 685,
                \"src\": \"519:19:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"memory\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_string_memory_ptr\",
                  \"typeString\": \"string\"
                },
                \"typeName\": {
                  \"id\": 649,
                  \"name\": \"string\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"519:6:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_string_storage_ptr\",
                    \"typeString\": \"string\"
                  }
                },
                \"visibility\": \"internal\"
              },
              {
                \"constant\": false,
                \"id\": 652,
                \"mutability\": \"mutable\",
                \"name\": \"_symbol\",
                \"nameLocation\": \"562:7:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 685,
                \"src\": \"548:21:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"memory\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_string_memory_ptr\",
                  \"typeString\": \"string\"
                },
                \"typeName\": {
                  \"id\": 651,
                  \"name\": \"string\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"548:6:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_string_storage_ptr\",
                    \"typeString\": \"string\"
                  }
                },
                \"visibility\": \"internal\"
              },
              {
                \"constant\": false,
                \"id\": 654,
                \"mutability\": \"mutable\",
                \"name\": \"_lzEndpoint\",
                \"nameLocation\": \"587:11:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 685,
                \"src\": \"579:19:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_address\",
                  \"typeString\": \"address\"
                },
                \"typeName\": {
                  \"id\": 653,
                  \"name\": \"address\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"579:7:1\",
                  \"stateMutability\": \"nonpayable\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"visibility\": \"internal\"
              },
              {
                \"constant\": false,
                \"id\": 656,
                \"mutability\": \"mutable\",
                \"name\": \"_delegate\",
                \"nameLocation\": \"616:9:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 685,
                \"src\": \"608:17:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_address\",
                  \"typeString\": \"address\"
                },
                \"typeName\": {
                  \"id\": 655,
                  \"name\": \"address\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"608:7:1\",
                  \"stateMutability\": \"nonpayable\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"visibility\": \"internal\"
              },
              {
                \"constant\": false,
                \"id\": 658,
                \"mutability\": \"mutable\",
                \"name\": \"initialMintAmount\",
                \"nameLocation\": \"643:17:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 685,
                \"src\": \"635:25:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_uint256\",
                  \"typeString\": \"uint256\"
                },
                \"typeName\": {
                  \"id\": 657,
                  \"name\": \"uint256\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"635:7:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_uint256\",
                    \"typeString\": \"uint256\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"509:157:1\"
          },
          \"returnParameters\": {
            \"id\": 669,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [],
            \"src\": \"730:0:1\"
          },
          \"scope\": 883,
          \"stateMutability\": \"nonpayable\",
          \"virtual\": false,
          \"visibility\": \"public\"
        },
        {
          \"id\": 689,
          \"nodeType\": \"EventDefinition\",
          \"src\": \"975:78:1\",
          \"nodes\": [],
          \"anonymous\": false,
          \"eventSelector\": \"252edac38144d9c2befa344dd080eea9a8f68a1e64efd4b4b1d42ff99953054d\",
          \"name\": \"TransferAllowedContractUpdated\",
          \"nameLocation\": \"981:30:1\",
          \"parameters\": {
            \"id\": 688,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 687,
                \"indexed\": true,
                \"mutability\": \"mutable\",
                \"name\": \"transferAllowedContract\",
                \"nameLocation\": \"1028:23:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 689,
                \"src\": \"1012:39:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_address\",
                  \"typeString\": \"address\"
                },
                \"typeName\": {
                  \"id\": 686,
                  \"name\": \"address\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"1012:7:1\",
                  \"stateMutability\": \"nonpayable\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"1011:41:1\"
          }
        },
        {
          \"id\": 705,
          \"nodeType\": \"FunctionDefinition\",
          \"src\": \"1058:227:1\",
          \"nodes\": [],
          \"body\": {
            \"id\": 704,
            \"nodeType\": \"Block\",
            \"src\": \"1147:138:1\",
            \"nodes\": [],
            \"statements\": [
              {
                \"expression\": {
                  \"id\": 698,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"lValueRequested\": false,
                  \"leftHandSide\": {
                    \"id\": 696,
                    \"name\": \"transferAllowedContract\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 644,
                    \"src\": \"1157:23:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_address\",
                      \"typeString\": \"address\"
                    }
                  },
                  \"nodeType\": \"Assignment\",
                  \"operator\": \"=\",
                  \"rightHandSide\": {
                    \"id\": 697,
                    \"name\": \"_transferAllowedContract\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 691,
                    \"src\": \"1183:24:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_address\",
                      \"typeString\": \"address\"
                    }
                  },
                  \"src\": \"1157:50:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"id\": 699,
                \"nodeType\": \"ExpressionStatement\",
                \"src\": \"1157:50:1\"
              },
              {
                \"eventCall\": {
                  \"arguments\": [
                    {
                      \"id\": 701,
                      \"name\": \"_transferAllowedContract\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 691,
                      \"src\": \"1253:24:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    }
                  ],
                  \"expression\": {
                    \"argumentTypes\": [
                      {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    ],
                    \"id\": 700,
                    \"name\": \"TransferAllowedContractUpdated\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 689,
                    \"src\": \"1222:30:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_function_event_nonpayable$_t_address_$returns$__$\",
                      \"typeString\": \"function (address)\"
                    }
                  },
                  \"id\": 702,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"kind\": \"functionCall\",
                  \"lValueRequested\": false,
                  \"nameLocations\": [],
                  \"names\": [],
                  \"nodeType\": \"FunctionCall\",
                  \"src\": \"1222:56:1\",
                  \"tryCall\": false,
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_tuple$__$\",
                    \"typeString\": \"tuple()\"
                  }
                },
                \"id\": 703,
                \"nodeType\": \"EmitStatement\",
                \"src\": \"1217:61:1\"
              }
            ]
          },
          \"functionSelector\": \"7dad4281\",
          \"implemented\": true,
          \"kind\": \"function\",
          \"modifiers\": [
            {
              \"id\": 694,
              \"kind\": \"modifierInvocation\",
              \"modifierName\": {
                \"id\": 693,
                \"name\": \"onlyOwner\",
                \"nameLocations\": [
                  \"1137:9:1\"
                ],
                \"nodeType\": \"IdentifierPath\",
                \"referencedDeclaration\": 4908,
                \"src\": \"1137:9:1\"
              },
              \"nodeType\": \"ModifierInvocation\",
              \"src\": \"1137:9:1\"
            }
          ],
          \"name\": \"setTransferAllowedContract\",
          \"nameLocation\": \"1067:26:1\",
          \"parameters\": {
            \"id\": 692,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 691,
                \"mutability\": \"mutable\",
                \"name\": \"_transferAllowedContract\",
                \"nameLocation\": \"1102:24:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 705,
                \"src\": \"1094:32:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_address\",
                  \"typeString\": \"address\"
                },
                \"typeName\": {
                  \"id\": 690,
                  \"name\": \"address\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"1094:7:1\",
                  \"stateMutability\": \"nonpayable\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"1093:34:1\"
          },
          \"returnParameters\": {
            \"id\": 695,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [],
            \"src\": \"1147:0:1\"
          },
          \"scope\": 883,
          \"stateMutability\": \"nonpayable\",
          \"virtual\": false,
          \"visibility\": \"external\"
        },
        {
          \"id\": 713,
          \"nodeType\": \"FunctionDefinition\",
          \"src\": \"1291:117:1\",
          \"nodes\": [],
          \"body\": {
            \"id\": 712,
            \"nodeType\": \"Block\",
            \"src\": \"1361:47:1\",
            \"nodes\": [],
            \"statements\": [
              {
                \"expression\": {
                  \"id\": 710,
                  \"name\": \"transferAllowedContract\",
                  \"nodeType\": \"Identifier\",
                  \"overloadedDeclarations\": [],
                  \"referencedDeclaration\": 644,
                  \"src\": \"1378:23:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"functionReturnParameters\": 709,
                \"id\": 711,
                \"nodeType\": \"Return\",
                \"src\": \"1371:30:1\"
              }
            ]
          },
          \"functionSelector\": \"e6aed2ad\",
          \"implemented\": true,
          \"kind\": \"function\",
          \"modifiers\": [],
          \"name\": \"getTransferAllowedContract\",
          \"nameLocation\": \"1300:26:1\",
          \"parameters\": {
            \"id\": 706,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [],
            \"src\": \"1326:2:1\"
          },
          \"returnParameters\": {
            \"id\": 709,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 708,
                \"mutability\": \"mutable\",
                \"name\": \"\",
                \"nameLocation\": \"-1:-1:-1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 713,
                \"src\": \"1352:7:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_address\",
                  \"typeString\": \"address\"
                },
                \"typeName\": {
                  \"id\": 707,
                  \"name\": \"address\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"1352:7:1\",
                  \"stateMutability\": \"nonpayable\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"1351:9:1\"
          },
          \"scope\": 883,
          \"stateMutability\": \"view\",
          \"virtual\": false,
          \"visibility\": \"external\"
        },
        {
          \"id\": 717,
          \"nodeType\": \"EventDefinition\",
          \"src\": \"1414:53:1\",
          \"nodes\": [],
          \"anonymous\": false,
          \"eventSelector\": \"2e6c26903e4eaf4e186a073d1c34c3a6551d5a750461eaeedf0604649dcab540\",
          \"name\": \"BridgedTokenTransferLockUpdated\",
          \"nameLocation\": \"1420:31:1\",
          \"parameters\": {
            \"id\": 716,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 715,
                \"indexed\": false,
                \"mutability\": \"mutable\",
                \"name\": \"isLocked\",
                \"nameLocation\": \"1457:8:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 717,
                \"src\": \"1452:13:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_bool\",
                  \"typeString\": \"bool\"
                },
                \"typeName\": {
                  \"id\": 714,
                  \"name\": \"bool\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"1452:4:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"1451:15:1\"
          }
        },
        {
          \"id\": 733,
          \"nodeType\": \"FunctionDefinition\",
          \"src\": \"1472:189:1\",
          \"nodes\": [],
          \"body\": {
            \"id\": 732,
            \"nodeType\": \"Block\",
            \"src\": \"1546:115:1\",
            \"nodes\": [],
            \"statements\": [
              {
                \"expression\": {
                  \"id\": 726,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"lValueRequested\": false,
                  \"leftHandSide\": {
                    \"id\": 724,
                    \"name\": \"isBridgedTokensTransferLocked\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 642,
                    \"src\": \"1556:29:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_bool\",
                      \"typeString\": \"bool\"
                    }
                  },
                  \"nodeType\": \"Assignment\",
                  \"operator\": \"=\",
                  \"rightHandSide\": {
                    \"id\": 725,
                    \"name\": \"_isLocked\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 719,
                    \"src\": \"1588:9:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_bool\",
                      \"typeString\": \"bool\"
                    }
                  },
                  \"src\": \"1556:41:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"id\": 727,
                \"nodeType\": \"ExpressionStatement\",
                \"src\": \"1556:41:1\"
              },
              {
                \"eventCall\": {
                  \"arguments\": [
                    {
                      \"id\": 729,
                      \"name\": \"_isLocked\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 719,
                      \"src\": \"1644:9:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_bool\",
                        \"typeString\": \"bool\"
                      }
                    }
                  ],
                  \"expression\": {
                    \"argumentTypes\": [
                      {
                        \"typeIdentifier\": \"t_bool\",
                        \"typeString\": \"bool\"
                      }
                    ],
                    \"id\": 728,
                    \"name\": \"BridgedTokenTransferLockUpdated\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 717,
                    \"src\": \"1612:31:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_function_event_nonpayable$_t_bool_$returns$__$\",
                      \"typeString\": \"function (bool)\"
                    }
                  },
                  \"id\": 730,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"kind\": \"functionCall\",
                  \"lValueRequested\": false,
                  \"nameLocations\": [],
                  \"names\": [],
                  \"nodeType\": \"FunctionCall\",
                  \"src\": \"1612:42:1\",
                  \"tryCall\": false,
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_tuple$__$\",
                    \"typeString\": \"tuple()\"
                  }
                },
                \"id\": 731,
                \"nodeType\": \"EmitStatement\",
                \"src\": \"1607:47:1\"
              }
            ]
          },
          \"functionSelector\": \"4910a788\",
          \"implemented\": true,
          \"kind\": \"function\",
          \"modifiers\": [
            {
              \"id\": 722,
              \"kind\": \"modifierInvocation\",
              \"modifierName\": {
                \"id\": 721,
                \"name\": \"onlyOwner\",
                \"nameLocations\": [
                  \"1536:9:1\"
                ],
                \"nodeType\": \"IdentifierPath\",
                \"referencedDeclaration\": 4908,
                \"src\": \"1536:9:1\"
              },
              \"nodeType\": \"ModifierInvocation\",
              \"src\": \"1536:9:1\"
            }
          ],
          \"name\": \"setBridgedTokenTransferLocked\",
          \"nameLocation\": \"1481:29:1\",
          \"parameters\": {
            \"id\": 720,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 719,
                \"mutability\": \"mutable\",
                \"name\": \"_isLocked\",
                \"nameLocation\": \"1516:9:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 733,
                \"src\": \"1511:14:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_bool\",
                  \"typeString\": \"bool\"
                },
                \"typeName\": {
                  \"id\": 718,
                  \"name\": \"bool\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"1511:4:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"1510:16:1\"
          },
          \"returnParameters\": {
            \"id\": 723,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [],
            \"src\": \"1546:0:1\"
          },
          \"scope\": 883,
          \"stateMutability\": \"nonpayable\",
          \"virtual\": false,
          \"visibility\": \"external\"
        },
        {
          \"id\": 741,
          \"nodeType\": \"FunctionDefinition\",
          \"src\": \"1667:123:1\",
          \"nodes\": [],
          \"body\": {
            \"id\": 740,
            \"nodeType\": \"Block\",
            \"src\": \"1737:53:1\",
            \"nodes\": [],
            \"statements\": [
              {
                \"expression\": {
                  \"id\": 738,
                  \"name\": \"isBridgedTokensTransferLocked\",
                  \"nodeType\": \"Identifier\",
                  \"overloadedDeclarations\": [],
                  \"referencedDeclaration\": 642,
                  \"src\": \"1754:29:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"functionReturnParameters\": 737,
                \"id\": 739,
                \"nodeType\": \"Return\",
                \"src\": \"1747:36:1\"
              }
            ]
          },
          \"functionSelector\": \"08e4f3a5\",
          \"implemented\": true,
          \"kind\": \"function\",
          \"modifiers\": [],
          \"name\": \"getBridgedTokenTransferLocked\",
          \"nameLocation\": \"1676:29:1\",
          \"parameters\": {
            \"id\": 734,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [],
            \"src\": \"1705:2:1\"
          },
          \"returnParameters\": {
            \"id\": 737,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 736,
                \"mutability\": \"mutable\",
                \"name\": \"\",
                \"nameLocation\": \"-1:-1:-1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 741,
                \"src\": \"1731:4:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_bool\",
                  \"typeString\": \"bool\"
                },
                \"typeName\": {
                  \"id\": 735,
                  \"name\": \"bool\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"1731:4:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"1730:6:1\"
          },
          \"scope\": 883,
          \"stateMutability\": \"view\",
          \"virtual\": false,
          \"visibility\": \"external\"
        },
        {
          \"id\": 764,
          \"nodeType\": \"FunctionDefinition\",
          \"src\": \"1902:170:1\",
          \"nodes\": [],
          \"body\": {
            \"id\": 763,
            \"nodeType\": \"Block\",
            \"src\": \"1979:93:1\",
            \"nodes\": [],
            \"statements\": [
              {
                \"expression\": {
                  \"arguments\": [
                    {
                      \"expression\": {
                        \"id\": 752,
                        \"name\": \"msg\",
                        \"nodeType\": \"Identifier\",
                        \"overloadedDeclarations\": [],
                        \"referencedDeclaration\": -15,
                        \"src\": \"2007:3:1\",
                        \"typeDescriptions\": {
                          \"typeIdentifier\": \"t_magic_message\",
                          \"typeString\": \"msg\"
                        }
                      },
                      \"id\": 753,
                      \"isConstant\": false,
                      \"isLValue\": false,
                      \"isPure\": false,
                      \"lValueRequested\": false,
                      \"memberLocation\": \"2011:6:1\",
                      \"memberName\": \"sender\",
                      \"nodeType\": \"MemberAccess\",
                      \"src\": \"2007:10:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    {
                      \"id\": 754,
                      \"name\": \"to\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 743,
                      \"src\": \"2019:2:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    }
                  ],
                  \"expression\": {
                    \"argumentTypes\": [
                      {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      },
                      {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    ],
                    \"id\": 751,
                    \"name\": \"_validateTransfer\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 835,
                    \"src\": \"1989:17:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_function_internal_view$_t_address_$_t_address_$returns$__$\",
                      \"typeString\": \"function (address,address) view\"
                    }
                  },
                  \"id\": 755,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"kind\": \"functionCall\",
                  \"lValueRequested\": false,
                  \"nameLocations\": [],
                  \"names\": [],
                  \"nodeType\": \"FunctionCall\",
                  \"src\": \"1989:33:1\",
                  \"tryCall\": false,
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_tuple$__$\",
                    \"typeString\": \"tuple()\"
                  }
                },
                \"id\": 756,
                \"nodeType\": \"ExpressionStatement\",
                \"src\": \"1989:33:1\"
              },
              {
                \"expression\": {
                  \"arguments\": [
                    {
                      \"id\": 759,
                      \"name\": \"to\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 743,
                      \"src\": \"2054:2:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    {
                      \"id\": 760,
                      \"name\": \"amount\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 745,
                      \"src\": \"2058:6:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_uint256\",
                        \"typeString\": \"uint256\"
                      }
                    }
                  ],
                  \"expression\": {
                    \"argumentTypes\": [
                      {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      },
                      {
                        \"typeIdentifier\": \"t_uint256\",
                        \"typeString\": \"uint256\"
                      }
                    ],
                    \"expression\": {
                      \"id\": 757,
                      \"name\": \"super\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": -25,
                      \"src\": \"2039:5:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_type$_t_super$_Titn_$883_$\",
                        \"typeString\": \"type(contract super Titn)\"
                      }
                    },
                    \"id\": 758,
                    \"isConstant\": false,
                    \"isLValue\": false,
                    \"isPure\": false,
                    \"lValueRequested\": false,
                    \"memberLocation\": \"2045:8:1\",
                    \"memberName\": \"transfer\",
                    \"nodeType\": \"MemberAccess\",
                    \"referencedDeclaration\": 5349,
                    \"src\": \"2039:14:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_function_internal_nonpayable$_t_address_$_t_uint256_$returns$_t_bool_$\",
                      \"typeString\": \"function (address,uint256) returns (bool)\"
                    }
                  },
                  \"id\": 761,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"kind\": \"functionCall\",
                  \"lValueRequested\": false,
                  \"nameLocations\": [],
                  \"names\": [],
                  \"nodeType\": \"FunctionCall\",
                  \"src\": \"2039:26:1\",
                  \"tryCall\": false,
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"functionReturnParameters\": 750,
                \"id\": 762,
                \"nodeType\": \"Return\",
                \"src\": \"2032:33:1\"
              }
            ]
          },
          \"baseFunctions\": [
            5349
          ],
          \"functionSelector\": \"a9059cbb\",
          \"implemented\": true,
          \"kind\": \"function\",
          \"modifiers\": [],
          \"name\": \"transfer\",
          \"nameLocation\": \"1911:8:1\",
          \"overrides\": {
            \"id\": 747,
            \"nodeType\": \"OverrideSpecifier\",
            \"overrides\": [],
            \"src\": \"1955:8:1\"
          },
          \"parameters\": {
            \"id\": 746,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 743,
                \"mutability\": \"mutable\",
                \"name\": \"to\",
                \"nameLocation\": \"1928:2:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 764,
                \"src\": \"1920:10:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_address\",
                  \"typeString\": \"address\"
                },
                \"typeName\": {
                  \"id\": 742,
                  \"name\": \"address\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"1920:7:1\",
                  \"stateMutability\": \"nonpayable\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"visibility\": \"internal\"
              },
              {
                \"constant\": false,
                \"id\": 745,
                \"mutability\": \"mutable\",
                \"name\": \"amount\",
                \"nameLocation\": \"1940:6:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 764,
                \"src\": \"1932:14:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_uint256\",
                  \"typeString\": \"uint256\"
                },
                \"typeName\": {
                  \"id\": 744,
                  \"name\": \"uint256\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"1932:7:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_uint256\",
                    \"typeString\": \"uint256\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"1919:28:1\"
          },
          \"returnParameters\": {
            \"id\": 750,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 749,
                \"mutability\": \"mutable\",
                \"name\": \"\",
                \"nameLocation\": \"-1:-1:-1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 764,
                \"src\": \"1973:4:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_bool\",
                  \"typeString\": \"bool\"
                },
                \"typeName\": {
                  \"id\": 748,
                  \"name\": \"bool\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"1973:4:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"1972:6:1\"
          },
          \"scope\": 883,
          \"stateMutability\": \"nonpayable\",
          \"virtual\": false,
          \"visibility\": \"public\"
        },
        {
          \"id\": 789,
          \"nodeType\": \"FunctionDefinition\",
          \"src\": \"2078:192:1\",
          \"nodes\": [],
          \"body\": {
            \"id\": 788,
            \"nodeType\": \"Block\",
            \"src\": \"2173:97:1\",
            \"nodes\": [],
            \"statements\": [
              {
                \"expression\": {
                  \"arguments\": [
                    {
                      \"id\": 777,
                      \"name\": \"from\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 766,
                      \"src\": \"2201:4:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    {
                      \"id\": 778,
                      \"name\": \"to\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 768,
                      \"src\": \"2207:2:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    }
                  ],
                  \"expression\": {
                    \"argumentTypes\": [
                      {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      },
                      {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    ],
                    \"id\": 776,
                    \"name\": \"_validateTransfer\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 835,
                    \"src\": \"2183:17:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_function_internal_view$_t_address_$_t_address_$returns$__$\",
                      \"typeString\": \"function (address,address) view\"
                    }
                  },
                  \"id\": 779,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"kind\": \"functionCall\",
                  \"lValueRequested\": false,
                  \"nameLocations\": [],
                  \"names\": [],
                  \"nodeType\": \"FunctionCall\",
                  \"src\": \"2183:27:1\",
                  \"tryCall\": false,
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_tuple$__$\",
                    \"typeString\": \"tuple()\"
                  }
                },
                \"id\": 780,
                \"nodeType\": \"ExpressionStatement\",
                \"src\": \"2183:27:1\"
              },
              {
                \"expression\": {
                  \"arguments\": [
                    {
                      \"id\": 783,
                      \"name\": \"from\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 766,
                      \"src\": \"2246:4:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    {
                      \"id\": 784,
                      \"name\": \"to\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 768,
                      \"src\": \"2252:2:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    {
                      \"id\": 785,
                      \"name\": \"amount\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 770,
                      \"src\": \"2256:6:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_uint256\",
                        \"typeString\": \"uint256\"
                      }
                    }
                  ],
                  \"expression\": {
                    \"argumentTypes\": [
                      {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      },
                      {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      },
                      {
                        \"typeIdentifier\": \"t_uint256\",
                        \"typeString\": \"uint256\"
                      }
                    ],
                    \"expression\": {
                      \"id\": 781,
                      \"name\": \"super\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": -25,
                      \"src\": \"2227:5:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_type$_t_super$_Titn_$883_$\",
                        \"typeString\": \"type(contract super Titn)\"
                      }
                    },
                    \"id\": 782,
                    \"isConstant\": false,
                    \"isLValue\": false,
                    \"isPure\": false,
                    \"lValueRequested\": false,
                    \"memberLocation\": \"2233:12:1\",
                    \"memberName\": \"transferFrom\",
                    \"nodeType\": \"MemberAccess\",
                    \"referencedDeclaration\": 5422,
                    \"src\": \"2227:18:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_function_internal_nonpayable$_t_address_$_t_address_$_t_uint256_$returns$_t_bool_$\",
                      \"typeString\": \"function (address,address,uint256) returns (bool)\"
                    }
                  },
                  \"id\": 786,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"kind\": \"functionCall\",
                  \"lValueRequested\": false,
                  \"nameLocations\": [],
                  \"names\": [],
                  \"nodeType\": \"FunctionCall\",
                  \"src\": \"2227:36:1\",
                  \"tryCall\": false,
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"functionReturnParameters\": 775,
                \"id\": 787,
                \"nodeType\": \"Return\",
                \"src\": \"2220:43:1\"
              }
            ]
          },
          \"baseFunctions\": [
            5422
          ],
          \"functionSelector\": \"23b872dd\",
          \"implemented\": true,
          \"kind\": \"function\",
          \"modifiers\": [],
          \"name\": \"transferFrom\",
          \"nameLocation\": \"2087:12:1\",
          \"overrides\": {
            \"id\": 772,
            \"nodeType\": \"OverrideSpecifier\",
            \"overrides\": [],
            \"src\": \"2149:8:1\"
          },
          \"parameters\": {
            \"id\": 771,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 766,
                \"mutability\": \"mutable\",
                \"name\": \"from\",
                \"nameLocation\": \"2108:4:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 789,
                \"src\": \"2100:12:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_address\",
                  \"typeString\": \"address\"
                },
                \"typeName\": {
                  \"id\": 765,
                  \"name\": \"address\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"2100:7:1\",
                  \"stateMutability\": \"nonpayable\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"visibility\": \"internal\"
              },
              {
                \"constant\": false,
                \"id\": 768,
                \"mutability\": \"mutable\",
                \"name\": \"to\",
                \"nameLocation\": \"2122:2:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 789,
                \"src\": \"2114:10:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_address\",
                  \"typeString\": \"address\"
                },
                \"typeName\": {
                  \"id\": 767,
                  \"name\": \"address\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"2114:7:1\",
                  \"stateMutability\": \"nonpayable\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"visibility\": \"internal\"
              },
              {
                \"constant\": false,
                \"id\": 770,
                \"mutability\": \"mutable\",
                \"name\": \"amount\",
                \"nameLocation\": \"2134:6:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 789,
                \"src\": \"2126:14:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_uint256\",
                  \"typeString\": \"uint256\"
                },
                \"typeName\": {
                  \"id\": 769,
                  \"name\": \"uint256\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"2126:7:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_uint256\",
                    \"typeString\": \"uint256\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"2099:42:1\"
          },
          \"returnParameters\": {
            \"id\": 775,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 774,
                \"mutability\": \"mutable\",
                \"name\": \"\",
                \"nameLocation\": \"-1:-1:-1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 789,
                \"src\": \"2167:4:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_bool\",
                  \"typeString\": \"bool\"
                },
                \"typeName\": {
                  \"id\": 773,
                  \"name\": \"bool\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"2167:4:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"2166:6:1\"
          },
          \"scope\": 883,
          \"stateMutability\": \"nonpayable\",
          \"virtual\": false,
          \"visibility\": \"public\"
        },
        {
          \"id\": 835,
          \"nodeType\": \"FunctionDefinition\",
          \"src\": \"2420:856:1\",
          \"nodes\": [],
          \"body\": {
            \"id\": 834,
            \"nodeType\": \"Block\",
            \"src\": \"2487:789:1\",
            \"nodes\": [],
            \"statements\": [
              {
                \"assignments\": [
                  798
                ],
                \"declarations\": [
                  {
                    \"constant\": false,
                    \"id\": 798,
                    \"mutability\": \"mutable\",
                    \"name\": \"arbitrumChainId\",
                    \"nameLocation\": \"2534:15:1\",
                    \"nodeType\": \"VariableDeclaration\",
                    \"scope\": 834,
                    \"src\": \"2526:23:1\",
                    \"stateVariable\": false,
                    \"storageLocation\": \"default\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_uint256\",
                      \"typeString\": \"uint256\"
                    },
                    \"typeName\": {
                      \"id\": 797,
                      \"name\": \"uint256\",
                      \"nodeType\": \"ElementaryTypeName\",
                      \"src\": \"2526:7:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_uint256\",
                        \"typeString\": \"uint256\"
                      }
                    },
                    \"visibility\": \"internal\"
                  }
                ],
                \"id\": 800,
                \"initialValue\": {
                  \"hexValue\": \"3432313631\",
                  \"id\": 799,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": true,
                  \"kind\": \"number\",
                  \"lValueRequested\": false,
                  \"nodeType\": \"Literal\",
                  \"src\": \"2552:5:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_rational_42161_by_1\",
                    \"typeString\": \"int_const 42161\"
                  },
                  \"value\": \"42161\"
                },
                \"nodeType\": \"VariableDeclarationStatement\",
                \"src\": \"2526:31:1\"
              },
              {
                \"condition\": {
                  \"commonType\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  },
                  \"id\": 828,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"lValueRequested\": false,
                  \"leftExpression\": {
                    \"commonType\": {
                      \"typeIdentifier\": \"t_bool\",
                      \"typeString\": \"bool\"
                    },
                    \"id\": 824,
                    \"isConstant\": false,
                    \"isLValue\": false,
                    \"isPure\": false,
                    \"lValueRequested\": false,
                    \"leftExpression\": {
                      \"commonType\": {
                        \"typeIdentifier\": \"t_bool\",
                        \"typeString\": \"bool\"
                      },
                      \"id\": 814,
                      \"isConstant\": false,
                      \"isLValue\": false,
                      \"isPure\": false,
                      \"lValueRequested\": false,
                      \"leftExpression\": {
                        \"commonType\": {
                          \"typeIdentifier\": \"t_bool\",
                          \"typeString\": \"bool\"
                        },
                        \"id\": 812,
                        \"isConstant\": false,
                        \"isLValue\": false,
                        \"isPure\": false,
                        \"lValueRequested\": false,
                        \"leftExpression\": {
                          \"commonType\": {
                            \"typeIdentifier\": \"t_bool\",
                            \"typeString\": \"bool\"
                          },
                          \"id\": 808,
                          \"isConstant\": false,
                          \"isLValue\": false,
                          \"isPure\": false,
                          \"lValueRequested\": false,
                          \"leftExpression\": {
                            \"commonType\": {
                              \"typeIdentifier\": \"t_address\",
                              \"typeString\": \"address\"
                            },
                            \"id\": 804,
                            \"isConstant\": false,
                            \"isLValue\": false,
                            \"isPure\": false,
                            \"lValueRequested\": false,
                            \"leftExpression\": {
                              \"id\": 801,
                              \"name\": \"from\",
                              \"nodeType\": \"Identifier\",
                              \"overloadedDeclarations\": [],
                              \"referencedDeclaration\": 792,
                              \"src\": \"2632:4:1\",
                              \"typeDescriptions\": {
                                \"typeIdentifier\": \"t_address\",
                                \"typeString\": \"address\"
                              }
                            },
                            \"nodeType\": \"BinaryOperation\",
                            \"operator\": \"!=\",
                            \"rightExpression\": {
                              \"arguments\": [],
                              \"expression\": {
                                \"argumentTypes\": [],
                                \"id\": 802,
                                \"name\": \"owner\",
                                \"nodeType\": \"Identifier\",
                                \"overloadedDeclarations\": [],
                                \"referencedDeclaration\": 4917,
                                \"src\": \"2640:5:1\",
                                \"typeDescriptions\": {
                                  \"typeIdentifier\": \"t_function_internal_view$__$returns$_t_address_$\",
                                  \"typeString\": \"function () view returns (address)\"
                                }
                              },
                              \"id\": 803,
                              \"isConstant\": false,
                              \"isLValue\": false,
                              \"isPure\": false,
                              \"kind\": \"functionCall\",
                              \"lValueRequested\": false,
                              \"nameLocations\": [],
                              \"names\": [],
                              \"nodeType\": \"FunctionCall\",
                              \"src\": \"2640:7:1\",
                              \"tryCall\": false,
                              \"typeDescriptions\": {
                                \"typeIdentifier\": \"t_address\",
                                \"typeString\": \"address\"
                              }
                            },
                            \"src\": \"2632:15:1\",
                            \"typeDescriptions\": {
                              \"typeIdentifier\": \"t_bool\",
                              \"typeString\": \"bool\"
                            }
                          },
                          \"nodeType\": \"BinaryOperation\",
                          \"operator\": \"&&\",
                          \"rightExpression\": {
                            \"commonType\": {
                              \"typeIdentifier\": \"t_address\",
                              \"typeString\": \"address\"
                            },
                            \"id\": 807,
                            \"isConstant\": false,
                            \"isLValue\": false,
                            \"isPure\": false,
                            \"lValueRequested\": false,
                            \"leftExpression\": {
                              \"id\": 805,
                              \"name\": \"from\",
                              \"nodeType\": \"Identifier\",
                              \"overloadedDeclarations\": [],
                              \"referencedDeclaration\": 792,
                              \"src\": \"2698:4:1\",
                              \"typeDescriptions\": {
                                \"typeIdentifier\": \"t_address\",
                                \"typeString\": \"address\"
                              }
                            },
                            \"nodeType\": \"BinaryOperation\",
                            \"operator\": \"!=\",
                            \"rightExpression\": {
                              \"id\": 806,
                              \"name\": \"transferAllowedContract\",
                              \"nodeType\": \"Identifier\",
                              \"overloadedDeclarations\": [],
                              \"referencedDeclaration\": 644,
                              \"src\": \"2706:23:1\",
                              \"typeDescriptions\": {
                                \"typeIdentifier\": \"t_address\",
                                \"typeString\": \"address\"
                              }
                            },
                            \"src\": \"2698:31:1\",
                            \"typeDescriptions\": {
                              \"typeIdentifier\": \"t_bool\",
                              \"typeString\": \"bool\"
                            }
                          },
                          \"src\": \"2632:97:1\",
                          \"typeDescriptions\": {
                            \"typeIdentifier\": \"t_bool\",
                            \"typeString\": \"bool\"
                          }
                        },
                        \"nodeType\": \"BinaryOperation\",
                        \"operator\": \"&&\",
                        \"rightExpression\": {
                          \"commonType\": {
                            \"typeIdentifier\": \"t_address\",
                            \"typeString\": \"address\"
                          },
                          \"id\": 811,
                          \"isConstant\": false,
                          \"isLValue\": false,
                          \"isPure\": false,
                          \"lValueRequested\": false,
                          \"leftExpression\": {
                            \"id\": 809,
                            \"name\": \"to\",
                            \"nodeType\": \"Identifier\",
                            \"overloadedDeclarations\": [],
                            \"referencedDeclaration\": 794,
                            \"src\": \"2795:2:1\",
                            \"typeDescriptions\": {
                              \"typeIdentifier\": \"t_address\",
                              \"typeString\": \"address\"
                            }
                          },
                          \"nodeType\": \"BinaryOperation\",
                          \"operator\": \"!=\",
                          \"rightExpression\": {
                            \"id\": 810,
                            \"name\": \"transferAllowedContract\",
                            \"nodeType\": \"Identifier\",
                            \"overloadedDeclarations\": [],
                            \"referencedDeclaration\": 644,
                            \"src\": \"2801:23:1\",
                            \"typeDescriptions\": {
                              \"typeIdentifier\": \"t_address\",
                              \"typeString\": \"address\"
                            }
                          },
                          \"src\": \"2795:29:1\",
                          \"typeDescriptions\": {
                            \"typeIdentifier\": \"t_bool\",
                            \"typeString\": \"bool\"
                          }
                        },
                        \"src\": \"2632:192:1\",
                        \"typeDescriptions\": {
                          \"typeIdentifier\": \"t_bool\",
                          \"typeString\": \"bool\"
                        }
                      },
                      \"nodeType\": \"BinaryOperation\",
                      \"operator\": \"&&\",
                      \"rightExpression\": {
                        \"id\": 813,
                        \"name\": \"isBridgedTokensTransferLocked\",
                        \"nodeType\": \"Identifier\",
                        \"overloadedDeclarations\": [],
                        \"referencedDeclaration\": 642,
                        \"src\": \"2890:29:1\",
                        \"typeDescriptions\": {
                          \"typeIdentifier\": \"t_bool\",
                          \"typeString\": \"bool\"
                        }
                      },
                      \"src\": \"2632:287:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_bool\",
                        \"typeString\": \"bool\"
                      }
                    },
                    \"nodeType\": \"BinaryOperation\",
                    \"operator\": \"&&\",
                    \"rightExpression\": {
                      \"components\": [
                        {
                          \"commonType\": {
                            \"typeIdentifier\": \"t_bool\",
                            \"typeString\": \"bool\"
                          },
                          \"id\": 822,
                          \"isConstant\": false,
                          \"isLValue\": false,
                          \"isPure\": false,
                          \"lValueRequested\": false,
                          \"leftExpression\": {
                            \"baseExpression\": {
                              \"id\": 815,
                              \"name\": \"isBridgedTokenHolder\",
                              \"nodeType\": \"Identifier\",
                              \"overloadedDeclarations\": [],
                              \"referencedDeclaration\": 640,
                              \"src\": \"3062:20:1\",
                              \"typeDescriptions\": {
                                \"typeIdentifier\": \"t_mapping$_t_address_$_t_bool_$\",
                                \"typeString\": \"mapping(address => bool)\"
                              }
                            },
                            \"id\": 817,
                            \"indexExpression\": {
                              \"id\": 816,
                              \"name\": \"from\",
                              \"nodeType\": \"Identifier\",
                              \"overloadedDeclarations\": [],
                              \"referencedDeclaration\": 792,
                              \"src\": \"3083:4:1\",
                              \"typeDescriptions\": {
                                \"typeIdentifier\": \"t_address\",
                                \"typeString\": \"address\"
                              }
                            },
                            \"isConstant\": false,
                            \"isLValue\": true,
                            \"isPure\": false,
                            \"lValueRequested\": false,
                            \"nodeType\": \"IndexAccess\",
                            \"src\": \"3062:26:1\",
                            \"typeDescriptions\": {
                              \"typeIdentifier\": \"t_bool\",
                              \"typeString\": \"bool\"
                            }
                          },
                          \"nodeType\": \"BinaryOperation\",
                          \"operator\": \"||\",
                          \"rightExpression\": {
                            \"commonType\": {
                              \"typeIdentifier\": \"t_uint256\",
                              \"typeString\": \"uint256\"
                            },
                            \"id\": 821,
                            \"isConstant\": false,
                            \"isLValue\": false,
                            \"isPure\": false,
                            \"lValueRequested\": false,
                            \"leftExpression\": {
                              \"expression\": {
                                \"id\": 818,
                                \"name\": \"block\",
                                \"nodeType\": \"Identifier\",
                                \"overloadedDeclarations\": [],
                                \"referencedDeclaration\": -4,
                                \"src\": \"3092:5:1\",
                                \"typeDescriptions\": {
                                  \"typeIdentifier\": \"t_magic_block\",
                                  \"typeString\": \"block\"
                                }
                              },
                              \"id\": 819,
                              \"isConstant\": false,
                              \"isLValue\": false,
                              \"isPure\": false,
                              \"lValueRequested\": false,
                              \"memberLocation\": \"3098:7:1\",
                              \"memberName\": \"chainid\",
                              \"nodeType\": \"MemberAccess\",
                              \"src\": \"3092:13:1\",
                              \"typeDescriptions\": {
                                \"typeIdentifier\": \"t_uint256\",
                                \"typeString\": \"uint256\"
                              }
                            },
                            \"nodeType\": \"BinaryOperation\",
                            \"operator\": \"==\",
                            \"rightExpression\": {
                              \"id\": 820,
                              \"name\": \"arbitrumChainId\",
                              \"nodeType\": \"Identifier\",
                              \"overloadedDeclarations\": [],
                              \"referencedDeclaration\": 798,
                              \"src\": \"3109:15:1\",
                              \"typeDescriptions\": {
                                \"typeIdentifier\": \"t_uint256\",
                                \"typeString\": \"uint256\"
                              }
                            },
                            \"src\": \"3092:32:1\",
                            \"typeDescriptions\": {
                              \"typeIdentifier\": \"t_bool\",
                              \"typeString\": \"bool\"
                            }
                          },
                          \"src\": \"3062:62:1\",
                          \"typeDescriptions\": {
                            \"typeIdentifier\": \"t_bool\",
                            \"typeString\": \"bool\"
                          }
                        }
                      ],
                      \"id\": 823,
                      \"isConstant\": false,
                      \"isInlineArray\": false,
                      \"isLValue\": false,
                      \"isPure\": false,
                      \"lValueRequested\": false,
                      \"nodeType\": \"TupleExpression\",
                      \"src\": \"3061:64:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_bool\",
                        \"typeString\": \"bool\"
                      }
                    },
                    \"src\": \"2632:493:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_bool\",
                      \"typeString\": \"bool\"
                    }
                  },
                  \"nodeType\": \"BinaryOperation\",
                  \"operator\": \"&&\",
                  \"rightExpression\": {
                    \"commonType\": {
                      \"typeIdentifier\": \"t_address\",
                      \"typeString\": \"address\"
                    },
                    \"id\": 827,
                    \"isConstant\": false,
                    \"isLValue\": false,
                    \"isPure\": false,
                    \"lValueRequested\": false,
                    \"leftExpression\": {
                      \"id\": 825,
                      \"name\": \"to\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 794,
                      \"src\": \"3141:2:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    \"nodeType\": \"BinaryOperation\",
                    \"operator\": \"!=\",
                    \"rightExpression\": {
                      \"id\": 826,
                      \"name\": \"lzEndpoint\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 646,
                      \"src\": \"3147:10:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    \"src\": \"3141:16:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_bool\",
                      \"typeString\": \"bool\"
                    }
                  },
                  \"src\": \"2632:525:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"id\": 833,
                \"nodeType\": \"IfStatement\",
                \"src\": \"2615:655:1\",
                \"trueBody\": {
                  \"id\": 832,
                  \"nodeType\": \"Block\",
                  \"src\": \"3209:61:1\",
                  \"statements\": [
                    {
                      \"errorCall\": {
                        \"arguments\": [],
                        \"expression\": {
                          \"argumentTypes\": [],
                          \"id\": 829,
                          \"name\": \"BridgedTokensTransferLocked\",
                          \"nodeType\": \"Identifier\",
                          \"overloadedDeclarations\": [],
                          \"referencedDeclaration\": 648,
                          \"src\": \"3230:27:1\",
                          \"typeDescriptions\": {
                            \"typeIdentifier\": \"t_function_error_pure$__$returns$_t_error_$\",
                            \"typeString\": \"function () pure returns (error)\"
                          }
                        },
                        \"id\": 830,
                        \"isConstant\": false,
                        \"isLValue\": false,
                        \"isPure\": false,
                        \"kind\": \"functionCall\",
                        \"lValueRequested\": false,
                        \"nameLocations\": [],
                        \"names\": [],
                        \"nodeType\": \"FunctionCall\",
                        \"src\": \"3230:29:1\",
                        \"tryCall\": false,
                        \"typeDescriptions\": {
                          \"typeIdentifier\": \"t_error\",
                          \"typeString\": \"error\"
                        }
                      },
                      \"id\": 831,
                      \"nodeType\": \"RevertStatement\",
                      \"src\": \"3223:36:1\"
                    }
                  ]
                }
              }
            ]
          },
          \"documentation\": {
            \"id\": 790,
            \"nodeType\": \"StructuredDocumentation\",
            \"src\": \"2276:139:1\",
            \"text\": \" @dev Validates transfer restrictions.\n @param from The sender's address.\n @param to The recipient's address.\"
          },
          \"implemented\": true,
          \"kind\": \"function\",
          \"modifiers\": [],
          \"name\": \"_validateTransfer\",
          \"nameLocation\": \"2429:17:1\",
          \"parameters\": {
            \"id\": 795,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 792,
                \"mutability\": \"mutable\",
                \"name\": \"from\",
                \"nameLocation\": \"2455:4:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 835,
                \"src\": \"2447:12:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_address\",
                  \"typeString\": \"address\"
                },
                \"typeName\": {
                  \"id\": 791,
                  \"name\": \"address\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"2447:7:1\",
                  \"stateMutability\": \"nonpayable\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"visibility\": \"internal\"
              },
              {
                \"constant\": false,
                \"id\": 794,
                \"mutability\": \"mutable\",
                \"name\": \"to\",
                \"nameLocation\": \"2469:2:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 835,
                \"src\": \"2461:10:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_address\",
                  \"typeString\": \"address\"
                },
                \"typeName\": {
                  \"id\": 793,
                  \"name\": \"address\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"2461:7:1\",
                  \"stateMutability\": \"nonpayable\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"2446:26:1\"
          },
          \"returnParameters\": {
            \"id\": 796,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [],
            \"src\": \"2487:0:1\"
          },
          \"scope\": 883,
          \"stateMutability\": \"view\",
          \"virtual\": false,
          \"visibility\": \"internal\"
        },
        {
          \"id\": 882,
          \"nodeType\": \"FunctionDefinition\",
          \"src\": \"3611:625:1\",
          \"nodes\": [],
          \"body\": {
            \"id\": 881,
            \"nodeType\": \"Block\",
            \"src\": \"3771:465:1\",
            \"nodes\": [],
            \"statements\": [
              {
                \"condition\": {
                  \"commonType\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  },
                  \"id\": 853,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"lValueRequested\": false,
                  \"leftExpression\": {
                    \"id\": 848,
                    \"name\": \"_to\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 838,
                    \"src\": \"3785:3:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_address\",
                      \"typeString\": \"address\"
                    }
                  },
                  \"nodeType\": \"BinaryOperation\",
                  \"operator\": \"==\",
                  \"rightExpression\": {
                    \"arguments\": [
                      {
                        \"hexValue\": \"307830\",
                        \"id\": 851,
                        \"isConstant\": false,
                        \"isLValue\": false,
                        \"isPure\": true,
                        \"kind\": \"number\",
                        \"lValueRequested\": false,
                        \"nodeType\": \"Literal\",
                        \"src\": \"3800:3:1\",
                        \"typeDescriptions\": {
                          \"typeIdentifier\": \"t_rational_0_by_1\",
                          \"typeString\": \"int_const 0\"
                        },
                        \"value\": \"0x0\"
                      }
                    ],
                    \"expression\": {
                      \"argumentTypes\": [
                        {
                          \"typeIdentifier\": \"t_rational_0_by_1\",
                          \"typeString\": \"int_const 0\"
                        }
                      ],
                      \"id\": 850,
                      \"isConstant\": false,
                      \"isLValue\": false,
                      \"isPure\": true,
                      \"lValueRequested\": false,
                      \"nodeType\": \"ElementaryTypeNameExpression\",
                      \"src\": \"3792:7:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_type$_t_address_$\",
                        \"typeString\": \"type(address)\"
                      },
                      \"typeName\": {
                        \"id\": 849,
                        \"name\": \"address\",
                        \"nodeType\": \"ElementaryTypeName\",
                        \"src\": \"3792:7:1\",
                        \"typeDescriptions\": {}
                      }
                    },
                    \"id\": 852,
                    \"isConstant\": false,
                    \"isLValue\": false,
                    \"isPure\": true,
                    \"kind\": \"typeConversion\",
                    \"lValueRequested\": false,
                    \"nameLocations\": [],
                    \"names\": [],
                    \"nodeType\": \"FunctionCall\",
                    \"src\": \"3792:12:1\",
                    \"tryCall\": false,
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_address\",
                      \"typeString\": \"address\"
                    }
                  },
                  \"src\": \"3785:19:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"id\": 861,
                \"nodeType\": \"IfStatement\",
                \"src\": \"3781:46:1\",
                \"trueBody\": {
                  \"expression\": {
                    \"id\": 859,
                    \"isConstant\": false,
                    \"isLValue\": false,
                    \"isPure\": false,
                    \"lValueRequested\": false,
                    \"leftHandSide\": {
                      \"id\": 854,
                      \"name\": \"_to\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 838,
                      \"src\": \"3806:3:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    \"nodeType\": \"Assignment\",
                    \"operator\": \"=\",
                    \"rightHandSide\": {
                      \"arguments\": [
                        {
                          \"hexValue\": \"307864656164\",
                          \"id\": 857,
                          \"isConstant\": false,
                          \"isLValue\": false,
                          \"isPure\": true,
                          \"kind\": \"number\",
                          \"lValueRequested\": false,
                          \"nodeType\": \"Literal\",
                          \"src\": \"3820:6:1\",
                          \"typeDescriptions\": {
                            \"typeIdentifier\": \"t_rational_57005_by_1\",
                            \"typeString\": \"int_const 57005\"
                          },
                          \"value\": \"0xdead\"
                        }
                      ],
                      \"expression\": {
                        \"argumentTypes\": [
                          {
                            \"typeIdentifier\": \"t_rational_57005_by_1\",
                            \"typeString\": \"int_const 57005\"
                          }
                        ],
                        \"id\": 856,
                        \"isConstant\": false,
                        \"isLValue\": false,
                        \"isPure\": true,
                        \"lValueRequested\": false,
                        \"nodeType\": \"ElementaryTypeNameExpression\",
                        \"src\": \"3812:7:1\",
                        \"typeDescriptions\": {
                          \"typeIdentifier\": \"t_type$_t_address_$\",
                          \"typeString\": \"type(address)\"
                        },
                        \"typeName\": {
                          \"id\": 855,
                          \"name\": \"address\",
                          \"nodeType\": \"ElementaryTypeName\",
                          \"src\": \"3812:7:1\",
                          \"typeDescriptions\": {}
                        }
                      },
                      \"id\": 858,
                      \"isConstant\": false,
                      \"isLValue\": false,
                      \"isPure\": true,
                      \"kind\": \"typeConversion\",
                      \"lValueRequested\": false,
                      \"nameLocations\": [],
                      \"names\": [],
                      \"nodeType\": \"FunctionCall\",
                      \"src\": \"3812:15:1\",
                      \"tryCall\": false,
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    \"src\": \"3806:21:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_address\",
                      \"typeString\": \"address\"
                    }
                  },
                  \"id\": 860,
                  \"nodeType\": \"ExpressionStatement\",
                  \"src\": \"3806:21:1\"
                }
              },
              {
                \"expression\": {
                  \"arguments\": [
                    {
                      \"id\": 863,
                      \"name\": \"_to\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 838,
                      \"src\": \"3924:3:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    {
                      \"id\": 864,
                      \"name\": \"_amountLD\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 840,
                      \"src\": \"3929:9:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_uint256\",
                        \"typeString\": \"uint256\"
                      }
                    }
                  ],
                  \"expression\": {
                    \"argumentTypes\": [
                      {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      },
                      {
                        \"typeIdentifier\": \"t_uint256\",
                        \"typeString\": \"uint256\"
                      }
                    ],
                    \"id\": 862,
                    \"name\": \"_mint\",
                    \"nodeType\": \"Identifier\",
                    \"overloadedDeclarations\": [],
                    \"referencedDeclaration\": 5579,
                    \"src\": \"3918:5:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_function_internal_nonpayable$_t_address_$_t_uint256_$returns$__$\",
                      \"typeString\": \"function (address,uint256)\"
                    }
                  },
                  \"id\": 865,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"kind\": \"functionCall\",
                  \"lValueRequested\": false,
                  \"nameLocations\": [],
                  \"names\": [],
                  \"nodeType\": \"FunctionCall\",
                  \"src\": \"3918:21:1\",
                  \"tryCall\": false,
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_tuple$__$\",
                    \"typeString\": \"tuple()\"
                  }
                },
                \"id\": 866,
                \"nodeType\": \"ExpressionStatement\",
                \"src\": \"3918:21:1\"
              },
              {
                \"condition\": {
                  \"id\": 870,
                  \"isConstant\": false,
                  \"isLValue\": false,
                  \"isPure\": false,
                  \"lValueRequested\": false,
                  \"nodeType\": \"UnaryOperation\",
                  \"operator\": \"!\",
                  \"prefix\": true,
                  \"src\": \"4027:26:1\",
                  \"subExpression\": {
                    \"baseExpression\": {
                      \"id\": 867,
                      \"name\": \"isBridgedTokenHolder\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 640,
                      \"src\": \"4028:20:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_mapping$_t_address_$_t_bool_$\",
                        \"typeString\": \"mapping(address => bool)\"
                      }
                    },
                    \"id\": 869,
                    \"indexExpression\": {
                      \"id\": 868,
                      \"name\": \"_to\",
                      \"nodeType\": \"Identifier\",
                      \"overloadedDeclarations\": [],
                      \"referencedDeclaration\": 838,
                      \"src\": \"4049:3:1\",
                      \"typeDescriptions\": {
                        \"typeIdentifier\": \"t_address\",
                        \"typeString\": \"address\"
                      }
                    },
                    \"isConstant\": false,
                    \"isLValue\": true,
                    \"isPure\": false,
                    \"lValueRequested\": false,
                    \"nodeType\": \"IndexAccess\",
                    \"src\": \"4028:25:1\",
                    \"typeDescriptions\": {
                      \"typeIdentifier\": \"t_bool\",
                      \"typeString\": \"bool\"
                    }
                  },
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_bool\",
                    \"typeString\": \"bool\"
                  }
                },
                \"id\": 878,
                \"nodeType\": \"IfStatement\",
                \"src\": \"4023:89:1\",
                \"trueBody\": {
                  \"id\": 877,
                  \"nodeType\": \"Block\",
                  \"src\": \"4055:57:1\",
                  \"statements\": [
                    {
                      \"expression\": {
                        \"id\": 875,
                        \"isConstant\": false,
                        \"isLValue\": false,
                        \"isPure\": false,
                        \"lValueRequested\": false,
                        \"leftHandSide\": {
                          \"baseExpression\": {
                            \"id\": 871,
                            \"name\": \"isBridgedTokenHolder\",
                            \"nodeType\": \"Identifier\",
                            \"overloadedDeclarations\": [],
                            \"referencedDeclaration\": 640,
                            \"src\": \"4069:20:1\",
                            \"typeDescriptions\": {
                              \"typeIdentifier\": \"t_mapping$_t_address_$_t_bool_$\",
                              \"typeString\": \"mapping(address => bool)\"
                            }
                          },
                          \"id\": 873,
                          \"indexExpression\": {
                            \"id\": 872,
                            \"name\": \"_to\",
                            \"nodeType\": \"Identifier\",
                            \"overloadedDeclarations\": [],
                            \"referencedDeclaration\": 838,
                            \"src\": \"4090:3:1\",
                            \"typeDescriptions\": {
                              \"typeIdentifier\": \"t_address\",
                              \"typeString\": \"address\"
                            }
                          },
                          \"isConstant\": false,
                          \"isLValue\": true,
                          \"isPure\": false,
                          \"lValueRequested\": true,
                          \"nodeType\": \"IndexAccess\",
                          \"src\": \"4069:25:1\",
                          \"typeDescriptions\": {
                            \"typeIdentifier\": \"t_bool\",
                            \"typeString\": \"bool\"
                          }
                        },
                        \"nodeType\": \"Assignment\",
                        \"operator\": \"=\",
                        \"rightHandSide\": {
                          \"hexValue\": \"74727565\",
                          \"id\": 874,
                          \"isConstant\": false,
                          \"isLValue\": false,
                          \"isPure\": true,
                          \"kind\": \"bool\",
                          \"lValueRequested\": false,
                          \"nodeType\": \"Literal\",
                          \"src\": \"4097:4:1\",
                          \"typeDescriptions\": {
                            \"typeIdentifier\": \"t_bool\",
                            \"typeString\": \"bool\"
                          },
                          \"value\": \"true\"
                        },
                        \"src\": \"4069:32:1\",
                        \"typeDescriptions\": {
                          \"typeIdentifier\": \"t_bool\",
                          \"typeString\": \"bool\"
                        }
                      },
                      \"id\": 876,
                      \"nodeType\": \"ExpressionStatement\",
                      \"src\": \"4069:32:1\"
                    }
                  ]
                }
              },
              {
                \"expression\": {
                  \"id\": 879,
                  \"name\": \"_amountLD\",
                  \"nodeType\": \"Identifier\",
                  \"overloadedDeclarations\": [],
                  \"referencedDeclaration\": 840,
                  \"src\": \"4220:9:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_uint256\",
                    \"typeString\": \"uint256\"
                  }
                },
                \"functionReturnParameters\": 847,
                \"id\": 880,
                \"nodeType\": \"Return\",
                \"src\": \"4213:16:1\"
              }
            ]
          },
          \"baseFunctions\": [
            3752
          ],
          \"documentation\": {
            \"id\": 836,
            \"nodeType\": \"StructuredDocumentation\",
            \"src\": \"3282:324:1\",
            \"text\": \" @dev Credits tokens to the specified address.\n @param _to The address to credit the tokens to.\n @param _amountLD The amount of tokens to credit in local decimals.\n @dev _srcEid The source chain ID.\n @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.\"
          },
          \"implemented\": true,
          \"kind\": \"function\",
          \"modifiers\": [],
          \"name\": \"_credit\",
          \"nameLocation\": \"3620:7:1\",
          \"overrides\": {
            \"id\": 844,
            \"nodeType\": \"OverrideSpecifier\",
            \"overrides\": [],
            \"src\": \"3727:8:1\"
          },
          \"parameters\": {
            \"id\": 843,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 838,
                \"mutability\": \"mutable\",
                \"name\": \"_to\",
                \"nameLocation\": \"3645:3:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 882,
                \"src\": \"3637:11:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_address\",
                  \"typeString\": \"address\"
                },
                \"typeName\": {
                  \"id\": 837,
                  \"name\": \"address\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"3637:7:1\",
                  \"stateMutability\": \"nonpayable\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_address\",
                    \"typeString\": \"address\"
                  }
                },
                \"visibility\": \"internal\"
              },
              {
                \"constant\": false,
                \"id\": 840,
                \"mutability\": \"mutable\",
                \"name\": \"_amountLD\",
                \"nameLocation\": \"3666:9:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 882,
                \"src\": \"3658:17:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_uint256\",
                  \"typeString\": \"uint256\"
                },
                \"typeName\": {
                  \"id\": 839,
                  \"name\": \"uint256\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"3658:7:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_uint256\",
                    \"typeString\": \"uint256\"
                  }
                },
                \"visibility\": \"internal\"
              },
              {
                \"constant\": false,
                \"id\": 842,
                \"mutability\": \"mutable\",
                \"name\": \"\",
                \"nameLocation\": \"-1:-1:-1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 882,
                \"src\": \"3685:6:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_uint32\",
                  \"typeString\": \"uint32\"
                },
                \"typeName\": {
                  \"id\": 841,
                  \"name\": \"uint32\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"3685:6:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_uint32\",
                    \"typeString\": \"uint32\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"3627:82:1\"
          },
          \"returnParameters\": {
            \"id\": 847,
            \"nodeType\": \"ParameterList\",
            \"parameters\": [
              {
                \"constant\": false,
                \"id\": 846,
                \"mutability\": \"mutable\",
                \"name\": \"amountReceivedLD\",
                \"nameLocation\": \"3753:16:1\",
                \"nodeType\": \"VariableDeclaration\",
                \"scope\": 882,
                \"src\": \"3745:24:1\",
                \"stateVariable\": false,
                \"storageLocation\": \"default\",
                \"typeDescriptions\": {
                  \"typeIdentifier\": \"t_uint256\",
                  \"typeString\": \"uint256\"
                },
                \"typeName\": {
                  \"id\": 845,
                  \"name\": \"uint256\",
                  \"nodeType\": \"ElementaryTypeName\",
                  \"src\": \"3745:7:1\",
                  \"typeDescriptions\": {
                    \"typeIdentifier\": \"t_uint256\",
                    \"typeString\": \"uint256\"
                  }
                },
                \"visibility\": \"internal\"
              }
            ],
            \"src\": \"3744:26:1\"
          },
          \"scope\": 883,
          \"stateMutability\": \"nonpayable\",
          \"virtual\": true,
          \"visibility\": \"internal\"
        }
      ],
      \"abstract\": false,
      \"baseContracts\": [
        {
          \"baseName\": {
            \"id\": 635,
            \"name\": \"OFT\",
            \"nameLocations\": [
              \"206:3:1\"
            ],
            \"nodeType\": \"IdentifierPath\",
            \"referencedDeclaration\": 3753,
            \"src\": \"206:3:1\"
          },
          \"id\": 636,
          \"nodeType\": \"InheritanceSpecifier\",
          \"src\": \"206:3:1\"
        }
      ],
      \"canonicalName\": \"Titn\",
      \"contractDependencies\": [],
      \"contractKind\": \"contract\",
      \"fullyImplemented\": true,
      \"linearizedBaseContracts\": [
        883,
        3753,
        5739,
        5129,
        5843,
        5817,
        4382,
        3166,
        3340,
        2388,
        2670,
        2856,
        2518,
        4997,
        6282,
        2981,
        3394,
        2919,
        3002,
        1255,
        4526
      ],
      \"name\": \"Titn\",
      \"nameLocation\": \"198:4:1\",
      \"scope\": 884,
      \"usedErrors\": [
        648,
        2534,
        2692,
        2694,
        2867,
        2871,
        2873,
        2875,
        2954,
        3350,
        3352,
        4424,
        4430,
        4863,
        4868,
        5099,
        5104,
        5109,
        5118,
        5123,
        5128,
        5855
      ],
      \"usedEvents\": [
        689,
        717,
        2881,
        2960,
        3357,
        3807,
        4442,
        4452,
        4874,
        5751,
        5760
      ]
    }
  ],
  \"license\": \"MIT\"
},
\"id\": 1
}"
