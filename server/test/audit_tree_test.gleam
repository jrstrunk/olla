import gleam/dict
import gleeunit/should
import o11a/user_interface/audit_tree

pub fn group_files_by_parent_test() {
  let files = [
    "example_audit/readme.md", "example_audit/src/o11a.sol",
    "example_audit/src/o11a/page.sol",
    "example_audit/src/o11a/user_interface/line_notes.sol",
    "example_audit/src/o11a/user_interface/function_notes.sol",
  ]

  audit_tree.group_files_by_parent(files)
  |> should.equal(
    [
      #("example_audit", #(["example_audit/src"], ["example_audit/readme.md"])),
      #(
        "example_audit/src",
        #(["example_audit/src/o11a"], ["example_audit/src/o11a.sol"]),
      ),
      #(
        "example_audit/src/o11a",
        #(["example_audit/src/o11a/user_interface"], [
          "example_audit/src/o11a/page.sol",
        ]),
      ),
      #(
        "example_audit/src/o11a/user_interface",
        #([], [
          "example_audit/src/o11a/user_interface/line_notes.sol",
          "example_audit/src/o11a/user_interface/function_notes.sol",
        ]),
      ),
    ]
    |> dict.from_list,
  )
}

pub fn group_files_by_parent2_test() {
  let files = [
    "thorwallet/contracts/mocks/Tgt.sol",
    "thorwallet/contracts/interfaces/IERC677Receiver.sol",
    "thorwallet/contracts/interfaces/IMerge.sol",
    "thorwallet/contracts/MergeTgt.sol", "thorwallet/contracts/Titn.sol",
  ]

  audit_tree.group_files_by_parent(files)
  |> should.equal(
    [
      #("thorwallet", #(["thorwallet/contracts"], [])),
      #(
        "thorwallet/contracts",
        #(["thorwallet/contracts/mocks", "thorwallet/contracts/interfaces"], [
          "thorwallet/contracts/MergeTgt.sol", "thorwallet/contracts/Titn.sol",
        ]),
      ),
      #(
        "thorwallet/contracts/interfaces",
        #([], [
          "thorwallet/contracts/interfaces/IERC677Receiver.sol",
          "thorwallet/contracts/interfaces/IMerge.sol",
        ]),
      ),
      #(
        "thorwallet/contracts/mocks",
        #([], ["thorwallet/contracts/mocks/Tgt.sol"]),
      ),
    ]
    |> dict.from_list,
  )
}
