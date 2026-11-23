import Foundation
import Vision

public protocol TextRecognizing: Sendable {
  func text(in image: URL) throws -> String
}

public struct VisionTextRecognizer: TextRecognizing {
  public init() {}

  public func text(in image: URL) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    do {
      try VNImageRequestHandler(url: image).perform([request])
    } catch {
      throw ThoughtsError.io("Text recognition failed: \(error.localizedDescription)")
    }
    let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    return lines.joined(separator: "\n")
  }
}
