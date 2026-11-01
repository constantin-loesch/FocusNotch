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
        let t = topRadius, b = min(bottomRadius, (r.height - t) / 1)
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
        let size = ui.size(active: model.isActive)
        let t: CGFloat = ui.isExpanded ? 12 : 6
        let hidden = !ui.hasNotch && !model.isActive && !ui.isExpanded

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(topRadius: t, bottomRadius: ui.isExpanded ? 26 : 10)
                    .fill(Color.black)
                    .frame(width: size.width, height: size.height)
                    .shadow(color: .black.opacity(ui.isExpanded ? 0.45 : 0), radius: 14, y: 6)

                Group {
                    if ui.isExpanded {
                        ExpandedView()
                            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                    } else if model.isActive {
                        CollapsedView()
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, t)
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipped()
            }
            .opacity(hidden ? 0 : 1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .animation(spring, value: ui.isExpanded)
        .animation(spring, value: model.isActive)
        .animation(spring, value: ui.showSettings)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Eingeklappt: Zeit links von der Kamera, Fortschritt rechts

struct CollapsedView: View {
    @EnvironmentObject var model: PomodoroModel
    @EnvironmentObject var ui: IslandUIState

    var body: some View {
        let color = Color(nsColor: model.phaseColor)
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: model.phase.isBreak ? "cup.and.saucer.fill" : "timer")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(model.remainingString)
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
            }
            .frame(width: IslandUIState.sideWidth - 6, alignment: .center)

            Spacer(minLength: ui.notchSize.width)

            ProgressRing(progress: model.progress, color: color, lineWidth: 2.5)
                .frame(width: 15, height: 15)
                .frame(width: IslandUIState.sideWidth - 6)
        }
        .frame(height: ui.notchSize.height)
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

struct ExpandedView: View {
    @EnvironmentObject var model: PomodoroModel
    @EnvironmentObject var ui: IslandUIState

    var body: some View {
        VStack(spacing: 0) {
            // Zeile neben der Notch
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color(nsColor: model.phaseColor)).frame(width: 7, height: 7)
                    Text(ui.showSettings ? "Einstellungen" : "Pomodoro · \(model.phase.title)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                HStack(spacing: 14) {
                    IconButton(symbol: ui.showSettings ? "xmark" : "gearshape.fill") { ui.showSettings.toggle() }
                    IconButton(symbol: "power") { NSApp.terminate(nil) }
                }
            }
            .padding(.horizontal, 20)
            .frame(height: ui.notchSize.height)

            Group {
                if ui.showSettings {
                    SettingsView().transition(.opacity)
                } else {
                    MainPanel().transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 18)
            .frame(maxHeight: .infinity)
        }
    }
}

struct MainPanel: View {
    var body: some View {
        HStack(spacing: 0) {
            ClockView().frame(maxWidth: .infinity, alignment: .leading)
            VDivider()
            TimerControl().frame(maxWidth: .infinity)
            VDivider()
            RecordView().frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 18)
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
    static let weekdayLetter: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateFormat = "EEEEE"; return f
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

// MARK: Timer + Start/Abbrechen

struct TimerControl: View {
    @EnvironmentObject var model: PomodoroModel

    var body: some View {
        let color = Color(nsColor: model.phase == .idle ? .systemOrange : model.phaseColor)
        VStack(spacing: 10) {
            ZStack {
                ProgressRing(progress: model.progress, color: color, lineWidth: 6)
                VStack(spacing: 0) {
                    Text(model.remainingString)
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                    Text(model.phase == .idle ? "\(model.settings.focusMinutes) min Fokus" : model.phase.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: 100, height: 100)

            switch model.phase {
            case .idle:
                PillButton(title: "Start", symbol: "play.fill", color: .orange) { model.startFocus() }
            case .focus:
                PillButton(title: "Abbrechen", symbol: "xmark", color: .red) { model.cancel() }
            case .shortBreak, .longBreak:
                PillButton(title: "Pause beenden", symbol: "forward.fill", color: .green) { model.skipBreak() }
            }
        }
    }
}

// MARK: Record

struct RecordView: View {
    @EnvironmentObject var model: PomodoroModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Record")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(model.todayCount)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("/ \(model.settings.dailyGoal) heute · \(model.todayMinutes) min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            GoalDots(done: model.todayCount, goal: model.settings.dailyGoal)
            WeekBars(days: model.lastSevenDays)
            HStack(spacing: 10) {
                Stat(symbol: "flame.fill", color: .orange, value: "\(model.streak) T")
                Stat(symbol: "trophy.fill", color: .yellow, value: "\(model.bestDay)")
                Stat(symbol: "sum", color: .white, value: "\(model.totalCount)")
                Stat(symbol: "xmark.circle", color: .red, value: "\(model.cancelledCount)")
            }
            .help("Serie · Bester Tag · Gesamt · Abgebrochen")
        }
    }
}

struct GoalDots: View {
    var done: Int
    var goal: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(goal, 1), id: \.self) { i in
                Circle()
                    .fill(i < done ? Color.orange : Color.white.opacity(0.15))
                    .frame(width: 7, height: 7)
            }
            if done > goal {
                Text("+\(done - goal)").font(.system(size: 9, weight: .bold)).foregroundStyle(.orange)
            }
        }
    }
}

struct WeekBars: View {
    var days: [(date: Date, count: Int)]
    var body: some View {
        let maxCount = max(days.map(\.count).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(days.indices, id: \.self) { i in
                let d = days[i]
                let isToday = i == days.count - 1
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isToday ? Color.orange : Color.white.opacity(d.count > 0 ? 0.45 : 0.12))
                        .frame(width: 12, height: max(3, 26 * CGFloat(d.count) / CGFloat(maxCount)))
                    Text(Fmt.weekdayLetter.string(from: d.date))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(isToday ? 0.9 : 0.4))
                }
                .help("\(d.count) Pomodoros")
            }
        }
        .frame(height: 38, alignment: .bottom)
    }
}

struct Stat: View {
    var symbol: String
    var color: Color
    var value: String
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
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
                StepperRow(label: "Lange Pause alle", value: $model.settings.longBreakEvery, unit: "×", range: 2...8, step: 1)
                StepperRow(label: "Tagesziel", value: $model.settings.dailyGoal, unit: "🍅", range: 1...16, step: 1)
                Button {
                    if confirmReset { model.resetRecord(); confirmReset = false } else { confirmReset = true }
                } label: {
                    Text(confirmReset ? "Wirklich löschen?" : "Record zurücksetzen")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(confirmReset ? .white : .red)
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .background(Capsule().fill(confirmReset ? Color.red : Color.red.opacity(0.15)))
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
    var label: String
    @Binding var isOn: Bool
    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 8) {
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule().fill(isOn ? Color.orange : Color.white.opacity(0.2)).frame(width: 30, height: 18)
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

struct RoundIcon: View {
    var symbol: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }
}

struct PillButton: View {
    var title: String
    var symbol: String
    var color: Color
    var action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10, weight: .bold))
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 26)
            .background(Capsule().fill(color.opacity(hover ? 0.95 : 0.75)))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
