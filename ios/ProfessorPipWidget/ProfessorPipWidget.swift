import WidgetKit
import SwiftUI
import StoreKit

private let appGroupId = "group.com.gaberoeloffs.professorpip"
private let followedTopicsKey = "followedTopics"
private let lastWordKey = "lastWord"
private let proStatusKey = "proStatus"
private let wordsPerDayKey = "wordsPerDay"
private let defaultWordsPerDay = 24
private let maxWordsPerDay = 48

private func isProUser() -> Bool {
    let defaults = UserDefaults(suiteName: appGroupId)
    return defaults?.bool(forKey: proStatusKey) ?? false
}

/// Live entitlement check straight from StoreKit, so the widget reflects the
/// real subscription state even when the app hasn't run in a while — people buy
/// this for the widget and may rarely open the app, so we can't trust the
/// app-pushed `proStatus` flag to be fresh. Pro is sold only as an
/// auto-renewable subscription, so we count ONLY active subscriptions — never a
/// non-consumable. (This deliberately ignores any leftover one-time purchase.)
/// Falls back to the cached flag on iOS < 15 (no StoreKit 2), and writes the
/// result back to the flag so the synchronous render-time gate stays consistent.
private func isProEntitled() async -> Bool {
    if #available(iOS 15.0, *) {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result,
               txn.revocationDate == nil,
               txn.productType == .autoRenewable {
                entitled = true
                break
            }
        }
        UserDefaults(suiteName: appGroupId)?.set(entitled, forKey: proStatusKey)
        return entitled
    }
    return isProUser()
}

private func wordsPerDay() -> Int {
    let defaults = UserDefaults(suiteName: appGroupId)
    // `integer(forKey:)` returns 0 when the key is missing; treat that as "use
    // the default" rather than "user wants 0 words" so a fresh install gets a
    // sensible cadence before onboarding finishes pushing the real value.
    let raw = defaults?.object(forKey: wordsPerDayKey) as? Int
    guard let raw = raw else { return defaultWordsPerDay }
    return min(max(raw, 0), maxWordsPerDay)
}

private let upgradeEntry = VocabEntry(
    date: .now,
    word: "Upgrade",
    partOfSpeech: "",
    definition: "Tap here to unlock all 10,000+ words across 15 topics"
)

private let pausedEntry = VocabEntry(
    date: .now,
    word: "Paused",
    partOfSpeech: "",
    definition: "Set words per day in the app to start learning again."
)

private struct AppWord {
    let word: String
    let pos: String
    let definition: String
}

private func lastWordFromApp() -> AppWord? {
    let defaults = UserDefaults(suiteName: appGroupId)
    guard let dict = defaults?.dictionary(forKey: lastWordKey),
          let word = dict["word"] as? String,
          let pos = dict["pos"] as? String,
          let definition = dict["definition"] as? String else {
        return nil
    }
    return AppWord(word: word, pos: pos, definition: definition)
}

struct VocabEntry: TimelineEntry {
    let date: Date
    let word: String
    let partOfSpeech: String
    let definition: String
}

private let emptyStateEntry = VocabEntry(
    date: .now,
    word: "Upgrade",
    partOfSpeech: "",
    definition: "Tap here to unlock all 10,000+ words across 15 topics"
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
    // Deterministic per-slot selection so widgets across families stay in sync.
    // Seed by minute-of-day so sub-hourly cadences (e.g., every 30 min when
    // wordsPerDay == 48) still get a unique word per slot.
    let cal = Calendar(identifier: .gregorian)
    let components = cal.dateComponents(
        [.year, .dayOfYear, .hour, .minute], from: date
    )
    let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
    let seed = (components.year ?? 0) * 1_000_000
        + (components.dayOfYear ?? 0) * 2_000
        + minuteOfDay
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
        Task {
            if !(await isProEntitled()) {
                completion(upgradeEntry)
                return
            }
            if let last = lastWordFromApp() {
                completion(VocabEntry(
                    date: Date(),
                    word: last.word,
                    partOfSpeech: last.pos,
                    definition: last.definition
                ))
                return
            }
            let pool = wordPool()
            completion(makeVocabEntry(for: Date(), pool: pool))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VocabEntry>) -> Void) {
        Task {
            let isPro = await isProEntitled()
            let cal = Calendar(identifier: .gregorian)
            let now = Date()
            let startOfDay = cal.date(
                from: cal.dateComponents([.year, .month, .day], from: now)
            ) ?? now

            if !isPro {
                // No active subscription — show a static upgrade prompt and
                // re-check in a few hours in case the user upgrades.
                let refresh = cal.date(byAdding: .hour, value: 4, to: now) ?? now
                completion(Timeline(entries: [upgradeEntry], policy: .after(refresh)))
                return
            }

            let wpd = wordsPerDay()
            if wpd <= 0 {
                // User dialed cadence down to 0 — pin a "paused" entry and
                // re-check once a day so the widget picks up changes.
                let refresh = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? now
                completion(Timeline(entries: [pausedEntry], policy: .after(refresh)))
                return
            }

            let pool = wordPool()
            let secondsPerSlot = 86_400.0 / Double(wpd)
            let secondsIntoDay = now.timeIntervalSince(startOfDay)
            let currentSlotIndex = Int(secondsIntoDay / secondsPerSlot)
            let currentSlotStart = startOfDay
                .addingTimeInterval(Double(currentSlotIndex) * secondsPerSlot)

            // Always generate one full day's worth of slots so the timeline keeps
            // rotating even if WidgetCenter doesn't reload us promptly.
            let slotsToGenerate = wpd
            var entries: [VocabEntry] = []

            // The current slot's entry mirrors whatever word the app last
            // showed (if any) so the widget stays in sync with the in-app view.
            if let last = lastWordFromApp() {
                entries.append(VocabEntry(
                    date: currentSlotStart,
                    word: last.word,
                    partOfSpeech: last.pos,
                    definition: last.definition
                ))
            } else {
                entries.append(makeVocabEntry(for: currentSlotStart, pool: pool))
            }
            for offset in 1..<slotsToGenerate {
                let d = currentSlotStart
                    .addingTimeInterval(Double(offset) * secondsPerSlot)
                entries.append(makeVocabEntry(for: d, pool: pool))
            }
            // Refresh at the next slot boundary, but at least every few hours so
            // a lapsed subscription is caught promptly even if the app never runs.
            let slotsRefresh = currentSlotStart
                .addingTimeInterval(Double(slotsToGenerate) * secondsPerSlot)
            let entitlementRefresh = cal.date(byAdding: .hour, value: 4, to: now) ?? slotsRefresh
            let refresh = min(slotsRefresh, entitlementRefresh)
            completion(Timeline(entries: entries, policy: .after(refresh)))
        }
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
            // Re-check Pro live at render time so a non-subscriber never sees a
            // real word, even if a timeline generated while subscribed is still
            // cached. One gate here covers every widget family.
            let gated = isProUser() ? entry : upgradeEntry
            if #available(iOS 17.0, *) {
                ProfessorPipWidgetEntryView(entry: gated)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ProfessorPipWidgetEntryView(entry: gated)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Word of the hour")
        .description("A vocabulary word from your followed topics, refreshed on the cadence you pick in the app.")
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
