import Testing

@testable import ThoughtsCore

struct JetBrainsIDETests {
  @Test(
    arguments: [
      (["com.jetbrains.pycharm"], true),
      (["com.apple.Safari", "com.google.android.studio"], true),
      (["com.microsoft.VSCode"], false),
      ([], false),
    ] as [([String], Bool)])
  func recognizesJetBrainsAndAndroidStudio(_ bundleIDs: [String], _ expected: Bool) {
    #expect(JetBrainsIDE.isAny(bundleIDs) == expected)
  }
}
