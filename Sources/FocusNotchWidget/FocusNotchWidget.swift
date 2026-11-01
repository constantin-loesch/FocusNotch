import SwiftUI
import WidgetKit

struct FocusEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot
}

struct FocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(date: Date(), snap: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> Void) {
        completion(FocusEntry(date: Date(), snap: SharedStore.read() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusEntry>) -> Void) {
        let now = Date()
        let snap = SharedStore.read() ?? .placeholder
        let cal = Calendar.current
        // Neu laden um Mitternacht oder wenn der laufende Timer endet
        var next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!.addingTimeInterval(5)
        if snap.pausedRemaining == nil, let end = snap.endDate, end > now {
            next = min(next, end.addingTimeInterval(1))
        }
        completion(Timeline(entries: [FocusEntry(date: now, snap: snap)], policy: .after(next)))
    }
}

struct FocusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FocusEntry

    var body: some View {
        let s = entry.snap.resolved(at: entry.date)
        Group {
            if family == .systemSmall {
                SmallWidgetView(s: s, date: entry.date, accent: entry.snap.accent)
            } else {
                MediumWidgetView(s: s, date: entry.date, accent: entry.snap.accent)
            }
        }
        .containerBackground(for: .widget) { Color.black }
        .environment(\.colorScheme, .dark)
    }
}

struct FocusNotchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FocusNotchWidget", provider: FocusProvider()) { entry in
            FocusWidgetView(entry: entry)
        }
        .configurationDisplayName("FocusNotch")
        .description("Pomodoro starten, anhalten und deinen Fokus von heute sehen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FocusNotchWidgetBundle: WidgetBundle {
    var body: some Widget { FocusNotchWidget() }
}
