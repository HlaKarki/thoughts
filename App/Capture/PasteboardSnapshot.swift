import AppKit

struct PasteboardSnapshot: Equatable, Sendable {
  let items: [[NSPasteboard.PasteboardType: Data]]

  static func take(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
    let items = (pasteboard.pasteboardItems ?? []).compactMap {
      item -> [NSPasteboard.PasteboardType: Data]? in
      var entries: [NSPasteboard.PasteboardType: Data] = [:]
      for type in item.types {
        if let data = item.data(forType: type) { entries[type] = data }
      }
      return entries.isEmpty ? nil : entries
    }
    return PasteboardSnapshot(items: items)
  }

  func restore(to pasteboard: NSPasteboard) -> Int {
    pasteboard.clearContents()
    let restored = items.map { entries -> NSPasteboardItem in
      let item = NSPasteboardItem()
      for (type, data) in entries { item.setData(data, forType: type) }
      return item
    }
    if !restored.isEmpty { pasteboard.writeObjects(restored) }
    return pasteboard.changeCount
  }
}
