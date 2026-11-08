import AppKit
import SwiftUI

// Renders the README images from the real app and widget views with demo data.
// Run via tools/screenshots.sh (redirects the widget data to a temporary folder).

let notch = CGSize(width: 185, height: 32)

@MainActor
enum Demo {
    /// Sessions of the last 14 days (last value = today)
    static let counts = [4, 6, 3, 0, 5, 8, 7, 2, 6, 4, 0, 5, 7, 3]

    /// Language of the screenshots (FOCUSNOTCH_LANG=de for German)
    static let language: AppLanguage = ProcessInfo.processInfo.environment["FOCUSNOTCH_LANG"] == "de" ? .de : .en

    static func prepare(running: Bool) {
        let d = UserDefaults.standard
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        var sessions: [Session] = []
        for (i, n) in counts.enumerated() {
            let day = cal.date(byAdding: .day, value: i - (counts.count - 1), to: today)!
            for k in 0..<n {
                let end = min(day.addingTimeInterval(9 * 3600 + Double(k) * 1800 + 1500), now.addingTimeInterval(-120))
                sessions.append(Session(end: end, seconds: 1500, kind: .focus, completed: true))
                sessions.append(Session(end: end.addingTimeInterval(60), seconds: 300, kind: .rest, completed: true))
            }
        }
        d.set(try? JSONEncoder().encode(sessions), forKey: "sessions")
        var settings = PomodoroSettings()
        settings.language = language
        d.set(try? JSONEncoder().encode(settings), forKey: "settings")
        d.set(true, forKey: "migratedFromPomodoroIsland")
        d.set(1, forKey: "cycle")
        if running { // Focus has been running for about 10 minutes
            let run: [String: Any] = ["phase": "focus", "duration": 1500, "cycleCount": 1,
                                      "endDate": now.addingTimeInterval(14 * 60 + 23).timeIntervalSinceReferenceDate]
            d.set(try? JSONSerialization.data(withJSONObject: run), forKey: "run")
        } else {
            d.removeObject(forKey: "run")
        }
    }
}

// MARK: - Stage

struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.09, green: 0.10, blue: 0.24),
                                    Color(red: 0.38, green: 0.16, blue: 0.42),
                                    Color(red: 0.93, green: 0.45, blue: 0.28)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(red: 1, green: 0.72, blue: 0.42).opacity(0.55), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 760)
            RadialGradient(colors: [Color(red: 0.32, green: 0.5, blue: 1).opacity(0.35), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 640)
        }
    }
}

struct MenuBar: View {
    static let clock: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "EEE MMM d  HH:mm"; return f
    }()

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "apple.logo").font(.system(size: 14, weight: .semibold))
            Text("Finder").fontWeight(.bold)
            Text("File"); Text("Edit")
            Spacer()
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text(Self.clock.string(from: Date()))
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(height: notch.height)
        .background(Color.black.opacity(0.2))
    }
}

/// Top edge of the screen with the island.
struct Screen: View {
    let model: PomodoroModel
    var expanded = false
    var settings = false
    var celebrating = false
    var menuBar = false

    var body: some View {
        let ui = IslandUIState()
        ui.notchSize = notch
        ui.isExpanded = expanded
        ui.showSettings = settings
        ui.celebrating = celebrating
        return ZStack(alignment: .top) {
            Wallpaper()
            if menuBar { MenuBar() }
            IslandView().environmentObject(model).environmentObject(ui)
                .environment(\.focusPreviewMode, true)
        }
    }
}

struct WidgetCard<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(15)
            .frame(width: width, height: height)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            .environment(\.focusPreviewMode, true)
            .environment(\.focusLanguage, Demo.language)
    }
}

struct Widgets: View {
    let idle: WidgetSnapshot
    let running: WidgetSnapshot

    var body: some View {
        let now = Date()
        HStack(spacing: 24) {
            WidgetCard(width: 164, height: 164) {
                SmallWidgetView(s: idle.resolved(at: now), date: now, accent: idle.accent)
            }
            WidgetCard(width: 344, height: 164) {
                MediumWidgetView(s: running.resolved(at: now), date: now, accent: running.accent)
            }
        }
    }
}

// MARK: - Rendering

@MainActor
func save(_ name: String, width: CGFloat, height: CGFloat, scale: CGFloat = 2, @ViewBuilder _ view: () -> some View) {
    let content = view()
        .frame(width: width, height: height)
        .environment(\.colorScheme, .dark)
    let renderer = ImageRenderer(content: content)
    renderer.scale = scale
    guard let cg = renderer.cgImage,
          let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
        fatalError("Rendering failed: \(name)")
    }
    let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("\(name).png")
    try! png.write(to: url)
    print("  \(url.path)")
}

MainActor.assumeIsolated {
    _ = NSApplication.shared

    Demo.prepare(running: true)
    let running = PomodoroModel()
    let runningSnap = SharedStore.read()!

    Demo.prepare(running: false)
    let idle = PomodoroModel()
    let idleSnap = SharedStore.read()!

    print("Images:")
    save("hero", width: 1280, height: 560) {
        ZStack(alignment: .top) {
            Screen(model: running, expanded: true, menuBar: true)
            Widgets(idle: idleSnap, running: runningSnap)
                .padding(.top, 300)
        }
    }
    save("island-idle", width: 760, height: 64) { Screen(model: idle) }
    save("island-running", width: 760, height: 64) { Screen(model: running) }
    save("island-expanded", width: 760, height: 210) { Screen(model: running, expanded: true) }
    save("island-complete", width: 760, height: 140) { Screen(model: idle, celebrating: true) }
    save("island-settings", width: 760, height: 270) { Screen(model: idle, expanded: true, settings: true) }
    save("widgets", width: 640, height: 230) {
        ZStack { Wallpaper(); Widgets(idle: idleSnap, running: runningSnap) }
    }

    // GitHub social preview (1280×640, shown when the repo link is shared)
    save("social-preview", width: 1280, height: 640, scale: 1) {
        ZStack {
            Wallpaper()
            Color.black.opacity(0.25)
            HStack(spacing: 56) {
                VStack(alignment: .leading, spacing: 18) {
                    AppIconView(size: 190)
                        .padding(.leading, -22)
                    Text("FocusNotch")
                        .font(.system(size: 76, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("A Pomodoro timer in your\nMacBook's notch – with a\ndesktop widget.")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(4)
                }
                VStack(spacing: 36) {
                    Screen(model: running)
                        .frame(width: 520, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
                    WidgetCard(width: 344, height: 164) {
                        MediumWidgetView(s: runningSnap.resolved(at: Date()), date: Date(), accent: runningSnap.accent)
                    }
                    .scaleEffect(1.3)
                    .padding(.vertical, 24)
                }
            }
        }
    }

    // All accent colors (collapsed, timer running)
    var strips: [(AccentColor, PomodoroModel)] = []
    for c in AccentColor.allCases {
        Demo.prepare(running: true)
        let m = PomodoroModel()
        m.settings.accent = c
        strips.append((c, m))
    }
    save("colors", width: 3 * 470 + 2 * 14 + 40, height: 3 * 64 + 2 * 14 + 40) {
        ZStack {
            Color(white: 0.08)
            VStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { col in
                            Screen(model: strips[row * 3 + col].1).frame(width: 470, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                    }
                }
            }
        }
    }
}
