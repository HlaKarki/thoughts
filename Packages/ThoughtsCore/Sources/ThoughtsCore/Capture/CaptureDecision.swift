import Foundation

public enum SelectionProbe: Sendable, Equatable {
  case text(String)
  case empty
  case unavailable
  case secureField
  case copiedNothing
  case copyDisabled
}

public struct ClipboardImage: Sendable, Equatable {
  public let changeCount: Int
  public let seen: Date

  public init(changeCount: Int, seen: Date) {
    self.changeCount = changeCount
    self.seen = seen
  }
}

public struct CaptureContext: Sendable, Equatable {
  public var offer: OfferID?
  public var selection: SelectionProbe
  public var fallbackAllowed: Bool
  public var clipboardImage: ClipboardImage?
  public var changeCount: Int
  public var equivalentCounts: [Int]
  public var saved: SavedLedger
  public var source: Source
  public var now: Date

  public init(
    offer: OfferID? = nil,
    selection: SelectionProbe,
    fallbackAllowed: Bool,
    clipboardImage: ClipboardImage? = nil,
    changeCount: Int,
    equivalentCounts: [Int] = [],
    saved: SavedLedger = SavedLedger(),
    source: Source = Source(),
    now: Date
  ) {
    self.offer = offer
    self.selection = selection
    self.fallbackAllowed = fallbackAllowed
    self.clipboardImage = clipboardImage
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
    guard hasRecentImage(context) else { return .nothingToSave }
    let counts = [context.changeCount] + context.equivalentCounts
    if let match = context.saved.newestHoldingImage(counts: counts) {
      return .alreadySaved(match.file)
    }
    return .saveClipboardImage
  }

  private static func hasRecentImage(_ context: CaptureContext) -> Bool {
    guard let image = context.clipboardImage, image.changeCount == context.changeCount else {
      return false
    }
    let age = context.now.timeIntervalSince(image.seen)
    return age <= imageWindow
  }

  private static func isBlank(_ text: String) -> Bool {
    text.allSatisfy(\.isWhitespace)
  }
}
