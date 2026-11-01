import SwiftUI
import ServiceManagement

// MARK: - Form der Island (wie die Notch: unten abgerundet, oben leicht ausgestellt)

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

// MARK: - Wurzel

struct IslandView: View {
    @EnvironmentObject var model: PomodoroModel
    @EnvironmentObject var ui: IslandUIState

    var body: some View {
        let size = ui.size()
        let t: CGFloat = ui.isExpanded ? 12 : 6

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(topRadius: t, bottomRadius: ui.isExpanded ? 26 : 10)
                    .fill(Color.black)
                    .frame(width: size.width, height: size.height)
                    .shadow(color: .black.opacity(ui.isExpanded ? 0.45 : 0), radius: 14, y: 6)

                VStack(spacing: 0) {
                    HeaderRow(sideWidth: max(0, (size.width - 2 * t - ui.notchSize.width) / 2))
                    if ui.isExpanded {
                        Group {
                            if ui.showSettings { SettingsView() } else { MainPanel() }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 18)
                        .frame(maxHeight: .infinity)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, t)
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipped()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .animation(spring, value: ui.isExpanded)
        .animation(spring, value: ui.showSettings)
        .animation(spring, value: model.phase)
        .animation(spring, value: model.isPaused)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Kopfzeile neben der Notch (immer sichtbar)
// Links: [Start/Pause] [Skip] Zeit – direkt an der Kamera. Rechts: Fortschrittsring.
// Die Elemente bleiben beim Aufklappen an derselben Stelle, damit man sofort klicken kann.

struct HeaderRow: View {
    @EnvironmentObject var model: PomodoroModel
    @EnvironmentObject var ui: IslandUIState
    var sideWidth: CGFloat

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
            .frame(width: sideWidth)

            Color.clear.frame(width: ui.notchSize.width)

            HStack(spacing: 14) {
                ProgressRing(progress: model.progress, color: model.accent, lineWidth: 2.5)
                    .frame(width: 15, height: 15)
                Spacer(minLength: 0)
                if ui.isExpanded {
                    IconButton(symbol: ui.showSettings ? "xmark" : "gearshape.fill") { ui.showSettings.toggle() }
                    IconButton(symbol: "power") { NSApp.terminate(nil) }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 16)
            .frame(width: sideWidth)
        }
        .frame(height: ui.notchSize.height)
    }
}

/// Start / Pause / Fortsetzen + Überspringen.
struct TimerButtons: View {
    @EnvironmentObject var model: PomodoroModel
    var size: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            CircleButton(symbol: model.isRunning ? "pause.fill" : "play.fill",
                         fill: model.accent, foreground: model.onAccent, size: size,
                         help: model.isRunning ? "Anhalten" : (model.isPaused ? "Fortsetzen" : "Starten")) {
                model.togglePause()
            }
            if model.isActive {
                CircleButton(symbol: "forward.fill", fill: .white.opacity(0.16), foreground: .white, size: size,
                             help: model.phase == .focus ? "Überspringen (zur Pause)" : "Pause überspringen") {
                    model.skip()
                }
                .transition(.scale.combined(with: .opacity))
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

// MARK: - Aufgeklappt

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

// MARK: Digitaluhr

private enum Fmt {
    static let hm: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
    static let sec: DateFormatter = { let f = DateFormatter(); f.dateFormat = "ss"; return f }()
    static let day: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEEE, d. MMMM"; return f
    }()
}

struct ClockView: View {
    @EnvironmentObject var model: PomodoroModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel("Uhrzeit")
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(Fmt.hm.string(from: model.now))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text(Fmt.sec.string(from: model.now))
                    .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.45))
            }
            Text(Fmt.day.string(from: model.now))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

// MARK: Timer + Steuerung

struct TimerControl: View {
    @EnvironmentObject var model: PomodoroModel

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                ProgressRing(progress: model.progress, color: model.accent, lineWidth: 6)
                VStack(spacing: 0) {
                    Text(model.remainingString)
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(model.isPaused ? 0.5 : 1))
                        .contentTransition(.numericText(countsDown: true))
                    Text(model.phase == .idle ? "\(model.settings.focusMinutes) min Fokus" : model.phaseLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 100, height: 100)

            if model.isActive {
                HStack(spacing: 8) {
                    PillButton(title: model.isPaused ? "Weiter" : "Pause",
                               symbol: model.isPaused ? "play.fill" : "pause.fill") { model.togglePause() }
                    RoundIcon(symbol: "forward.fill", help: "Überspringen") { model.skip() }
                    RoundIcon(symbol: "stop.fill", help: "Stoppen") { model.cancel() }
                }
            } else {
                PillButton(title: "Start", symbol: "play.fill") { model.start() }
            }
        }
    }
}

// MARK: Heute + Sessions-Graph

struct TodayView: View {
    @EnvironmentObject var model: PomodoroModel

    var body: some View {
        let days = model.dailyCounts(days: RollingSessionsGrid.dayCount)
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Heute")
            HStack(spacing: 18) {
                StatBlock(title: "Fokus", value: formatDuration(model.todayFocus), color: model.accent)
                StatBlock(title: "Pause", value: formatDuration(model.todayBreak), color: .white)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                SectionLabel("Sessions · 14 Tage")
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

// MARK: - Einstellungen

struct SettingsView: View {
    @EnvironmentObject var model: PomodoroModel
    @State private var confirmReset = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                StepperRow(label: "Fokus", value: $model.settings.focusMinutes, unit: "min", range: 1...120, step: 5)
                StepperRow(label: "Kurze Pause", value: $model.settings.shortBreakMinutes, unit: "min", range: 1...30, step: 1)
                StepperRow(label: "Lange Pause", value: $model.settings.longBreakMinutes, unit: "min", range: 5...60, step: 5)
            }
            VStack(alignment: .leading, spacing: 8) {
                StepperRow(label: "Lange Pause nach", value: $model.settings.longBreakEvery, unit: "Sess.", range: 2...8, step: 1)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Farbe").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                    ColorPickerRow(selection: $model.settings.accent)
                }
                Button {
                    if confirmReset { model.resetRecord(); confirmReset = false } else { confirmReset = true }
                } label: {
                    Text(confirmReset ? "Wirklich löschen?" : "Statistik zurücksetzen")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(confirmReset ? .black : .white.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .background(Capsule().fill(confirmReset ? Color.white : Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 10) {
                SwitchRow(label: "Pause auto-starten", isOn: $model.settings.autoStartBreak)
                SwitchRow(label: "Ton", isOn: $model.settings.sound)
                SwitchRow(label: "Beim Login starten", isOn: Binding(
                    get: { launchAtLogin },
                    set: { on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch { NSLog("Login-Item: \(error)") }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }))
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

struct ColorPickerRow: View {
    @Binding var selection: AccentColor

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(18), spacing: 7), count: 4), alignment: .leading, spacing: 7) {
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

// MARK: - Kleine Bausteine

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
