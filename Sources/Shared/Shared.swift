import SwiftUI
import Foundation

// Code, den App und Widget gemeinsam nutzen.

enum Phase: String, Codable {
    case idle, focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .idle: return "Bereit"
        case .focus: return "Fokus"
        case .shortBreak: return "Kurze Pause"
        case .longBreak: return "Lange Pause"
        }
    }

    var isBreak: Bool { self == .shortBreak || self == .longBreak }
}

/// Die eine Akzentfarbe der App (in den Einstellungen wählbar).
enum AccentColor: String, Codable, CaseIterable, Identifiable {
    case orange, red, pink, purple, blue, teal, green, yellow

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
        }
    }

    /// Text-/Symbolfarbe auf der Akzentfarbe.
    var onAccent: Color { self == .yellow ? .black : .white }
}

/// URLs, mit denen das Widget die App steuert (focusnotch://start usw.).
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

// MARK: - Datenaustausch App → Widget

/// Zustand, den die App für das Widget als JSON ablegt.
struct WidgetSnapshot: Codable {
    var phase: Phase
    var endDate: Date?
    var pausedRemaining: TimeInterval?
    var duration: TimeInterval
    var focusMinutes: Int
    var todayFocus: TimeInterval   // bereits erfasste Fokuszeit heute (ohne laufende Phase)
    var todayBreak: TimeInterval   // bereits erfasste Pausenzeit heute (ohne laufende Phase)
    var days: [Int]                // abgeschlossene Sessions pro Tag, ältester zuerst, letzter = Tag von `updated`
    var accent: AccentColor
    var updated: Date

    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(phase: .idle, endDate: nil, pausedRemaining: nil, duration: 0, focusMinutes: 25,
                       todayFocus: 75 * 60, todayBreak: 15 * 60,
                       days: (0..<91).map { ($0 * 7 + $0 / 3) % 6 }, accent: .orange, updated: Date())
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

    /// Zustand zu einem bestimmten Zeitpunkt (abgelaufene Timer, Tageswechsel).
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
    /// ~/Library/Application Support/FocusNotch (auch aus der Widget-Sandbox der echte Home-Ordner).
    static var directory: URL {
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

// MARK: - Kästchen-Graph (Sessions pro Tag)

/// Spalten = Wochen (Mo oben), Kästchen = Tage. Die Farbstufen passen sich dem besten Tag im Zeitraum an.
struct HeatmapGrid: View {
    var days: [Int]            // ältester zuerst, letzter = heute
    var weeks: Int
    var cell: CGFloat
    var gap: CGFloat
    var color: Color
    var today: Date = Date()

    var body: some View {
        let maxCount = max(days.max() ?? 0, 1)
        let todayRow = (Calendar.current.component(.weekday, from: today) + 5) % 7 // Montag = 0
        HStack(spacing: gap) {
            ForEach(0..<weeks, id: \.self) { col in
                VStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { row in
                        cellView(daysAgo: (weeks - 1 - col) * 7 + (todayRow - row), maxCount: maxCount)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(daysAgo: Int, maxCount: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: cell * 0.25, style: .continuous)
        if daysAgo < 0 {
            Color.clear.frame(width: cell, height: cell) // Zukunft
        } else {
            let index = days.count - 1 - daysAgo
            let count = index >= 0 ? days[index] : 0
            shape
                .fill(count == 0 ? Color.white.opacity(0.09) : color.opacity(Self.opacity(count, maxCount)))
                .frame(width: cell, height: cell)
                .overlay(daysAgo == 0 ? shape.stroke(Color.white.opacity(0.7), lineWidth: 1) : nil)
                .help("\(count) Sessions")
        }
    }

    private static func opacity(_ count: Int, _ maxCount: Int) -> Double {
        let level = min(3, max(0, Int((Double(count) / Double(maxCount) * 4).rounded(.up)) - 1))
        return [0.35, 0.6, 0.8, 1.0][level]
    }
}
