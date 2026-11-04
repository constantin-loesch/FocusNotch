import SwiftUI
import Foundation

// Code shared by the app and the widget.

/// UI language (switchable in settings; defaults to the Mac's system language).
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case en, de

    var id: String { rawValue }

    static var system: AppLanguage {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("de") ? .de : .en
    }

    /// Name of the language in that language.
    var name: String { self == .de ? "Deutsch" : "English" }

    /// Picks the English or German text.
    func pick(_ en: String, _ de: String) -> String { self == .de ? de : en }

    /// Long date, e.g. "Sunday, November 1" / "Sonntag, 1. November".
    func longDate(_ date: Date) -> String {
        (self == .de ? Self.deDate : Self.enDate).string(from: date)
    }

    private static let enDate: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "EEEE, MMMM d"; return f
    }()
    private static let deDate: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEEE, d. MMMM"; return f
    }()
}

enum Phase: String, Codable {
    case idle, focus, shortBreak, longBreak

    func title(_ lang: AppLanguage) -> String {
        switch self {
        case .idle: return lang.pick("Ready", "Bereit")
        case .focus: return lang.pick("Focus", "Fokus")
        case .shortBreak: return lang.pick("Short Break", "Kurze Pause")
        case .longBreak: return lang.pick("Long Break", "Lange Pause")
        }
    }

    var isBreak: Bool { self == .shortBreak || self == .longBreak }
}

/// The app's single accent color (selectable in settings).
enum AccentColor: String, Codable, CaseIterable, Identifiable {
    case orange, red, pink, purple, blue, teal, green, yellow, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .orange: return Color(red: 1.00, green: 0.58, blue: 0.00)
        case .red:    return Color(red: 1.00, green: 0.27, blue: 0.23)
        case .pink:   return Color(red: 1.00, green: 0.22, blue: 0.47)
        case .purple: return Color(red: 0.69, green: 0.35, blue: 0.97)
        case .blue:   return Color(red: 0.04, green: 0.52, blue: 1.00)
        case .teal:   return Color(red: 0.19, green: 0.78, blue: 0.85)
        case .green:  return Color(red: 0.20, green: 0.84, blue: 0.29)
        case .yellow: return Color(red: 1.00, green: 0.80, blue: 0.00)
        case .gray:   return Color(red: 0.56, green: 0.56, blue: 0.60)
        }
    }

    /// Text/icon color on top of the accent color.
    var onAccent: Color { self == .yellow || self == .gray ? .black : .white }
}

/// Commands from the widget to the app via system notification (without opening the app).
enum FocusCommand {
    static let all = ["start", "toggle", "skip", "stop"]
    static func notificationName(_ command: String) -> Notification.Name {
        Notification.Name("de.constantin.focusnotch.command.\(command)")
    }
}

/// URLs the widget uses to control the app (focusnotch://start etc.).
enum FocusURL {
    static func make(_ action: String) -> URL { URL(string: "focusnotch://\(action)")! }
}

func formatClock(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds).rounded(.up))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let m = Int(max(0, seconds) / 60)
    if m < 60 { return "\(m) min" }
    return m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min"
}

// MARK: - Preview mode (screenshots)

private struct PreviewModeKey: EnvironmentKey { static let defaultValue = false }
private struct LanguageKey: EnvironmentKey { static let defaultValue = AppLanguage.system }

extension EnvironmentValues {
    /// UI language for the widget views.
    var focusLanguage: AppLanguage {
        get { self[LanguageKey.self] }
        set { self[LanguageKey.self] = newValue }
    }

    /// true when rendering outside WidgetKit: replaces links/progress views with static views.
    var focusPreviewMode: Bool {
        get { self[PreviewModeKey.self] }
        set { self[PreviewModeKey.self] = newValue }
    }
}

// MARK: - Data exchange app → widget

/// State the app stores as JSON for the widget.
struct WidgetSnapshot: Codable {
    var phase: Phase
    var endDate: Date?
    var pausedRemaining: TimeInterval?
    var duration: TimeInterval
    var focusMinutes: Int
    var todayFocus: TimeInterval   // focus time logged today (without the running phase)
    var todayBreak: TimeInterval   // break time logged today (without the running phase)
    var days: [Int]                // completed sessions per day, oldest first, last = day of `updated`
    var accent: AccentColor
    var language: AppLanguage? // optional: older snapshots don't have it
    var updated: Date

    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(phase: .idle, endDate: nil, pausedRemaining: nil, duration: 0, focusMinutes: 25,
                       todayFocus: 75 * 60, todayBreak: 15 * 60,
                       days: (0..<91).map { ($0 * 7 + $0 / 3) % 6 }, accent: .orange, language: nil, updated: Date())
    }

    struct Resolved {
        var phase: Phase
        var endDate: Date?
        var paused: Bool
        var remaining: TimeInterval
        var duration: TimeInterval
        var todayFocus: TimeInterval
        var todayBreak: TimeInterval
        var days: [Int]
        var isActive: Bool { phase != .idle }
        var isRunning: Bool { isActive && !paused }
    }

    /// State at a given point in time (expired timers, day change).
    func resolved(at date: Date) -> Resolved {
        var r = Resolved(phase: phase, endDate: endDate, paused: pausedRemaining != nil, remaining: 0,
                         duration: duration, todayFocus: todayFocus, todayBreak: todayBreak, days: days)
        if phase != .idle, pausedRemaining == nil, (endDate ?? .distantPast) <= date {
            r.phase = .idle; r.endDate = nil; r.paused = false
        }
        if r.phase == .idle {
            r.remaining = TimeInterval(focusMinutes * 60)
            r.duration = r.remaining
        } else if let p = pausedRemaining {
            r.remaining = p
        } else if let e = endDate {
            r.remaining = e.timeIntervalSince(date)
        }
        let cal = Calendar.current
        let shift = cal.dateComponents([.day], from: cal.startOfDay(for: updated), to: cal.startOfDay(for: date)).day ?? 0
        if shift > 0 {
            r.todayFocus = 0
            r.todayBreak = 0
            r.days = Array(days.dropFirst(min(shift, days.count))) + Array(repeating: 0, count: min(shift, days.count))
        } else if r.isActive {
            let elapsed = max(0, r.duration - r.remaining)
            if r.phase == .focus { r.todayFocus += elapsed } else { r.todayBreak += elapsed }
        }
        return r
    }
}

enum SharedStore {
    /// ~/Library/Application Support/FocusNotch (the real home folder, even from the widget sandbox).
    static var directory: URL {
        // Can be redirected for screenshots/tests so the real data stays untouched
        if let dir = ProcessInfo.processInfo.environment["FOCUSNOTCH_SHARED_DIR"] { return URL(fileURLWithPath: dir) }
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/FocusNotch", isDirectory: true)
    }

    static var fileURL: URL { directory.appendingPathComponent("widget.json") }

    static func write(_ snapshot: WidgetSnapshot) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: fileURL, options: .atomic) }
    }

    static func read() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

// MARK: - Box grid (sessions of the last 14 days)

/// Rolling 14 days: one box per day, oldest top left, today bottom right.
/// Color levels scale to the best day in the period; the count is shown in the box.
struct RollingSessionsGrid: View {
    static let dayCount = 14

    var days: [Int]            // oldest first, last = today (only the last 14 count)
    var cell: CGFloat
    var gap: CGFloat
    var color: Color
    var numberColor: Color = .white
    var intensityScale: Double = 1 // < 1 in the dimmed widget mode so the numbers stay readable

    var body: some View {
        let last = Array(days.suffix(Self.dayCount))
        let padded = Array(repeating: 0, count: max(0, Self.dayCount - last.count)) + last
        let maxCount = max(padded.max() ?? 0, 1)
        VStack(spacing: gap) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { col in
                        let i = row * 7 + col
                        cellView(count: padded[i], isToday: i == Self.dayCount - 1, maxCount: maxCount)
                    }
                }
            }
        }
    }

    private func cellView(count: Int, isToday: Bool, maxCount: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: cell * 0.28, style: .continuous)
        return shape
            .fill(count == 0 ? Color.white.opacity(0.09) : color.opacity(Self.opacity(count, maxCount) * intensityScale))
            .frame(width: cell, height: cell)
            .overlay {
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: cell * 0.48, weight: .bold, design: .rounded))
                        .foregroundStyle(numberColor)
                        .minimumScaleFactor(0.5)
                }
            }
            .overlay(isToday ? shape.stroke(Color.white.opacity(0.7), lineWidth: 1) : nil)
    }

    private static func opacity(_ count: Int, _ maxCount: Int) -> Double {
        let level = min(3, max(0, Int((Double(count) / Double(maxCount) * 4).rounded(.up)) - 1))
        return [0.35, 0.6, 0.8, 1.0][level]
    }
}
