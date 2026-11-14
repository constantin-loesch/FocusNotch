import SwiftUI
import ServiceManagement

// MARK: - Island shape (like the notch: rounded at the bottom, slightly flared at the top)

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        let t = topRadius, b = min(bottomRadius, r.height - t)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + t, y: r.minY + t), control: CGPoint(x: r.minX + t, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + t, y: r.maxY - b))
        p.addQuadCurve(to: CGPoint(x: r.minX + t + b, y: r.maxY), control: CGPoint(x: r.minX + t, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - t - b, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - t, y: r.maxY - b), control: CGPoint(x: r.maxX - t, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - t, y: r.minY + t))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - t, y: r.minY))
        p.closeSubpath()
        return p
    }
}

private let spring = Animation.spring(response: 0.38, dampingFraction: 0.8)

// MARK: - Root

struct IslandView: View {
    @EnvironmentObject var model: PomodoroModel
    @EnvironmentObject var ui: IslandUIState

    var body: some View {
        let size = ui.size()
        let t: CGFloat = ui.isExpanded ? 12 : 6

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(topRadius: t, bottomRadius: ui.isExpanded ? 26 : (ui.celebrating || ui.askNextSession ? 22 : 10))
                    .fill(Color.black)
                    .frame(width: size.width, height: size.height)
                    .shadow(color: .black.opacity(ui.isExpanded ? 0.45 : 0), radius: 14, y: 6)

                VStack(spacing: 0) {
                    HeaderRow(leftWidth: max(0, ui.sides.left - t), rightWidth: max(0, ui.sides.right - t))
                    if ui.isExpanded {
                        Group {
                            if ui.showSettings { SettingsView() } else { MainPanel() }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, ui.showSettings ? 8 : 4)
                        .padding(.bottom, ui.showSettings ? 18 : 14)
                        .frame(maxHeight: .infinity)
                        .transition(.opacity)
                    } else if ui.askNextSession {
                        NextSessionPrompt()
                            .frame(maxHeight: .infinity)
                            .transition(.opacity)
                    } else if ui.celebrating {
                        FocusCompleteView()
                            .frame(maxHeight: .infinity)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, t)
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipped()
            }
            .offset(x: ui.offsetX)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .animation(spring, value: ui.isExpanded)
        .animation(spring, value: ui.showSettings)
        .animation(spring, value: ui.celebrating)
        .animation(spring, value: ui.askNextSession)
        .animation(spring, value: model.settings.showProgressBar)
        .animation(spring, value: ui.compactRight)
        .animation(spring, value: model.phase)
        .animation(spring, value: model.isPaused)
        .preferredColorScheme(.dark)
        .focusEffectDisabled()
    }
}

// MARK: - Header next to the notch (always visible)
// Left: [Start/Pause] [Skip] time – right next to the camera. Right: progress bar.
// The controls stay in place when expanding, so you can click right away.

struct HeaderRow: View {
    @EnvironmentObject var model: PomodoroModel
    @EnvironmentObject var ui: IslandUIState
    var leftWidth: CGFloat
    var rightWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                if ui.isExpanded {
                    HStack(spacing: 6) {
                        Circle().fill(model.accent.opacity(model.isActive ? 1 : 0.35)).frame(width: 7, height: 7)
                        Text(model.phaseLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                    .transition(.opacity)
                }
                Spacer(minLength: 0)
                TimerButtons(size: 22)
                Text(model.remainingString)
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(model.isPaused ? 0.45 : (model.isActive ? 1 : 0.8)))
                    .contentTransition(.numericText(countsDown: true))
                    .fixedSize()
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .frame(width: leftWidth)

            Color.clear.frame(width: ui.notchSize.width)

            HStack(spacing: 14) {
                if model.settings.showProgressBar {
                    ProgressBar(progress: model.progress, color: model.accent)
                        .frame(width: 72, height: 5)
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                if ui.isExpanded {
                    IconButton(symbol: ui.showSettings ? "xmark" : "gearshape.fill") { ui.showSettings.toggle() }
                    IconButton(symbol: "power") { NSApp.terminate(nil) }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .frame(width: rightWidth)
            .clipped()
        }
        .frame(height: ui.notchSize.height)
    }
}

/// Start / Pause / Resume + Skip.
struct TimerButtons: View {
    @EnvironmentObject var model: PomodoroModel
    var size: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            CircleButton(symbol: model.isRunning ? "pause.fill" : "play.fill",
                         fill: model.accent, foreground: model.onAccent, size: size,
                         help: model.isRunning ? model.lang.pick("Pause", "Anhalten") : (model.isPaused ? model.lang.pick("Resume", "Fortsetzen") : model.lang.pick("Start", "Starten"))) {
                model.togglePause()
            }
            if model.isActive {
                CircleButton(symbol: "forward.fill", fill: .white.opacity(0.16), foreground: .white, size: size,
                             help: model.phase == .focus ? model.lang.pick("Skip to break", "Zur Pause springen") : model.lang.pick("Skip break", "Pause überspringen")) {
                    model.skip()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

/// Horizontal progress bar to the right of the notch.
struct ProgressBar: View {
    var progress: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(color)
                    .frame(width: max(progress > 0 ? geo.size.height : 0, geo.size.width * progress))
                    .animation(.linear(duration: 0.5), value: progress)
            }
        }
    }
}

struct ProgressRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)
        }
    }
}

// MARK: - Focus complete

/// Green check that draws itself: circle → check → small bounce.
struct FocusCompleteView: View {
    @EnvironmentObject var model: PomodoroModel
    /// Screenshots: show the finished state right away
    @Environment(\.focusPreviewMode) private var previewMode

    @State private var ring: CGFloat = 0
    @State private var check: CGFloat = 0
    @State private var pop: CGFloat = 0.6

    static let green = Color(red: 0.20, green: 0.84, blue: 0.35)

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Self.green.opacity(0.18))
                Circle()
                    .trim(from: 0, to: previewMode ? 1 : ring)
                    .stroke(Self.green, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                CheckmarkShape()
                    .trim(from: 0, to: previewMode ? 1 : check)
                    .stroke(Self.green, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                    .padding(13)
            }
            .frame(width: 46, height: 46)
            .scaleEffect(previewMode ? 1 : pop)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.lang.pick("Focus complete!", "Fokus geschafft!"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(model.phase.isBreak
                     ? model.lang.pick("Time for a break", "Zeit für eine Pause")
                     : model.lang.pick("+1 session", "+1 Session"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .opacity(previewMode || check > 0 ? 1 : 0)
            .offset(x: previewMode || check > 0 ? 0 : -6)
        }
        .padding(.bottom, 6)
        .onAppear {
            guard !previewMode else { ring = 1; check = 1; pop = 1; return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { pop = 1 }
            withAnimation(.easeOut(duration: 0.45).delay(0.15)) { ring = 1 }
            withAnimation(.easeOut(duration: 0.35).delay(0.55)) { check = 1 }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45).delay(0.9)) { pop = 1.12 }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(1.1)) { pop = 1 }
        }
    }
}

// MARK: - Break over: next session?

/// Two big round buttons (red X = no, green check = yes); either one closes the island.
struct NextSessionPrompt: View {
    @EnvironmentObject var model: PomodoroModel
    @EnvironmentObject var ui: IslandUIState
    @Environment(\.focusPreviewMode) private var previewMode
    @State private var shown = false

    static let red = Color(red: 1.0, green: 0.30, blue: 0.27)

    var body: some View {
        let visible = previewMode || shown
        HStack(spacing: 14) {
            AnswerButton(color: Self.red, help: model.lang.pick("No", "Nein")) {
                CrossShape().stroke(Self.red, style: StrokeStyle(lineWidth: 4.5, lineCap: .round)).padding(15)
            } action: {
                ui.askNextSession = false
            }
            AnswerButton(color: FocusCompleteView.green, help: model.lang.pick("Yes", "Ja")) {
                CheckmarkShape()
                    .stroke(FocusCompleteView.green, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                    .padding(13)
            } action: {
                ui.askNextSession = false
                model.start()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.lang.pick("Break over", "Pause vorbei"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Text(model.lang.pick("Start a new session?", "Neue Session starten?"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 4)
        }
        .scaleEffect(visible ? 1 : 0.85)
        .opacity(visible ? 1 : 0)
        .padding(.bottom, 6)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65).delay(0.1)) { shown = true }
        }
    }
}

/// Big round answer button with hover feedback.
struct AnswerButton<Icon: View>: View {
    let color: Color
    let help: String
    @ViewBuilder let icon: Icon
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color.opacity(hover ? 0.32 : 0.18))
                Circle().stroke(color, lineWidth: 3.5)
                icon
            }
            .frame(width: 46, height: 46)
            .scaleEffect(hover ? 1.08 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hover)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

struct CrossShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.move(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        return p
    }
}

struct CheckmarkShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY + r.height * 0.02))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.36, y: r.maxY - r.height * 0.12))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.1))
        return p
    }
}

// MARK: - Expanded

struct MainPanel: View {
    var body: some View {
        HStack(spacing: 0) {
            ClockView().frame(maxWidth: .infinity, alignment: .leading)
            VDivider()
            TimerControl().frame(maxWidth: .infinity)
            VDivider()
            TodayView().frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 20)
        }
    }
}

struct VDivider: View {
    var body: some View {
        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1).padding(.vertical, 6)
    }
}

// MARK: Digital clock

private enum Fmt {
    static let hm: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
    static let sec: DateFormatter = { let f = DateFormatter(); f.dateFormat = "ss"; return f }()
}

struct ClockView: View {
    @EnvironmentObject var model: PomodoroModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(model.lang.pick("Time", "Uhrzeit"))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(Fmt.hm.string(from: model.now))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text(Fmt.sec.string(from: model.now))
                    .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.45))
            }
            Text(model.lang.longDate(model.now))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            TimerControlButtons()
                .padding(.top, 6)
        }
    }
}

// MARK: Timer + controls

struct TimerControl: View {
    @EnvironmentObject var model: PomodoroModel

    var body: some View {
        ZStack {
            ProgressRing(progress: model.progress, color: model.accent, lineWidth: 6)
            VStack(spacing: 0) {
                Text(model.remainingString)
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(model.isPaused ? 0.5 : 1))
                    .contentTransition(.numericText(countsDown: true))
                Text(model.phase == .idle ? "\(model.settings.focusMinutes) " + model.lang.pick("min focus", "min Fokus") : model.phaseLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: 100, height: 100)
    }
}

/// Start or Pause/Resume, Skip, Stop – below the clock.
struct TimerControlButtons: View {
    @EnvironmentObject var model: PomodoroModel

    var body: some View {
        if model.isActive {
            HStack(spacing: 8) {
                PillButton(title: model.isPaused ? model.lang.pick("Resume", "Weiter") : model.lang.pick("Pause", "Pause"),
                           symbol: model.isPaused ? "play.fill" : "pause.fill") { model.togglePause() }
                RoundIcon(symbol: "forward.fill", help: model.lang.pick("Skip", "Überspringen")) { model.skip() }
                RoundIcon(symbol: "stop.fill", help: model.lang.pick("Stop", "Stoppen")) { model.cancel() }
            }
        } else {
            PillButton(title: model.lang.pick("Start", "Start"), symbol: "play.fill") { model.start() }
        }
    }
}

// MARK: Today + sessions grid

struct TodayView: View {
    @EnvironmentObject var model: PomodoroModel

    var body: some View {
        let days = model.dailyCounts(days: RollingSessionsGrid.dayCount)
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(model.lang.pick("Today", "Heute"))
            HStack(spacing: 18) {
                StatBlock(title: model.lang.pick("Focus", "Fokus"), value: formatDuration(model.todayFocus), color: model.accent)
                StatBlock(title: model.lang.pick("Break", "Pause"), value: formatDuration(model.todayBreak), color: .white)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                SectionLabel(model.lang.pick("Sessions · 14 days", "Sessions · 14 Tage"))
                Text("\(days.reduce(0, +))")
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            }
            RollingSessionsGrid(days: days, cell: 19, gap: 4, color: model.accent, numberColor: model.onAccent)
        }
    }
}

struct StatBlock: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            }
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var model: PomodoroModel
    @State private var confirmReset = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                StepperRow(label: model.lang.pick("Focus", "Fokus"), value: $model.settings.focusMinutes, unit: "min", range: 1...120, step: 5)
                StepperRow(label: model.lang.pick("Short break", "Kurze Pause"), value: $model.settings.shortBreakMinutes, unit: "min", range: 1...30, step: 1)
                StepperRow(label: model.lang.pick("Long break", "Lange Pause"), value: $model.settings.longBreakMinutes, unit: "min", range: 5...60, step: 5)
            }
            VStack(alignment: .leading, spacing: 8) {
                StepperRow(label: model.lang.pick("Long break after", "Lange Pause nach"), value: $model.settings.longBreakEvery, unit: model.lang.pick("sess.", "Sess."), range: 2...8, step: 1)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.lang.pick("Color", "Farbe")).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                    ColorPickerRow(selection: $model.settings.accent)
                }
                Button {
                    if confirmReset { model.resetRecord(); confirmReset = false } else { confirmReset = true }
                } label: {
                    Text(confirmReset ? model.lang.pick("Really delete?", "Wirklich löschen?") : model.lang.pick("Reset statistics", "Statistik zurücksetzen"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(confirmReset ? .black : .white.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .background(Capsule().fill(confirmReset ? Color.white : Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 10) {
                SwitchRow(label: model.lang.pick("Auto-start breaks", "Pause auto-starten"), isOn: $model.settings.autoStartBreak)
                SwitchRow(label: model.lang.pick("Sound", "Ton"), isOn: $model.settings.sound)
                SwitchRow(label: model.lang.pick("Progress bar", "Fortschrittsleiste"), isOn: $model.settings.showProgressBar)
                SwitchRow(label: model.lang.pick("Launch at login", "Beim Login starten"), isOn: Binding(
                    get: { launchAtLogin },
                    set: { on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch { NSLog("Login item: \(error)") }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }))
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.lang.pick("Language", "Sprache"))
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                    LanguagePicker(selection: $model.settings.language)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

/// English / Deutsch switch.
struct LanguagePicker: View {
    @EnvironmentObject var model: PomodoroModel
    @Binding var selection: AppLanguage

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppLanguage.allCases) { lang in
                let selected = selection == lang
                Button { selection = lang } label: {
                    Text(lang.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selected ? model.onAccent : .white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .frame(height: 24)
                        .background(Capsule().fill(selected ? model.accent : Color.white.opacity(0.1)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ColorPickerRow: View {
    @Binding var selection: AccentColor

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(18), spacing: 7), count: 5), alignment: .leading, spacing: 7) {
            ForEach(AccentColor.allCases) { c in
                Button { selection = c } label: {
                    Circle()
                        .fill(c.color)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color.white, lineWidth: selection == c ? 2 : 0).padding(-3))
                        .frame(width: 18, height: 18)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct StepperRow: View {
    var label: String
    @Binding var value: Int
    var unit: String
    var range: ClosedRange<Int>
    var step: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            HStack(spacing: 6) {
                RoundIcon(symbol: "minus") { value = max(range.lowerBound, value - (value - step < range.lowerBound ? 1 : step)) }
                Text("\(value) \(unit)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 56)
                RoundIcon(symbol: "plus") { value = min(range.upperBound, value + (value == 1 && step > 1 ? step - 1 : step)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SwitchRow: View {
    @EnvironmentObject var model: PomodoroModel
    var label: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 8) {
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule().fill(isOn ? model.accent : Color.white.opacity(0.2)).frame(width: 30, height: 18)
                    Circle().fill(.white).frame(width: 14, height: 14).padding(2)
                }
                .animation(.easeOut(duration: 0.15), value: isOn)
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            }
            .frame(height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Small building blocks

struct SectionLabel: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(.white.opacity(0.4))
    }
}

struct IconButton: View {
    var symbol: String
    var action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(hover ? 1 : 0.6))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct CircleButton: View {
    var symbol: String
    var fill: Color
    var foreground: Color
    var size: CGFloat
    var help: String
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(Circle().fill(fill))
                .brightness(hover ? 0.08 : 0)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

struct RoundIcon: View {
    var symbol: String
    var help: String = ""
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.14)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct PillButton: View {
    @EnvironmentObject var model: PomodoroModel
    var title: String
    var symbol: String
    var action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10, weight: .bold))
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(model.onAccent)
            .padding(.horizontal, 14)
            .frame(height: 26)
            .background(Capsule().fill(model.accent.opacity(hover ? 1 : 0.85)))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
