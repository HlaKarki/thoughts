public enum SourceRule {
  public static func app(
    frontmost: AppSnapshot?,
    history: [AppSnapshot],
    ownBundleID: String
  ) -> AppSnapshot? {
    if let frontmost, isUsable(frontmost, ownBundleID: ownBundleID) { return frontmost }
    return history.last { isUsable($0, ownBundleID: ownBundleID) }
  }

  private static func isUsable(_ app: AppSnapshot, ownBundleID: String) -> Bool {
    guard let bundleID = app.bundleID else { return true }
    return bundleID != ownBundleID && !ScreenshotTools.bundleIDs.contains(bundleID)
  }
}
