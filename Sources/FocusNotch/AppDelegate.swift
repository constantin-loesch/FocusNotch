import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: IslandController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        controller = IslandController()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.controller?.layout() }
        }
    }

    /// Klicks im Widget öffnen focusnotch://start, ://toggle, ://skip, ://stop
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { controller?.handle(url: url) }
    }
}
