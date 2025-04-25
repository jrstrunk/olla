import gleam/dict
import gleam/dynamic/decode
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

  preprocessor_sol.preprocess_source(src, nodes, dict.new(), "thorwallet", "")
  |> list.map(fn(e) { echo e })
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
