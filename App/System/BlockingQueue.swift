import Foundation

struct BlockingQueue: Sendable {
  private let queue: DispatchQueue

  init(_ label: String, concurrent: Bool = false) {
    queue = DispatchQueue(label: label, attributes: concurrent ? [.concurrent] : [])
  }

  func run<T: Sendable, E: Error>(
    isolation: isolated (any Actor)? = #isolation,
    _ work: @escaping @Sendable () throws(E) -> T
  ) async throws(E) -> T {
    let result = await withCheckedContinuation {
      (continuation: CheckedContinuation<Result<T, E>, Never>) in
      queue.async { continuation.resume(returning: Result(catching: work)) }
    }
    return try result.get()
  }
}
