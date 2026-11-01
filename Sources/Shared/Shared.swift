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

    /// Text-/Symbolfarbe auf der Akzentfarbe.
    var onAccent: Color { self == .yellow || self == .gray ? .black : .white }
}

/// Befehle vom Widget an die App per System-Benachrichtigung (ohne die App zu öffnen).
enum FocusCommand {
    static let all = ["start", "toggle", "skip", "stop"]
    static func notificationName(_ command: String) -> Notification.Name {
        Notification.Name("de.constantin.focusnotch.command.\(command)")
    }
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

// MARK: - Vorschau-Modus (Screenshots)

private struct PreviewModeKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// true beim Rendern außerhalb von WidgetKit: ersetzt Links/ProgressViews durch statische Ansichten.
    var focusPreviewMode: Bool {
        get { self[PreviewModeKey.self] }
        set { self[PreviewModeKey.self] = newValue }
    }
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
        // Für Screenshots/Tests umlenkbar, damit die echten Daten unberührt bleiben
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

// MARK: - Kästchen-Graph (Sessions der letzten 14 Tage)

/// Rollende 14 Tage: ein Kästchen pro Tag, ältester links oben, heute rechts unten.
/// Die Farbstufen passen sich dem besten Tag im Zeitraum an; die Zahl steht im Kästchen.
struct RollingSessionsGrid: View {
    static let dayCount = 14

    var days: [Int]            // ältester zuerst, letzter = heute (es zählen nur die letzten 14)
    var cell: CGFloat
    var gap: CGFloat
    var color: Color
    var numberColor: Color = .white
    var intensityScale: Double = 1 // < 1 im abgedunkelten Widget-Modus, damit die Zahlen lesbar bleiben

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
