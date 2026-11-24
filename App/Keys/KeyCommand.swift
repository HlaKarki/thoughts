import SwiftUI

enum Focus: Equatable, Hashable {
  case input
  case search
  case list
  case menu
  case edit
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
  case saveEdit
  case cancelEdit
  case toggleDone
  case copy
  case copyPath
  case preview
  case openSource
  case showInFinder
  case delete
  case clearDone
  case actionsMenu
  case backToInput
  case type(String)
  case menuMove(Int)
  case menuRun
  case menuClose
  case ignore
}

struct KeyStroke: Equatable {
  let key: KeyEquivalent
  let modifiers: EventModifiers
  var characters = ""
}
