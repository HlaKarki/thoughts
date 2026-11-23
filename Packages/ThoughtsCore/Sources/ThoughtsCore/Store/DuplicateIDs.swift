import Foundation

enum DuplicateIDs {
  static func owns(_ name: String, _ id: ThoughtID) -> Bool {
    let stem = (name as NSString).deletingPathExtension
    return stem == id.rawValue || stem.hasSuffix("-" + id.rawValue)
  }

  static func demotions(_ items: [(id: ThoughtID, name: String)]) -> [String: String] {
    var groups: [ThoughtID: [String]] = [:]
    for item in items { groups[item.id, default: []].append(item.name) }
    var demoted: [String: String] = [:]
    for (id, names) in groups where names.count > 1 {
      let owners = names.filter { owns($0, id) }
      if owners.count == 1 {
        for name in names where name != owners[0] {
          demoted[name] = "Duplicate id \(id), owned by \(owners[0])"
        }
      } else {
        let all = names.sorted().joined(separator: ", ")
        for name in names {
          demoted[name] = "Several files share the id \(id): \(all)"
        }
      }
    }
    return demoted
  }
}
