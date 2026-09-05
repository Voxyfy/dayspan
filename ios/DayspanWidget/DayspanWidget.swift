import WidgetKit
import SwiftUI

// Uygulamanın yazdığı JSON. Alan adları lib/core/widget_bridge.dart ile aynı.
struct Summary: Decodable {
    struct Event: Decodable { let title: String; let time: String? }
    struct Habit: Decodable { let name: String; let color: Int; let done: Bool }
    let date: String
    let eventsTotal: Int
    let upcoming: [Event]
    let tasksLeft: Int
    let habitsLeft: Int
    let habits: [Habit]

    static let empty = Summary(date: "", eventsTotal: 0, upcoming: [], tasksLeft: 0, habitsLeft: 0, habits: [])

    static func load() -> Summary {
        guard let defaults = UserDefaults(suiteName: "group.com.batuhanhaymana.dayspan"),
              let raw = defaults.string(forKey: "summary"),
              let data = raw.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(Summary.self, from: data)
        else { return .empty }
        return parsed
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let summary: Summary
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, summary: .empty) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, summary: Summary.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // Veri uygulamadan geliyor; saat başı yenileme yalnızca "şimdi"ye
        // göre geçmiş etkinlikleri düşürmek için.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [Entry(date: .now, summary: Summary.load())], policy: .after(next)))
    }
}

// lib/core/theme/app_colors.dart içindeki TilePalette ile aynı sıra.
let tileFills: [Color] = [
    Color(red: 0.11, green: 0.11, blue: 0.13),
    Color(red: 0.83, green: 0.00, blue: 1.00),
    Color(red: 0.29, green: 0.24, blue: 1.00),
    Color(red: 0.95, green: 0.95, blue: 0.16),
    Color(red: 1.00, green: 0.24, blue: 0.35),
    Color(red: 0.12, green: 0.53, blue: 1.00),
    Color(red: 0.71, green: 0.36, blue: 1.00),
    Color(red: 0.20, green: 0.78, blue: 0.35),
    Color(red: 1.00, green: 0.62, blue: 0.04),
    Color(red: 0.00, green: 0.90, blue: 0.83),
]

struct DayspanWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: Entry

    var body: some View {
        switch family {
        case .systemSmall: small
        default: medium
        }
    }

    var summaryLine: String {
        var parts: [String] = []
        if entry.summary.eventsTotal > 0 { parts.append("\(entry.summary.eventsTotal) events") }
        if entry.summary.tasksLeft > 0 { parts.append("\(entry.summary.tasksLeft) tasks") }
        if entry.summary.habitsLeft > 0 { parts.append("\(entry.summary.habitsLeft) habits") }
        return parts.isEmpty ? "Nothing planned" : parts.joined(separator: " · ") + " left"
    }

    var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            Text(summaryLine).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
            Spacer(minLength: 0)
            if let first = entry.summary.upcoming.first {
                HStack(spacing: 6) {
                    if let t = first.time { Text(t).font(.system(size: 12, weight: .semibold, design: .monospaced)) }
                    Text(first.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                }.foregroundStyle(.white)
            }
            habitDots
        }
    }

    var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                Text(summaryLine).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
                Spacer(minLength: 0)
                habitDots
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(entry.summary.upcoming.prefix(3).enumerated()), id: \.offset) { _, e in
                    HStack(spacing: 6) {
                        Text(e.time ?? "All day")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(e.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    var habitDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(entry.summary.habits.prefix(8).enumerated()), id: \.offset) { _, h in
                Circle()
                    .fill(tileFills[h.color % tileFills.count])
                    .frame(width: 14, height: 14)
                    .overlay(h.done ? Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.black) : nil)
                    .opacity(h.done ? 1 : 0.45)
            }
        }
    }
}

struct DayspanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayspanWidget", provider: Provider()) { entry in
            DayspanWidgetView(entry: entry)
                .containerBackground(Color(red: 0.04, green: 0.04, blue: 0.05), for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Your events, tasks and habits at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct DayspanWidgetBundle: WidgetBundle {
    var body: some Widget { DayspanWidget() }
}
