import Foundation

public enum SelectionProbe: Sendable, Equatable {
  case text(String)
  case empty
  case unavailable
  case secureField
  case copiedNothing
  case copyDisabled
}

public struct ClipboardCopy: Sendable, Equatable {
  public enum Kind: Sendable, Equatable {
    case image
    case text
    case unknown
  }

  public let changeCount: Int
  public let seen: Date
  public let kind: Kind
  public let app: AppSnapshot?
  public let own: Bool

  public init(
    changeCount: Int, seen: Date, kind: Kind = .unknown, app: AppSnapshot? = nil,
    own: Bool = false
  ) {
    self.changeCount = changeCount
    self.seen = seen
    self.kind = kind
    self.app = app
    self.own = own
  }

  public func moved(to changeCount: Int) -> ClipboardCopy {
    ClipboardCopy(changeCount: changeCount, seen: seen, kind: kind, app: app, own: own)
  }

  public func source(recorded: Source) -> Source {
    guard let app else { return Source() }
    if app.bundleID == recorded.bundleID, app.name == recorded.app { return recorded }
    return Source(app: app.name, bundleID: app.bundleID)
  }
}

public enum ClipboardContent: Sendable, Equatable {
  case image
  case text(String)
  case nothing
}

public struct CaptureContext: Sendable, Equatable {
  public var offer: OfferID?
  public var selection: SelectionProbe
  public var fallbackAllowed: Bool
  public var clipboard: ClipboardCopy?
  public var clipboardContent: ClipboardContent?
  public var changeCount: Int
  public var equivalentCounts: [Int]
  public var saved: SavedLedger
  public var source: Source
  public var now: Date

  public init(
    offer: OfferID? = nil,
    selection: SelectionProbe,
    fallbackAllowed: Bool,
    clipboard: ClipboardCopy? = nil,
    clipboardContent: ClipboardContent? = nil,
    changeCount: Int,
    equivalentCounts: [Int] = [],
    saved: SavedLedger = SavedLedger(),
    source: Source = Source(),
    now: Date
  ) {
    self.offer = offer
    self.selection = selection
    self.fallbackAllowed = fallbackAllowed
    self.clipboard = clipboard
    self.clipboardContent = clipboardContent
    self.changeCount = changeCount
    self.equivalentCounts = equivalentCounts
    self.saved = saved
    self.source = source
    self.now = now
  }
}

public enum CaptureAction: Sendable, Equatable {
  case acceptOffer(OfferID)
  case saveText(String)
  case copyFallback
  case readClipboard
  case saveCopiedText(String, Source)
  case saveClipboardImage
  case alreadySaved(URL)
  case nothingToSave
}

public enum CaptureDecision {
  public static let imageWindow: TimeInterval = 120

  public static func decide(_ context: CaptureContext) -> CaptureAction {
    if let offer = context.offer { return .acceptOffer(offer) }
    switch context.selection {
    case .secureField:
      return .nothingToSave
    case .text(let text) where !isBlank(text):
      if let match = context.saved.newestMatchingText(text, from: context.source) {
        return .alreadySaved(match.file)
      }
      return .saveText(text)
    case .text, .unavailable:
      if context.fallbackAllowed { return .copyFallback }
    case .empty, .copyDisabled, .copiedNothing:
      break
    }
    return decideClipboard(context)
  }

  private static func decideClipboard(_ context: CaptureContext) -> CaptureAction {
    guard let copy = recentCopy(context) else { return .nothingToSave }
    if copy.own, copy.kind == .text { return .nothingToSave }
    let counts = [context.changeCount] + context.equivalentCounts
    if let match = context.saved.newestHolding(counts: counts) {
      return .alreadySaved(match.file)
    }
    switch context.clipboardContent {
    case nil:
      return copy.kind == .image ? .saveClipboardImage : .readClipboard
    case .image:
      return .saveClipboardImage
    case .text(let text):
      guard !copy.own, !isBlank(text) else { return .nothingToSave }
      let source = copy.source(recorded: context.source)
      if let match = context.saved.newestMatchingText(text, from: source) {
        return .alreadySaved(match.file)
      }
      return .saveCopiedText(text, source)
    case .nothing:
      return .nothingToSave
    }
  }

  private static func recentCopy(_ context: CaptureContext) -> ClipboardCopy? {
    guard let copy = context.clipboard, copy.changeCount == context.changeCount else {
      return nil
    }
    return context.now.timeIntervalSince(copy.seen) <= imageWindow ? copy : nil
  }

  private static func isBlank(_ text: String) -> Bool {
    text.allSatisfy(\.isWhitespace)
  }
}
