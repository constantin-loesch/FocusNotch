import SwiftUI
import WidgetKit

// Ansichten des Desktop-Widgets (ohne @main, damit sie sich auch offscreen rendern lassen).

struct WidgetHeader: View {
    @Environment(\.focusPreviewMode) private var previewMode
    let s: WidgetSnapshot.Resolved
    let accent: AccentColor
    var showSettings = false

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(accent.color.opacity(s.isActive ? 1 : 0.4)).frame(width: 7, height: 7)
            Text(s.paused ? "Pausiert" : s.phase.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer(minLength: 0)
            if showSettings {
                if previewMode {
                    gear
                } else {
                    Link(destination: FocusURL.make("settings")) { gear }
                }
            }
        }
    }

    private var gear: some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.75))
            .frame(width: 22, height: 22)
    }
}

struct WidgetTimeText: View {
    let s: WidgetSnapshot.Resolved
    let date: Date
    var size: CGFloat

    var body: some View {
        Group {
            if s.isRunning, let end = s.endDate, end > date {
                Text(timerInterval: date...end, countsDown: true)
            } else {
                Text(formatClock(s.remaining))
            }
        }
        .font(.system(size: size, weight: .bold, design: .rounded).monospacedDigit())
        .foregroundStyle(.white.opacity(s.paused ? 0.5 : 1))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// Hauptaktion: Start (bereit), Pause (läuft), Weiter (pausiert).
struct PrimaryAction {
    let title: String
    let symbol: String
    let url: URL

    init(_ s: WidgetSnapshot.Resolved) {
        if !s.isActive {
            title = "Start"; symbol = "play.fill"; url = FocusURL.make("start")
        } else if s.paused {
            title = "Weiter"; symbol = "play.fill"; url = FocusURL.make("toggle")
        } else {
            title = "Pause"; symbol = "pause.fill"; url = FocusURL.make("toggle")
        }
    }
}

struct WidgetPill: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let action: PrimaryAction
    let accent: AccentColor

    var body: some View {
        let fullColor = renderingMode == .fullColor
        HStack(spacing: 4) {
            Image(systemName: action.symbol).font(.system(size: 10, weight: .heavy))
            Text(action.title).font(.system(size: 12, weight: .bold)).lineLimit(1)
        }
        .fixedSize()
        // Abgedunkelter Modus: macOS macht dunkle Farben dort durchsichtig.
        // Deshalb weiße Schrift auf einem nur leicht hellen Button, ohne Rand.
        .foregroundStyle(fullColor ? accent.onAccent : .white)
        .padding(.horizontal, 13)
        .frame(height: 26)
        .background(Capsule().fill(fullColor ? accent.color : Color.white.opacity(0.16)))
    }
}

struct WidgetCircle: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Color.white.opacity(0.15)))
    }
}

struct WidgetProgress: View {
    @Environment(\.focusPreviewMode) private var previewMode
    let s: WidgetSnapshot.Resolved
    let date: Date
    let accent: AccentColor

    var body: some View {
        if previewMode {
            let fraction = s.isActive && s.duration > 0 ? min(1, max(0, 1 - s.remaining / s.duration)) : 0
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(accent.color).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 4)
        } else {
            liveProgress
        }
    }

    private var liveProgress: some View {
        Group {
            if s.isRunning, let end = s.endDate, end > date, s.duration > 0 {
                ProgressView(timerInterval: end.addingTimeInterval(-s.duration)...end, countsDown: false,
                             label: { EmptyView() }, currentValueLabel: { EmptyView() })
            } else {
                ProgressView(value: s.isActive && s.duration > 0 ? min(1, max(0, 1 - s.remaining / s.duration)) : 0)
            }
        }
        .progressViewStyle(.linear)
        .tint(accent.color)
    }
}

struct SmallWidgetView: View {
    let s: WidgetSnapshot.Resolved
    let date: Date
    let accent: AccentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(s: s, accent: accent)
            Spacer(minLength: 4)
            WidgetTimeText(s: s, date: date, size: 34)
            Text("\(formatDuration(s.todayFocus)) Fokus heute")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 6)
            Button(intent: ToggleTimerIntent()) { WidgetPill(action: PrimaryAction(s), accent: accent) }
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MediumWidgetView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let s: WidgetSnapshot.Resolved
    let date: Date
    let accent: AccentColor

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetHeader(s: s, accent: accent, showSettings: true)
                Spacer(minLength: 4)
                WidgetTimeText(s: s, date: date, size: 36)
                WidgetProgress(s: s, date: date, accent: accent)
                    .padding(.top, 2)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Button(intent: ToggleTimerIntent()) { WidgetPill(action: PrimaryAction(s), accent: accent) }
                        .buttonStyle(.plain)
                    if s.isActive {
                        Button(intent: SkipTimerIntent()) { WidgetCircle(symbol: "forward.fill") }
                            .buttonStyle(.plain)
                        Button(intent: StopTimerIntent()) { WidgetCircle(symbol: "stop.fill") }
                            .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 6) {
                Text("HEUTE")
                    .font(.system(size: 9, weight: .bold)).tracking(1.2)
                    .foregroundStyle(.white.opacity(0.4))
                HStack(spacing: 12) {
                    WidgetStat(title: "Fokus", value: formatDuration(s.todayFocus), color: accent.color)
                    WidgetStat(title: "Pause", value: formatDuration(s.todayBreak), color: .white)
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("SESSIONS · 14 TAGE")
                        .font(.system(size: 8, weight: .bold)).tracking(1)
                        .foregroundStyle(.white.opacity(0.4))
                    Text("\(s.days.suffix(RollingSessionsGrid.dayCount).reduce(0, +))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                RollingSessionsGrid(days: s.days, cell: 14, gap: 3, color: accent.color,
                                    numberColor: renderingMode == .fullColor ? accent.onAccent : .white,
                                    intensityScale: renderingMode == .fullColor ? 1 : 0.45)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct WidgetStat: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            }
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}
