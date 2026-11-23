import Foundation
import Logging
import MCP

actor DrainingTransport: Transport {
  nonisolated let logger: Logger

  private let inner: any Transport
  private let stream: AsyncThrowingStream<Data, any Error>
  private let continuation: AsyncThrowingStream<Data, any Error>.Continuation
  private var pending: [ID: Int] = [:]
  private var inputEnded = false
  private var pump: Task<Void, Never>?

  static func wrapping(_ inner: any Transport) async -> DrainingTransport {
    DrainingTransport(inner, logger: await inner.logger)
  }

  private init(_ inner: any Transport, logger: Logger) {
    self.inner = inner
    self.logger = logger
    (stream, continuation) = AsyncThrowingStream.makeStream()
  }

  func connect() async throws {
    try await inner.connect()
    let incoming = await inner.receive()
    pump = Task { await forward(incoming) }
  }

  func disconnect() async {
    pump?.cancel()
    pump = nil
    continuation.finish()
    await inner.disconnect()
  }

  func send(_ data: Data) async throws {
    defer { answered(by: data) }
    try await inner.send(data)
  }

  func receive() -> AsyncThrowingStream<Data, any Error> {
    stream
  }

  private func forward(_ incoming: AsyncThrowingStream<Data, any Error>) async {
    do {
      for try await data in incoming {
        track(data)
        continuation.yield(data)
      }
    } catch {}
    inputEnded = true
    finishIfDrained()
  }

  private func track(_ data: Data) {
    let decoder = JSONDecoder()
    if (try? decoder.decode(Response<Probe>.self, from: data)) != nil { return }
    if let request = try? decoder.decode(Request<Probe>.self, from: data) {
      pending[request.id, default: 0] += 1
    } else if let cancelled = cancelledID(in: data) {
      pending[cancelled] = nil
      finishIfDrained()
    }
  }

  private func answered(by data: Data) {
    guard let response = try? JSONDecoder().decode(Response<Probe>.self, from: data) else {
      return
    }
    if let count = pending[response.id] {
      pending[response.id] = count > 1 ? count - 1 : nil
    }
    finishIfDrained()
  }

  private func finishIfDrained() {
    if inputEnded && pending.isEmpty { continuation.finish() }
  }

  private func cancelledID(in data: Data) -> ID? {
    guard
      let message = try? JSONDecoder().decode([String: Value].self, from: data),
      message["method"]?.stringValue == CancelledNotification.name,
      let requestID = message["params"]?.objectValue?["requestId"]
    else { return nil }
    if let string = requestID.stringValue { return .string(string) }
    return requestID.intValue.map { .number($0) }
  }
}

private enum Probe: MCP.Method {
  static var name: String { "" }
  typealias Parameters = Value
  typealias Result = Value
}
