pub type Topic {
  SourceFile(topic_id: String, name: String)
  SourceDeclaration(
    topic_id: String,
    name: String,
    signature: Bool,
    scope: Bool,
  )
  TextDeclaration(topic_id: String, name: String, signature: Bool)
  Note(topic_id: String)
  AttackVector(topic_id: String)
}
