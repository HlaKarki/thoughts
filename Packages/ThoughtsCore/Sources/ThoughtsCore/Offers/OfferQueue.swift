import Foundation

public struct OfferQueue: Sendable {
  private static let remembered = 64

  public let mergeWindow: TimeInterval
  public let lifetime: TimeInterval
  public private(set) var current: Offer?
  private var ownCounts: [Int] = []
  private var savedCounts: [Int] = []
  private var savedFiles: [URL] = []
  private var lastSavedClipboard: Date?

  public init(mergeWindow: TimeInterval = 3, lifetime: TimeInterval = 6) {
    self.mergeWindow = mergeWindow
    self.lifetime = lifetime
  }

  public mutating func add(_ signal: OfferSignal, source: Source?) -> OfferUpdate {
    switch signal {
    case .clipboard(let changeCount, let file, let date):
      if ownCounts.contains(changeCount) || savedCounts.contains(changeCount) { return .ignore }
      if let file, savedFiles.contains(file) { return .ignore }
      if var offer = current, withinWindow(offer, date) {
        if offer.changeCount == changeCount { return .ignore }
        let sameImage = file == nil || offer.file == nil || offer.file == file
        if offer.changeCount == nil, sameImage {
          offer.changeCount = changeCount
          offer.file = offer.file ?? file
          return merged(offer, source: source, at: date)
        }
      }
      return replace(
        Offer(changeCount: changeCount, file: file, source: source, updated: date))
    case .file(let file, let date):
      if savedFiles.contains(file) { return .ignore }
      if let saved = lastSavedClipboard, abs(date.timeIntervalSince(saved)) <= mergeWindow {
        return .ignore
      }
      if var offer = current, withinWindow(offer, date) {
        if offer.file == file { return .ignore }
        if offer.file == nil {
          offer.file = file
          return merged(offer, source: source, at: date)
        }
      }
      return replace(Offer(file: file, source: source, updated: date))
    }
  }

  public mutating func noteSaved(changeCount: Int?, file: URL?, at date: Date) {
    if let changeCount {
      Self.remember(changeCount, in: &savedCounts)
      lastSavedClipboard = date
    }
    if let file { Self.remember(file, in: &savedFiles) }
    guard let offer = current else { return }
    let sameCount = changeCount != nil && offer.changeCount == changeCount
    let sameFile = file != nil && offer.file == file
    if sameCount || sameFile { current = nil }
  }

  public mutating func noteOwn(changeCount: Int) {
    Self.remember(changeCount, in: &ownCounts)
    if current?.changeCount == changeCount { current = nil }
  }

  public mutating func expire(now: Date) -> Bool {
    guard let offer = current, now.timeIntervalSince(offer.updated) >= lifetime else {
      return false
    }
    current = nil
    return true
  }

  public mutating func take() -> Offer? {
    defer { current = nil }
    return current
  }

  private func withinWindow(_ offer: Offer, _ date: Date) -> Bool {
    abs(date.timeIntervalSince(offer.updated)) <= mergeWindow
  }

  private mutating func merged(_ offer: Offer, source: Source?, at date: Date) -> OfferUpdate {
    var offer = offer
    offer.source = offer.source ?? source
    offer.updated = max(offer.updated, date)
    current = offer
    return .update(offer)
  }

  private mutating func replace(_ offer: Offer) -> OfferUpdate {
    current = offer
    return .show(offer)
  }

  private static func remember<Value: Equatable>(_ value: Value, in list: inout [Value]) {
    list.removeAll { $0 == value }
    list.append(value)
    if list.count > Self.remembered { list.removeFirst() }
  }
}
