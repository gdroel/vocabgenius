import WidgetKit
import SwiftUI

private let appGroupId = "group.com.gaberoeloffs.professorpip"
private let followedTopicsKey = "followedTopics"

struct VocabEntry: TimelineEntry {
    let date: Date
    let word: String
    let partOfSpeech: String
    let definition: String
}

private let emptyStateEntry = VocabEntry(
    date: .now,
    word: "Welcome",
    partOfSpeech: "",
    definition: "Open the app to select topics."
)

private func followedTopicIds() -> Set<String> {
    let defaults = UserDefaults(suiteName: appGroupId)
    let ids = defaults?.stringArray(forKey: followedTopicsKey) ?? []
    return Set(ids)
}

private func wordPool() -> [WidgetWord] {
    let followed = followedTopicIds()
    if followed.isEmpty { return [] }
    return allWidgetWords.filter { followed.contains($0.topicId) }
}

private func makeVocabEntry(for date: Date, pool: [WidgetWord]) -> VocabEntry {
    if pool.isEmpty {
        return VocabEntry(
            date: date,
            word: emptyStateEntry.word,
            partOfSpeech: emptyStateEntry.partOfSpeech,
            definition: emptyStateEntry.definition
        )
    }
    // Deterministic per-hour selection so widgets across families stay in sync.
    let cal = Calendar(identifier: .gregorian)
    let components = cal.dateComponents([.year, .dayOfYear, .hour], from: date)
    let seed = (components.year ?? 0) * 100000
        + (components.dayOfYear ?? 0) * 100
        + (components.hour ?? 0)
    let index = abs(seed) % pool.count
    let w = pool[index]
    return VocabEntry(
        date: date,
        word: w.word,
        partOfSpeech: w.pos,
        definition: w.definition
    )
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> VocabEntry { emptyStateEntry }

    func getSnapshot(in context: Context, completion: @escaping (VocabEntry) -> Void) {
        let pool = wordPool()
        completion(makeVocabEntry(for: Date(), pool: pool))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VocabEntry>) -> Void) {
        let pool = wordPool()
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let topOfHour = cal.date(
            from: cal.dateComponents([.year, .month, .day, .hour], from: now)
        ) ?? now

        var entries: [VocabEntry] = []
        for offset in 0..<24 {
            let d = cal.date(byAdding: .hour, value: offset, to: topOfHour) ?? now
            entries.append(makeVocabEntry(for: d, pool: pool))
        }
        let refresh = cal.date(byAdding: .hour, value: 24, to: topOfHour) ?? now
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

struct ProfessorPipWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: VocabEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.word)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                Text(entry.partOfSpeech.isEmpty
                    ? entry.definition
                    : "(\(entry.partOfSpeech)) \(entry.definition)")
                    .font(.system(size: 12, weight: .regular))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("\(entry.word) — \(entry.definition)")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text("Pip")
                    .font(.system(size: 10, weight: .semibold))
                Text(entry.word.prefix(6))
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text("Professor Pip")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.secondary)
                Text(entry.word)
                    .font(.system(size: 22, weight: .bold))
                Text("(\(entry.partOfSpeech))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(entry.definition)
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct ProfessorPipWidget: Widget {
    let kind: String = "ProfessorPipWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ProfessorPipWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ProfessorPipWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Word of the hour")
        .description("A vocabulary word from your followed topics, refreshed hourly.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular,
            .systemSmall,
            .systemMedium,
        ])
    }
}

#Preview(as: .accessoryRectangular) {
    ProfessorPipWidget()
} timeline: {
    emptyStateEntry
}
