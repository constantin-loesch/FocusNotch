import AppKit
import SwiftUI
import Combine

/// Randloses, transparentes Panel, das über der Menüleiste liegt.
final class IslandPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }
    override var canBecomeKey: Bool { false } // keine Tastatur-Fokusrahmen um die Buttons
    override var canBecomeMain: Bool { false }
}

/// Reagiert auf den ersten Klick, auch wenn das Panel nicht aktiv ist.
final class FirstMouseHostingView<V: View>: NSHostingView<V> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class IslandUIState: ObservableObject {
    @Published var isExpanded = false
    @Published var showSettings = false
    @Published var notchSize = CGSize(width: 190, height: 32)
    @Published var hasNotch = true

    /// Breite links und rechts neben der Notch im eingeklappten Zustand.
    static let sideWidth: CGFloat = 136

    func size() -> CGSize {
        if isExpanded {
            return CGSize(width: max(660, notchSize.width + 2 * Self.sideWidth + 80), height: notchSize.height + 200)
        }
        return CGSize(width: notchSize.width + 2 * Self.sideWidth, height: notchSize.height)
    }
}

@MainActor
final class IslandController {
    static let windowSize = CGSize(width: 760, height: 320)

    private let panel = IslandPanel()
    private let model = PomodoroModel()
    private let ui = IslandUIState()
    private var mouseTimer: Timer?
    private var enteredAt: Date?
    private var lastInside = Date.distantPast
    private var pinnedUntil = Date.distantPast

    init() {
        let root = IslandView()
            .environmentObject(model)
            .environmentObject(ui)
        let host = FirstMouseHostingView(rootView: root)
        host.sizingOptions = []
        panel.contentView = host
        layout()
        panel.orderFrontRegardless()

        // Nach Ende einer Phase kurz aufklappen
        // Befehle aus dem Widget (App Intents) – die App wird dabei nicht aktiviert
        for command in FocusCommand.all {
            DistributedNotificationCenter.default().addObserver(
                forName: FocusCommand.notificationName(command), object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { _ = self?.perform(command) }
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            MainActor.assumeIsolated { self?.previousApp = app }
        }

        model.onPhaseFinished = { [weak self] in
            self?.pinnedUntil = Date().addingTimeInterval(4)
        }

        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackMouse() }
        }
        RunLoop.main.add(t, forMode: .common)
        mouseTimer = t
    }

    /// Zuletzt aktive andere App – bekommt den Fokus nach einem Widget-Klick zurück.
    private var previousApp: NSRunningApplication?

    /// Steuerung über URL (vom Widget).
    func handle(url: URL) {
        guard url.scheme == "focusnotch", let command = url.host else { return }
        if command == "settings" {
            ui.showSettings = true
            ui.isExpanded = true
            pinnedUntil = Date().addingTimeInterval(8) // offen lassen, bis die Maus da ist
            return
        }
        // Timer-Aktionen: nichts aufklappen und den Fokus sofort zurückgeben
        if perform(command), NSApp.isActive, let app = previousApp, !app.isTerminated { app.activate() }
    }

    /// Führt einen Timer-Befehl aus. Gibt false zurück, wenn der Befehl unbekannt ist.
    @discardableResult
    func perform(_ command: String) -> Bool {
        switch command {
        case "start": model.start()
        case "toggle": model.togglePause()
        case "pause": model.pause()
        case "skip": model.skip()
        case "stop": model.cancel()
        default: return false
        }
        return true
    }

    private func targetScreen() -> NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    func layout() {
        let s = targetScreen()
        if s.safeAreaInsets.top > 0, let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
            ui.notchSize = CGSize(width: s.frame.width - l.width - r.width, height: s.safeAreaInsets.top)
            ui.hasNotch = true
        } else {
            let menuBar = s.frame.maxY - s.visibleFrame.maxY
            ui.notchSize = CGSize(width: 190, height: menuBar > 0 ? menuBar : 24)
            ui.hasNotch = false
        }
        let w = Self.windowSize
        panel.setFrame(NSRect(x: s.frame.midX - w.width / 2, y: s.frame.maxY - w.height,
                              width: w.width, height: w.height), display: true)
    }

    private func trackMouse() {
        let p = NSEvent.mouseLocation
        let f = panel.frame
        let size = ui.size()
        let pad: CGFloat = ui.isExpanded ? 14 : 2
        let hot = NSRect(x: f.midX - size.width / 2 - pad, y: f.maxY - size.height - pad,
                         width: size.width + 2 * pad, height: size.height + pad + 4)
        let inside = hot.contains(p)
        let now = Date()

        if inside {
            if enteredAt == nil { enteredAt = now }
            lastInside = now
        } else {
            enteredAt = nil
        }

        let dwellDone = enteredAt.map { now.timeIntervalSince($0) > 0.08 } ?? false
        let shouldExpand: Bool
        if ui.isExpanded {
            shouldExpand = inside || now < pinnedUntil || now.timeIntervalSince(lastInside) < 0.35
        } else {
            shouldExpand = dwellDone || now < pinnedUntil
        }

        if shouldExpand != ui.isExpanded {
            ui.isExpanded = shouldExpand
            if !shouldExpand { ui.showSettings = false }
        }
        panel.ignoresMouseEvents = !ui.isExpanded
    }
}
