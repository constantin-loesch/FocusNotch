import AppKit
import SwiftUI
import WidgetKit

struct PomodoroSettings: Codable, Equatable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var longBreakEvery = 4
    var autoStartBreak = true
    var sound = true
    var accent: AccentColor = .orange
    var language: AppLanguage = .system

    init() {}

    // Fill missing/old fields with defaults one by one
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PomodoroSettings()
        focusMinutes = (try? c.decodeIfPresent(Int.self, forKey: .focusMinutes)) ?? d.focusMinutes
        shortBreakMinutes = (try? c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes)) ?? d.shortBreakMinutes
        longBreakMinutes = (try? c.decodeIfPresent(Int.self, forKey: .longBreakMinutes)) ?? d.longBreakMinutes
        longBreakEvery = (try? c.decodeIfPresent(Int.self, forKey: .longBreakEvery)) ?? d.longBreakEvery
        autoStartBreak = (try? c.decodeIfPresent(Bool.self, forKey: .autoStartBreak)) ?? d.autoStartBreak
        sound = (try? c.decodeIfPresent(Bool.self, forKey: .sound)) ?? d.sound
        accent = (try? c.decodeIfPresent(AccentColor.self, forKey: .accent)) ?? d.accent
        language = (try? c.decodeIfPresent(AppLanguage.self, forKey: .language)) ?? d.language
    }
}

/// A history entry: a focus or break phase (complete or partial).
struct Session: Codable, Identifiable {
    enum Kind: String, Codable { case focus, rest }

    var id = UUID()
    var end: Date
    var seconds: TimeInterval
    var kind: Kind = .focus
    var completed = true

    init(end: Date, seconds: TimeInterval, kind: Kind, completed: Bool) {
        self.end = end
        self.seconds = seconds
        self.kind = kind
        self.completed = completed
    }

    private enum CodingKeys: String, CodingKey { case id, end, seconds, kind, completed, minutes }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        end = try c.decode(Date.self, forKey: .end)
        if let s = try c.decodeIfPresent(TimeInterval.self, forKey: .seconds) {
            seconds = s
        } else { // old format: minutes only
            seconds = TimeInterval(try c.decodeIfPresent(Int.self, forKey: .minutes) ?? 0) * 60
        }
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .focus
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(end, forKey: .end)
        try c.encode(seconds, forKey: .seconds)
        try c.encode(kind, forKey: .kind)
        try c.encode(completed, forKey: .completed)
    }
}

private struct RunState: Codable {
    var phase: Phase
    var endDate: Date?
    var pausedRemaining: TimeInterval?
    var duration: TimeInterval
    var cycleCount: Int
}

@MainActor
final class PomodoroModel: ObservableObject {
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var endDate: Date?                 // set while the timer is running
    @Published private(set) var pausedRemaining: TimeInterval? // set while it is paused
    @Published private(set) var phaseDuration: TimeInterval = 0
    @Published private(set) var now = Date()
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var cancelledCount = 0
    @Published var settings = PomodoroSettings() { didSet { save() } }

    /// Called when a phase ends on its own.
    var onPhaseFinished: ((Phase) -> Void)?

    private var cycleCount = 0 // completed Pomodoros since the last long break
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
        save() // Give the widget the current state right away
    }

    // MARK: State

    var isActive: Bool { phase != .idle }
    var isPaused: Bool { isActive && pausedRemaining != nil }
    var isRunning: Bool { isActive && pausedRemaining == nil }
    var accent: Color { settings.accent.color }
    var onAccent: Color { settings.accent.onAccent }

    var remaining: TimeInterval {
        if let pausedRemaining { return pausedRemaining }
        if let endDate { return max(0, endDate.timeIntervalSince(now)) }
        return TimeInterval(settings.focusMinutes * 60)
    }

    var elapsed: TimeInterval { isActive ? max(0, phaseDuration - remaining) : 0 }

    var progress: Double {
        guard isActive, phaseDuration > 0 else { return 0 }
        return min(1, max(0, elapsed / phaseDuration))
    }

    var remainingString: String { formatClock(remaining) }
    var lang: AppLanguage { settings.language }
    var phaseLabel: String { isPaused ? lang.pick("Paused", "Pausiert") : phase.title(lang) }

    // MARK: Actions

    /// Starts a focus timer or resumes a paused one.
    func start() {
        if !isActive { begin(.focus, minutes: settings.focusMinutes) } else if isPaused { resume() }
    }

    func togglePause() {
        if !isActive { start() } else if isPaused { resume() } else { pause() }
    }

    func pause() {
        guard isRunning else { return }
        now = Date()
        pausedRemaining = remaining
        endDate = nil
        save()
    }

    func resume() {
        guard isActive, let r = pausedRemaining else { return }
        now = Date()
        endDate = now.addingTimeInterval(r)
        pausedRemaining = nil
        save()
    }

    /// Focus → straight to the break. Break → end it.
    func skip() {
        guard isActive else { return }
        now = Date()
        if phase == .focus {
            log(.focus, seconds: elapsed, completed: false)
            startBreak()
        } else {
            log(.rest, seconds: elapsed, completed: false)
            stop()
        }
    }

    /// Stop the timer completely.
    func cancel() {
        guard isActive else { return }
        now = Date()
        if phase == .focus {
            cancelledCount += 1
            log(.focus, seconds: elapsed, completed: false)
        } else {
            log(.rest, seconds: elapsed, completed: false)
        }
        stop()
    }

    private func begin(_ p: Phase, minutes: Int) {
        phase = p
        phaseDuration = TimeInterval(minutes * 60)
        now = Date()
        endDate = now.addingTimeInterval(phaseDuration)
        pausedRemaining = nil
        save()
    }

    private func startBreak() {
        if cycleCount >= settings.longBreakEvery {
            cycleCount = 0
            begin(.longBreak, minutes: settings.longBreakMinutes)
        } else {
            begin(.shortBreak, minutes: settings.shortBreakMinutes)
        }
    }

    private func stop() {
        phase = .idle
        endDate = nil
        pausedRemaining = nil
        phaseDuration = 0
        save()
    }

    private func log(_ kind: Session.Kind, seconds: TimeInterval, completed: Bool) {
        guard seconds >= 1 else { return }
        sessions.append(Session(end: Date(), seconds: seconds, kind: kind, completed: completed))
    }

    private func tick() {
        now = Date()
        guard isRunning, let endDate, now >= endDate else { return }
        finishPhase()
    }

    private func finishPhase() {
        let finished = phase
        if phase == .focus {
            log(.focus, seconds: phaseDuration, completed: true)
            cycleCount += 1
            playSound("Glass")
            if settings.autoStartBreak { startBreak() } else { stop() }
        } else {
            log(.rest, seconds: phaseDuration, completed: true)
            playSound("Hero")
            stop()
        }
        onPhaseFinished?(finished)
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

    // MARK: Statistics

    private var cal: Calendar { Calendar.current }

    private func logged(_ kind: Session.Kind, on day: Date) -> TimeInterval {
        sessions.filter { $0.kind == kind && cal.isDate($0.end, inSameDayAs: day) }.reduce(0) { $0 + $1.seconds }
    }

    /// Focus time today (including the running focus phase).
    var todayFocus: TimeInterval { logged(.focus, on: now) + (phase == .focus ? elapsed : 0) }

    /// Break time today (including the running break).
    var todayBreak: TimeInterval { logged(.rest, on: now) + (phase.isBreak ? elapsed : 0) }

    /// Completed focus sessions per day, oldest first, last = today.
    func dailyCounts(days n: Int) -> [Int] {
        var counts: [Date: Int] = [:]
        for s in sessions where s.kind == .focus && s.completed {
            counts[cal.startOfDay(for: s.end), default: 0] += 1
        }
        let today = cal.startOfDay(for: now)
        return (0..<n).reversed().map { counts[cal.date(byAdding: .day, value: -$0, to: today)!] ?? 0 }
    }

    // MARK: Persistence

    private func save() {
        guard !isLoading else { return }
        let enc = JSONEncoder()
        defaults.set(try? enc.encode(settings), forKey: "settings")
        defaults.set(try? enc.encode(sessions), forKey: "sessions")
        defaults.set(cancelledCount, forKey: "cancelled")
        defaults.set(cycleCount, forKey: "cycle")
        if isActive {
            let rs = RunState(phase: phase, endDate: endDate, pausedRemaining: pausedRemaining,
                              duration: phaseDuration, cycleCount: cycleCount)
            defaults.set(try? enc.encode(rs), forKey: "run")
        } else {
            defaults.removeObject(forKey: "run")
        }

        let today = Date()
        SharedStore.write(WidgetSnapshot(
            phase: phase, endDate: endDate, pausedRemaining: pausedRemaining, duration: phaseDuration,
            focusMinutes: settings.focusMinutes,
            todayFocus: logged(.focus, on: today), todayBreak: logged(.rest, on: today),
            days: dailyCounts(days: RollingSessionsGrid.dayCount), accent: settings.accent,
            language: settings.language, updated: today))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Migrates settings and history from the old "Pomodoro Island" app (once).
    private func migrateFromPomodoroIsland() {
        guard !defaults.bool(forKey: "migratedFromPomodoroIsland") else { return }
        defaults.set(true, forKey: "migratedFromPomodoroIsland")
        guard defaults.data(forKey: "sessions") == nil,
              let old = UserDefaults(suiteName: "de.constantin.pomodoroisland") else { return }
        for key in ["settings", "sessions", "cancelled", "cycle", "run"] {
            if let value = old.object(forKey: key) { defaults.set(value, forKey: key) }
        }
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        migrateFromPomodoroIsland()
        let dec = JSONDecoder()
        if let d = defaults.data(forKey: "settings"), let s = try? dec.decode(PomodoroSettings.self, from: d) { settings = s }
        if let d = defaults.data(forKey: "sessions"), let s = try? dec.decode([Session].self, from: d) { sessions = s }
        cancelledCount = defaults.integer(forKey: "cancelled")
        cycleCount = defaults.integer(forKey: "cycle")
        // Resume a running or paused timer after a restart
        if let d = defaults.data(forKey: "run"), let rs = try? dec.decode(RunState.self, from: d) {
            if let p = rs.pausedRemaining {
                phase = rs.phase; pausedRemaining = p; endDate = nil
                phaseDuration = rs.duration; cycleCount = rs.cycleCount
            } else if let e = rs.endDate, e > Date() {
                phase = rs.phase; endDate = e
                phaseDuration = rs.duration; cycleCount = rs.cycleCount
            }
        }
    }
}
