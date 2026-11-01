import AppKit
import Combine

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

struct PomodoroSettings: Codable, Equatable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var longBreakEvery = 4
    var dailyGoal = 8
    var autoStartBreak = true
    var sound = true
}

struct Session: Codable, Identifiable {
    var id = UUID()
    var end: Date
    var minutes: Int
}

private struct RunState: Codable {
    var phase: Phase
    var endDate: Date
    var duration: TimeInterval
    var cycleCount: Int
}

@MainActor
final class PomodoroModel: ObservableObject {
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var endDate: Date?
    @Published private(set) var phaseDuration: TimeInterval = 0
    @Published private(set) var now = Date()
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var cancelledCount = 0
    @Published var settings = PomodoroSettings() { didSet { save() } }

    /// Wird aufgerufen, wenn eine Phase von selbst endet (Fokus oder Pause).
    var onPhaseFinished: (() -> Void)?

    private var cycleCount = 0 // abgeschlossene Pomodoros seit der letzten langen Pause
    private var ticker: Timer?
    private let defaults = UserDefaults.standard
    private var isLoading = false

    init() {
        load()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    // MARK: Zustand

    var isActive: Bool { phase != .idle }

    var remaining: TimeInterval {
        guard let endDate else { return TimeInterval(settings.focusMinutes * 60) }
        return max(0, endDate.timeIntervalSince(now))
    }

    var progress: Double {
        guard phaseDuration > 0, isActive else { return 0 }
        return min(1, max(0, 1 - remaining / phaseDuration))
    }

    var remainingString: String {
        let total = Int(remaining.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    var phaseColor: NSColor {
        switch phase {
        case .idle: return .systemGray
        case .focus: return .systemOrange
        case .shortBreak, .longBreak: return .systemGreen
        }
    }

    // MARK: Aktionen

    func startFocus() {
        begin(.focus, minutes: settings.focusMinutes)
    }

    func cancel() {
        if phase == .focus { cancelledCount += 1 }
        stop()
    }

    func skipBreak() { stop() }

    private func begin(_ p: Phase, minutes: Int) {
        phase = p
        phaseDuration = TimeInterval(minutes * 60)
        now = Date()
        endDate = now.addingTimeInterval(phaseDuration)
        save()
    }

    private func stop() {
        phase = .idle
        endDate = nil
        phaseDuration = 0
        save()
    }

    private func tick() {
        now = Date()
        guard isActive, let endDate, now >= endDate else { return }
        finishPhase()
    }

    private func finishPhase() {
        if phase == .focus {
            sessions.append(Session(end: Date(), minutes: Int(phaseDuration / 60)))
            cycleCount += 1
            playSound("Glass")
            if settings.autoStartBreak {
                if cycleCount >= settings.longBreakEvery {
                    cycleCount = 0
                    begin(.longBreak, minutes: settings.longBreakMinutes)
                } else {
                    begin(.shortBreak, minutes: settings.shortBreakMinutes)
                }
            } else {
                stop()
            }
        } else {
            playSound("Hero")
            stop()
        }
        onPhaseFinished?()
    }

    private func playSound(_ name: String) {
        guard settings.sound else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    func resetRecord() {
        sessions = []
        cancelledCount = 0
        cycleCount = 0
        save()
    }

    // MARK: Record / Statistik

    private var cal: Calendar { Calendar.current }

    func count(on day: Date) -> Int {
        sessions.filter { cal.isDate($0.end, inSameDayAs: day) }.count
    }

    var todayCount: Int { count(on: now) }
    var todayMinutes: Int { sessions.filter { cal.isDateInToday($0.end) }.reduce(0) { $0 + $1.minutes } }
    var totalCount: Int { sessions.count }
    var totalMinutes: Int { sessions.reduce(0) { $0 + $1.minutes } }

    var bestDay: Int {
        Dictionary(grouping: sessions) { cal.startOfDay(for: $0.end) }.values.map(\.count).max() ?? 0
    }

    /// Aufeinanderfolgende Tage mit mindestens einem Pomodoro (heute zählt, sobald einer fertig ist).
    var streak: Int {
        let days = Set(sessions.map { cal.startOfDay(for: $0.end) })
        var day = cal.startOfDay(for: now)
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while days.contains(day) {
            n += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    /// Anzahl der Pomodoros der letzten 7 Tage (ältester zuerst).
    var lastSevenDays: [(date: Date, count: Int)] {
        (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: now))!
            return (d, count(on: d))
        }
    }

    // MARK: Speichern

    private func save() {
        guard !isLoading else { return }
        let enc = JSONEncoder()
        defaults.set(try? enc.encode(settings), forKey: "settings")
        defaults.set(try? enc.encode(sessions), forKey: "sessions")
        defaults.set(cancelledCount, forKey: "cancelled")
        if isActive, let endDate {
            let rs = RunState(phase: phase, endDate: endDate, duration: phaseDuration, cycleCount: cycleCount)
            defaults.set(try? enc.encode(rs), forKey: "run")
        } else {
            defaults.removeObject(forKey: "run")
            defaults.set(cycleCount, forKey: "cycle")
        }
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        let dec = JSONDecoder()
        if let d = defaults.data(forKey: "settings"), let s = try? dec.decode(PomodoroSettings.self, from: d) { settings = s }
        if let d = defaults.data(forKey: "sessions"), let s = try? dec.decode([Session].self, from: d) { sessions = s }
        cancelledCount = defaults.integer(forKey: "cancelled")
        cycleCount = defaults.integer(forKey: "cycle")
        // Laufenden Timer nach Neustart der App fortsetzen
        if let d = defaults.data(forKey: "run"), let rs = try? dec.decode(RunState.self, from: d), rs.endDate > Date() {
            phase = rs.phase
            endDate = rs.endDate
            phaseDuration = rs.duration
            cycleCount = rs.cycleCount
        }
    }
}
