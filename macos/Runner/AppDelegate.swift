import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let externalActivationQueueFileName = "pending_external_activations.jsonl"

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls where url.scheme?.lowercased() == "otzaria" {
      enqueueExternalActivation(url)
    }

    super.application(application, open: urls)
  }

  private func enqueueExternalActivation(_ url: URL) {
    do {
      let queueFileURL = try externalActivationQueueFileURL()
      try FileManager.default.createDirectory(
        at: queueFileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: nil
      )

      let payload: [String: String] = [
        "uri": url.absoluteString,
        "createdAt": ISO8601DateFormatter().string(from: Date()),
      ]
      let recordData = try JSONSerialization.data(withJSONObject: payload)
      var lineData = recordData
      lineData.append(Data("\n".utf8))

      if FileManager.default.fileExists(atPath: queueFileURL.path) {
        let fileHandle = try FileHandle(forWritingTo: queueFileURL)
        defer {
          try? fileHandle.close()
        }

        fileHandle.seekToEndOfFile()
        fileHandle.write(lineData)
      } else {
        try lineData.write(to: queueFileURL, options: .atomic)
      }
    } catch {
      NSLog("Failed to enqueue external activation: \(error)")
    }
  }

  private func externalActivationQueueFileURL() throws -> URL {
    guard let appSupportDirectory = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
    ).first else {
      throw NSError(
        domain: "OtzariaAppDelegate",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Application Support directory is unavailable"],
      )
    }

    return appSupportDirectory
      .appendingPathComponent("otzaria", isDirectory: true)
      .appendingPathComponent(externalActivationQueueFileName, isDirectory: false)
  }
}
