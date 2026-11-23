public enum CopyFallbackPolicy {
  public static let copiesWithoutSelection: Set<String> = [
    "com.microsoft.VSCode",
    "com.todesktop.230313mzl4w4u92",
    "com.sublimetext.4",
    "com.sublimetext.3",
    "com.google.android.studio",
    "com.microsoft.Excel",
    "com.apple.Numbers",
  ]

  public static let copiesWithoutSelectionPrefixes: [String] = ["com.jetbrains."]

  public static func allowed(bundleID: String?, ownBundleID: String) -> Bool {
    guard let bundleID else { return true }
    if bundleID == ownBundleID { return false }
    if copiesWithoutSelection.contains(bundleID) { return false }
    return !copiesWithoutSelectionPrefixes.contains { bundleID.hasPrefix($0) }
  }
}
