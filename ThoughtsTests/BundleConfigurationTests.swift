import Foundation
import Security
import Testing

@testable import Thoughts

struct BundleConfigurationTests {
  static let activationKeys: Set<String> = [
    "NSExtensionActivationSupportsText",
    "NSExtensionActivationSupportsWebURLWithMaxCount",
    "NSExtensionActivationSupportsImageWithMaxCount",
    "NSExtensionActivationSupportsFileWithMaxCount",
    "NSExtensionActivationSupportsAttachmentsWithMaxCount",
  ]

  static func shareExtension() throws -> Bundle {
    let plugIns = try #require(Bundle.main.builtInPlugInsURL)
    return try #require(Bundle(url: plugIns.appendingPathComponent("ThoughtsShare.appex")))
  }

  static func entitlements(of bundle: Bundle) -> [String: Any]? {
    var code: SecStaticCode?
    guard SecStaticCodeCreateWithPath(bundle.bundleURL as CFURL, [], &code) == errSecSuccess,
      let code
    else { return nil }
    var information: CFDictionary?
    guard
      SecCodeCopySigningInformation(
        code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess
    else { return nil }
    return (information as? [String: Any])?[kSecCodeInfoEntitlementsDict as String]
      as? [String: Any]
  }

  @Test func theAppAndTheShareExtensionAgreeOnTheGroupAndTheScheme() throws {
    let share = try Self.shareExtension()
    let group = try #require(
      Bundle.main.object(forInfoDictionaryKey: "ThoughtsAppGroup") as? String)
    #expect(!group.isEmpty && !group.contains("$("))
    #expect(share.object(forInfoDictionaryKey: "ThoughtsAppGroup") as? String == group)

    let types = try #require(
      Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]])
    let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    let scheme = try #require(share.object(forInfoDictionaryKey: "ThoughtsURLScheme") as? String)
    #expect(!scheme.isEmpty && !scheme.contains("$("))
    #expect(schemes.contains(scheme))
  }

  @Test func theShareExtensionDeclaresAnActivationRuleMacOSAccepts() throws {
    let share = try Self.shareExtension()
    let extensionInfo = try #require(
      share.object(forInfoDictionaryKey: "NSExtension") as? [String: Any])
    #expect(extensionInfo["NSExtensionPointIdentifier"] as? String == "com.apple.share-services")
    let attributes = try #require(extensionInfo["NSExtensionAttributes"] as? [String: Any])
    let rule = try #require(attributes["NSExtensionActivationRule"] as? [String: Any])
    #expect(!rule.isEmpty)
    #expect(Set(rule.keys).isSubset(of: Self.activationKeys))
  }

  @Test func theAppGroupEntitlementMatchesTheInfoPlistWhenTheBuildIsSigned() throws {
    let group = try #require(
      Bundle.main.object(forInfoDictionaryKey: "ThoughtsAppGroup") as? String)
    if let entitlements = Self.entitlements(of: Bundle.main) {
      let groups = entitlements["com.apple.security.application-groups"] as? [String]
      #expect(groups == [group])
    }
    if let entitlements = Self.entitlements(of: try Self.shareExtension()) {
      let groups = entitlements["com.apple.security.application-groups"] as? [String]
      #expect(groups == [group])
      #expect(entitlements["com.apple.security.app-sandbox"] as? Bool == true)
    }
  }
}
