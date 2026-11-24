struct Hit: Equatable {
  enum Kind: Equatable {
    case comment
    case unparsed
  }

  let path: String
  let line: Int
  var kind: Kind = .comment
}
