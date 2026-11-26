import AppKit

@MainActor
enum LaunchFailure {
  static func alert(for error: any Error) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = String(localized: "Thoughts can't start")
    alert.informativeText = error.localizedDescription
    return alert
  }

  static func show(
    _ alert: NSAlert, front: WindowFront = .live,
    run: @MainActor (NSAlert) -> Void = { _ = $0.runModal() }
  ) {
    alert.layout()
    front.bring(alert.window)
    run(alert)
  }
}
