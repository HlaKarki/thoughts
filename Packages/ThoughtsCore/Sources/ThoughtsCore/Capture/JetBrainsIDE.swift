public enum JetBrainsIDE {
  public static func isAny(_ bundleIDs: [String]) -> Bool {
    bundleIDs.contains { $0.hasPrefix("com.jetbrains.") || $0 == "com.google.android.studio" }
  }
}
