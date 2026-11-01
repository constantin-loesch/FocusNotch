import SwiftUI
import WidgetKit

// Ansichten des Desktop-Widgets (ohne @main, damit sie sich auch offscreen rendern lassen).

struct WidgetHeader: View {
    let s: WidgetSnapshot.Resolved
    let accent: AccentColor

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(accent.color.opacity(s.isActive ? 1 : 0.4)).frame(width: 7, height: 7)
            Text(s.paused ? "Pausiert" : s.phase.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer(minLength: 0)
        }
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
    let action: PrimaryAction
    let accent: AccentColor

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: action.symbol).font(.system(size: 9, weight: .bold))
            Text(action.title).font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(accent.onAccent)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Capsule().fill(accent.color))
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
    let s: WidgetSnapshot.Resolved
    let date: Date
    let accent: AccentColor

    var body: some View {
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
            WidgetPill(action: PrimaryAction(s), accent: accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(PrimaryAction(s).url) // kleines Widget: ganzer Bereich ist der Button
    }
}

struct MediumWidgetView: View {
    let s: WidgetSnapshot.Resolved
    let date: Date
    let accent: AccentColor

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetHeader(s: s, accent: accent)
                Spacer(minLength: 4)
                WidgetTimeText(s: s, date: date, size: 36)
                WidgetProgress(s: s, date: date, accent: accent)
                    .padding(.top, 2)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Link(destination: PrimaryAction(s).url) { WidgetPill(action: PrimaryAction(s), accent: accent) }
                    if s.isActive {
                        Link(destination: FocusURL.make("skip")) { WidgetCircle(symbol: "forward.fill") }
                        Link(destination: FocusURL.make("stop")) { WidgetCircle(symbol: "stop.fill") }
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
                HeatmapGrid(days: s.days, weeks: 10, cell: 8, gap: 2.5, color: accent.color, today: date)
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
