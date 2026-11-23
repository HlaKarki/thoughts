import SwiftUI

enum Focus: Equatable, Hashable {
  case input
  case search
  case list
}

enum KeyCommand: Equatable {
  case add
  case selectNewest
  case focusSearch
  case clearSearch
  case hidePanel
  case removeAttachment
  case move(Int)
  case extend(Int)
  case edit
  case toggleDone
  case copy
  case copyPath
  case preview
  case openSource
  case showInFinder
  case delete
  case actionsMenu
  case backToInput
}

struct KeyStroke: Equatable {
  let key: KeyEquivalent
  let modifiers: EventModifiers
}
