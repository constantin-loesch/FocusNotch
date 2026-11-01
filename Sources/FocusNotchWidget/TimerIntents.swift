import AppIntents
import AppKit

// Echte Widget-Buttons: laufen im Widget, öffnen die App nicht und
// lösen sofort ein Neuzeichnen des Widgets aus (keine 5-Sekunden-Drossel).

enum AppBridge {
    static let appBundleID = "de.constantin.focusnotch"

    /// Schickt einen Befehl an die laufende App und wartet kurz, bis sie den neuen Stand geschrieben hat.
    static func send(_ command: String) async {
        let before = modificationDate()
        if NSRunningApplication.runningApplications(withBundleIdentifier: appBundleID).isEmpty {
            NSWorkspace.shared.open(FocusURL.make(command)) // App läuft nicht: per URL starten
        } else {
            DistributedNotificationCenter.default().postNotificationName(
                FocusCommand.notificationName(command), object: nil, userInfo: nil, deliverImmediately: true)
        }
        for _ in 0..<30 { // höchstens 1,5 s
            try? await Task.sleep(nanoseconds: 50_000_000)
            if modificationDate() != before { break }
        }
    }

    private static func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: SharedStore.fileURL.path))?[.modificationDate] as? Date
    }
}

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Timer starten oder anhalten"
    static var isDiscoverable: Bool = false
    func perform() async throws -> some IntentResult {
        await AppBridge.send("toggle")
        return .result()
    }
}

struct SkipTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Timer überspringen"
    static var isDiscoverable: Bool = false
    func perform() async throws -> some IntentResult {
        await AppBridge.send("skip")
        return .result()
    }
}

struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Timer stoppen"
    static var isDiscoverable: Bool = false
    func perform() async throws -> some IntentResult {
        await AppBridge.send("stop")
        return .result()
    }
}
