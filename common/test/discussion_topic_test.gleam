// import gleam/dict
// import gleam/option
// import gleeunit/should
// import o11a/discussion_topic
// import o11a/preprocessor

// pub fn declaration_merge_test() {
//   let declarations =
//     dict.from_list([
//       #(
//         "1",
//         topic.Topic(
//           id: 1,
//           topic_id: "1",
//           name: "1",
//           signature: [],
//           scope: preprocessor.Scope("", option.None, option.None),
//           kind: preprocessor.VariableDeclaration,
//           references: [
//             preprocessor.Reference(
//               parent_id: 101,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//             preprocessor.Reference(
//               parent_id: 104,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//           ],
//         ),
//       ),
//       #(
//         "2",
//         topic.Topic(
//           id: 2,
//           topic_id: "2",
//           name: "2",
//           signature: [],
//           scope: preprocessor.Scope("", option.None, option.None),
//           kind: preprocessor.VariableDeclaration,
//           references: [
//             preprocessor.Reference(
//               parent_id: 103,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//           ],
//         ),
//       ),
//       #(
//         "3",
//         topic.Topic(
//           id: 3,
//           topic_id: "3",
//           name: "3",
//           signature: [],
//           scope: preprocessor.Scope("", option.None, option.None),
//           kind: preprocessor.VariableDeclaration,
//           references: [
//             preprocessor.Reference(
//               parent_id: 104,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//           ],
//         ),
//       ),
//       #(
//         "4",
//         topic.Topic(
//           id: 4,
//           topic_id: "4",
//           name: "4",
//           signature: [],
//           scope: preprocessor.Scope("", option.None, option.None),
//           kind: preprocessor.VariableDeclaration,
//           references: [
//             preprocessor.Reference(
//               parent_id: 105,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//           ],
//         ),
//       ),
//     ])

//   let topic_merges = dict.from_list([#("1", "2"), #("2", "4")])

//   discussion_topic.build_declarations(declarations, topic_merges)
//   |> should.equal(
//     dict.from_list([
//       #(
//         "1",
//         topic.Topic(
//           id: 4,
//           topic_id: "4",
//           name: "4",
//           signature: [],
//           scope: preprocessor.Scope("", option.None, option.None),
//           kind: preprocessor.VariableDeclaration,
//           references: [
//             preprocessor.Reference(
//               parent_id: 105,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//             preprocessor.Reference(
//               parent_id: 103,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//             preprocessor.Reference(
//               parent_id: 101,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//             preprocessor.Reference(
//               parent_id: 102,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//           ],
//         ),
//       ),
//       #(
//         "2",
//         topic.Topic(
//           id: 4,
//           topic_id: "4",
//           name: "4",
//           signature: [],
//           scope: preprocessor.Scope("", option.None, option.None),
//           kind: preprocessor.VariableDeclaration,
//           references: [
//             preprocessor.Reference(
//               parent_id: 105,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//             preprocessor.Reference(
//               parent_id: 103,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//             preprocessor.Reference(
//               parent_id: 101,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//             preprocessor.Reference(
//               parent_id: 102,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//           ],
//         ),
//       ),
//       #(
//         "3",
//         topic.Topic(
//           id: 3,
//           topic_id: "3",
//           name: "3",
//           signature: [],
//           scope: preprocessor.Scope("", option.None, option.None),
//           kind: preprocessor.VariableDeclaration,
//           references: [
//             preprocessor.Reference(
//               parent_id: 104,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//           ],
//         ),
//       ),
//       #(
//         "4",
//         topic.Topic(
//           id: 4,
//           topic_id: "4",
//           name: "4",
//           signature: [],
//           scope: preprocessor.Scope("", option.None, option.None),
//           kind: preprocessor.VariableDeclaration,
//           references: [
//             preprocessor.Reference(
//               parent_id: 105,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//             preprocessor.Reference(
//               parent_id: 103,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//             preprocessor.Reference(
//               parent_id: 101,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//             preprocessor.Reference(
//               parent_id: 102,
//               scope: preprocessor.Scope("", option.None, option.None),
//               kind: preprocessor.CallReference,
//               source: preprocessor.Solidity,
//             ),
//           ],
//         ),
//       ),
//     ]),
//   )
// }
