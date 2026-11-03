import AppIntents
import AppKit

// Real widget buttons: they run inside the widget, don't open the app and
// trigger an immediate widget redraw (no 5-second throttle).

enum AppBridge {
    static let appBundleID = "de.constantin.focusnotch"

    /// Sends a command to the running app and briefly waits until it has written the new state.
    static func send(_ command: String) async {
        let before = modificationDate()
        if NSRunningApplication.runningApplications(withBundleIdentifier: appBundleID).isEmpty {
            NSWorkspace.shared.open(FocusURL.make(command)) // App not running: launch it via URL
        } else {
            DistributedNotificationCenter.default().postNotificationName(
                FocusCommand.notificationName(command), object: nil, userInfo: nil, deliverImmediately: true)
        }
        for _ in 0..<30 { // at most 1.5 s
            try? await Task.sleep(nanoseconds: 50_000_000)
            if modificationDate() != before { break }
        }
    }

    private static func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: SharedStore.fileURL.path))?[.modificationDate] as? Date
    }
}

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start or pause timer"
    static var isDiscoverable: Bool = false
    func perform() async throws -> some IntentResult {
        await AppBridge.send("toggle")
        return .result()
    }
}

struct SkipTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip timer"
    static var isDiscoverable: Bool = false
    func perform() async throws -> some IntentResult {
        await AppBridge.send("skip")
        return .result()
    }
}

struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop timer"
    static var isDiscoverable: Bool = false
    func perform() async throws -> some IntentResult {
        await AppBridge.send("stop")
        return .result()
    }
}
