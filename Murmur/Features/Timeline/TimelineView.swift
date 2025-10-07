//
//  TimelineView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI
import CoreData
import os.log

struct TimelineView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appearanceManager: AppearanceManager

    private let logger = Logger(subsystem: "app.murmur", category: "Timeline")

    // Use dynamic fetch requests that update automatically
    @FetchRequest private var entries: FetchedResults<SymptomEntry>
    @FetchRequest private var activities: FetchedResults<ActivityEvent>
    @FetchRequest private var sleepEvents: FetchedResults<SleepEvent>
    @FetchRequest private var mealEvents: FetchedResults<MealEvent>

    init() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let displayStartDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        // Fetch additional 60 days for load score decay calculation
        let dataStartDate = calendar.date(byAdding: .day, value: -90, to: today) ?? today

        let entriesRequest = SymptomEntry.fetchRequest()
        entriesRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
        ]
        entriesRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            dataStartDate as NSDate, dataStartDate as NSDate
        )
        entriesRequest.relationshipKeyPathsForPrefetching = ["symptomType"]
        entriesRequest.fetchBatchSize = 50
        _entries = FetchRequest(fetchRequest: entriesRequest, animation: .default)

        let activitiesRequest = ActivityEvent.fetchRequest()
        activitiesRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \ActivityEvent.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \ActivityEvent.createdAt, ascending: false)
        ]
        activitiesRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            dataStartDate as NSDate, dataStartDate as NSDate
        )
        activitiesRequest.fetchBatchSize = 50
        _activities = FetchRequest(fetchRequest: activitiesRequest, animation: .default)

        // Sleep and meal events only need display range (not used for load score calculation)
        let sleepRequest = SleepEvent.fetchRequest()
        sleepRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SleepEvent.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SleepEvent.createdAt, ascending: false)
        ]
        sleepRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            displayStartDate as NSDate, displayStartDate as NSDate
        )
        sleepRequest.fetchBatchSize = 20
        _sleepEvents = FetchRequest(fetchRequest: sleepRequest, animation: .default)

        let mealRequest = MealEvent.fetchRequest()
        mealRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \MealEvent.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: false)
        ]
        mealRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            displayStartDate as NSDate, displayStartDate as NSDate
        )
        mealRequest.fetchBatchSize = 20
        _mealEvents = FetchRequest(fetchRequest: mealRequest, animation: .default)
    }

    private var daySections: [DaySection] {
        DaySection.sectionsFromArrays(
            entries: Array(entries),
            activities: Array(activities),
            sleepEvents: Array(sleepEvents),
            mealEvents: Array(mealEvents)
        )
    }

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        List {
            ForEach(daySections) { section in
                Section(header: sectionHeader(for: section)) {
                    ForEach(section.timelineItems) { item in
                        switch item {
                        case .symptom(let entry):
                            TimelineEntryRow(entry: entry)
                        case .activity(let activity):
                            TimelineActivityRow(activity: activity)
                        case .sleep(let sleep):
                            TimelineSleepRow(sleep: sleep)
                        case .meal(let meal):
                            TimelineMealRow(meal: meal)
                        }
                    }
                }
                .listRowBackground(palette.surfaceColor)
            }
            if daySections.isEmpty {
                emptyState
            }
        }
        .listStyle(.insetGrouped)
        .themedScrollBackground()
        .navigationTitle("Murmur")
        .accessibilityIdentifier(AccessibilityIdentifiers.timelineList)
    }

    private func sectionHeader(for section: DaySection) -> some View {
        NavigationLink(destination: DayDetailView(date: section.date)) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(section.summary?.dominantColor(for: colorScheme) ?? Color.gray.opacity(0.3))
                    .frame(width: 6, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.date, style: .date)
                        .font(.headline)
                    if let summary = section.summary {
                        HStack(spacing: 6) {
                            Text(String(format: "%.1f average • %d logged", summary.rawAverageSeverity, summary.entryCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let loadScore = summary.loadScore, loadScore.decayedLoad > 0.1 {
                                Text("• \(Int(loadScore.decayedLoad))% load")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(daySummaryLabel(for: section))
            .accessibilityHint("Double tap to view all entries for this day")
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.square")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Record an event or how you're feeling with the buttons in the bottom right to get started.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Empty timeline. Record an event or how you're feeling with the buttons in the bottom right to get started.")
    }

    private func daySummaryLabel(for section: DaySection) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none

        let dateString = dateFormatter.string(from: section.date)

        guard let summary = section.summary else {
            return dateString
        }

        let severityDesc = SeverityScale.descriptor(for: Int(summary.rawAverageSeverity))
        return "\(dateString). \(summary.entryCount) \(summary.entryCount == 1 ? "entry" : "entries"). Average: Level \(Int(summary.rawAverageSeverity)), \(severityDesc)"
    }

}

private struct TimelineEntryRow: View {
    let entry: SymptomEntry

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(entry.symptomType?.uiColor ?? Color.gray)
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.symptomType?.name ?? "Unnamed")
                    .font(.headline)
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(SeverityScale.descriptor(for: Int(entry.severity), isPositive: entry.symptomType?.isPositive ?? false))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            SeverityBadge(value: Double(entry.severity), precision: .integer, isPositive: entry.symptomType?.isPositive ?? false)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier(AccessibilityIdentifiers.entryCell(entry.id?.uuidString ?? "unknown"))
    }

    private var timeLabel: String {
        let reference = entry.backdatedAt ?? entry.createdAt ?? Date()
        return DateFormatters.shortTime.string(from: reference)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []

        parts.append("\(entry.symptomType?.name ?? "Unnamed") at \(timeLabel)")

        let severityDesc = SeverityScale.descriptor(for: Int(entry.severity), isPositive: entry.symptomType?.isPositive ?? false)
        parts.append("Level \(entry.severity): \(severityDesc)")

        if let note = entry.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }

        return parts.joined(separator: ". ")
    }
}

private struct TimelineActivityRow: View {
    let activity: ActivityEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.purple.opacity(0.6))
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text(activity.name ?? "Unnamed activity")
                        .font(.headline)
                }
                HStack(spacing: 8) {
                    Text(timeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let duration = activity.durationMinutes?.intValue {
                        Text("\(duration) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    ExertionBadge(icon: "figure.walk", value: activity.physicalExertion)
                    ExertionBadge(icon: "brain.head.profile", value: activity.cognitiveExertion)
                    ExertionBadge(icon: "heart", value: activity.emotionalLoad)
                }
                if let note = activity.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var timeLabel: String {
        let reference = activity.backdatedAt ?? activity.createdAt ?? Date()
        return DateFormatters.shortTime.string(from: reference)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append("Activity: \(activity.name ?? "Unnamed") at \(timeLabel)")
        parts.append("Physical exertion: level \(activity.physicalExertion)")
        parts.append("Cognitive exertion: level \(activity.cognitiveExertion)")
        parts.append("Emotional load: level \(activity.emotionalLoad)")
        if let note = activity.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }
        return parts.joined(separator: ". ")
    }
}

private struct ExertionBadge: View {
    let icon: String
    let value: Int16

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text("\(value)")
        }
        .font(.caption2)
        .foregroundStyle(.purple)
    }
}

private struct PhysiologicalStateBadge: View {
    let state: PhysiologicalState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.iconName)
            Text(state.displayText)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(state.color)
        .background(
            Capsule()
                .fill(state.color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(state.color.opacity(0.4), lineWidth: 0.5)
        )
        .accessibilityLabel(state.displayText)
    }
}

private struct TimelineSleepRow: View {
    let sleep: SleepEvent

    private var hasHealthMetrics: Bool {
        sleep.hkSleepHours != nil || sleep.hkHRV != nil || sleep.hkRestingHR != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.indigo.opacity(0.6))
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                    Text("Sleep")
                        .font(.headline)
                }
                HStack(spacing: 8) {
                    Text(timeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let duration = sleepDuration {
                        Text(duration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                        Text("\(sleep.quality)/5")
                    }
                    .font(.caption2)
                    .foregroundStyle(.indigo)
                }
                if hasHealthMetrics {
                    HStack(spacing: 8) {
                        if let sleepHours = sleep.hkSleepHours?.doubleValue {
                            Text(String(format: "%.1fh", sleepHours))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let hrv = sleep.hkHRV?.doubleValue {
                            Text(String(format: "%.0f ms", hrv))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let rhr = sleep.hkRestingHR?.doubleValue {
                            Text(String(format: "%.0f bpm", rhr))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let note = sleep.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var timeLabel: String {
        if let bedTime = sleep.bedTime {
            return DateFormatters.shortTime.string(from: bedTime)
        }
        let reference = sleep.backdatedAt ?? sleep.createdAt ?? Date()
        return DateFormatters.shortTime.string(from: reference)
    }

    private var sleepDuration: String? {
        guard let bedTime = sleep.bedTime, let wakeTime = sleep.wakeTime else { return nil }
        let hours = wakeTime.timeIntervalSince(bedTime) / 3600
        return String(format: "%.1fh", hours)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append("Sleep at \(timeLabel)")
        if let duration = sleepDuration {
            parts.append("Duration: \(duration)")
        }
        parts.append("Quality: \(sleep.quality) out of 5")
        if let sleepHours = sleep.hkSleepHours?.doubleValue {
            parts.append(String(format: "%.1f hours sleep", sleepHours))
        }
        if let hrv = sleep.hkHRV?.doubleValue {
            parts.append(String(format: "HRV %.0f milliseconds", hrv))
        }
        if let rhr = sleep.hkRestingHR?.doubleValue {
            parts.append(String(format: "Resting heart rate %.0f beats per minute", rhr))
        }
        if let note = sleep.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }
        return parts.joined(separator: ". ")
    }
}

private struct TimelineMealRow: View {
    let meal: MealEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.orange.opacity(0.6))
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(meal.mealType?.capitalized ?? "Meal")
                        .font(.headline)
                }
                HStack(spacing: 8) {
                    Text(timeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let description = meal.mealDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let note = meal.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var timeLabel: String {
        let reference = meal.backdatedAt ?? meal.createdAt ?? Date()
        return DateFormatters.shortTime.string(from: reference)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append("\(meal.mealType?.capitalized ?? "Meal") at \(timeLabel)")
        if let description = meal.mealDescription, !description.isEmpty {
            parts.append(description)
        }
        if let note = meal.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }
        return parts.joined(separator: ". ")
    }
}

private enum TimelineItem: Identifiable {
    case symptom(SymptomEntry)
    case activity(ActivityEvent)
    case sleep(SleepEvent)
    case meal(MealEvent)

    var id: NSManagedObjectID {
        switch self {
        case .symptom(let entry):
            return entry.objectID
        case .activity(let activity):
            return activity.objectID
        case .sleep(let sleep):
            return sleep.objectID
        case .meal(let meal):
            return meal.objectID
        }
    }

    var date: Date {
        switch self {
        case .symptom(let entry):
            return entry.backdatedAt ?? entry.createdAt ?? Date()
        case .activity(let activity):
            return activity.backdatedAt ?? activity.createdAt ?? Date()
        case .sleep(let sleep):
            return sleep.backdatedAt ?? sleep.createdAt ?? Date()
        case .meal(let meal):
            return meal.backdatedAt ?? meal.createdAt ?? Date()
        }
    }
}

private struct DaySection: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let entries: [SymptomEntry]
    let activities: [ActivityEvent]
    let sleepEvents: [SleepEvent]
    let mealEvents: [MealEvent]
    let summary: DaySummary?

    static func == (lhs: DaySection, rhs: DaySection) -> Bool {
        guard lhs.date == rhs.date else { return false }

        let lhsEntryIDs = lhs.entries.map { $0.objectID }
        let rhsEntryIDs = rhs.entries.map { $0.objectID }

        let lhsActivityIDs = lhs.activities.map { $0.objectID }
        let rhsActivityIDs = rhs.activities.map { $0.objectID }

        let lhsSleepIDs = lhs.sleepEvents.map { $0.objectID }
        let rhsSleepIDs = rhs.sleepEvents.map { $0.objectID }

        let lhsMealIDs = lhs.mealEvents.map { $0.objectID }
        let rhsMealIDs = rhs.mealEvents.map { $0.objectID }

        return lhsEntryIDs == rhsEntryIDs &&
            lhsActivityIDs == rhsActivityIDs &&
            lhsSleepIDs == rhsSleepIDs &&
            lhsMealIDs == rhsMealIDs &&
            lhs.summary == rhs.summary
    }

    var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        items.append(contentsOf: entries.map { TimelineItem.symptom($0) })
        items.append(contentsOf: activities.map { TimelineItem.activity($0) })
        items.append(contentsOf: sleepEvents.map { TimelineItem.sleep($0) })
        items.append(contentsOf: mealEvents.map { TimelineItem.meal($0) })
        return items.sorted { $0.date > $1.date }
    }

    func sortEntries(_ lhs: SymptomEntry, _ rhs: SymptomEntry) -> Bool {
        let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? Date()
        let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? Date()
        return lhsDate > rhsDate
    }

    func sortActivities(_ lhs: ActivityEvent, _ rhs: ActivityEvent) -> Bool {
        let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? Date()
        let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? Date()
        return lhsDate > rhsDate
    }

    static func sectionsFromArrays(entries: [SymptomEntry], activities: [ActivityEvent], sleepEvents: [SleepEvent], mealEvents: [MealEvent]) -> [DaySection] {
        let calendar = Calendar.current

        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
        }

        let groupedActivities = Dictionary(grouping: activities) { activity in
            calendar.startOfDay(for: activity.backdatedAt ?? activity.createdAt ?? Date())
        }

        let groupedSleepEvents = Dictionary(grouping: sleepEvents) { sleep in
            calendar.startOfDay(for: sleep.backdatedAt ?? sleep.createdAt ?? Date())
        }

        let groupedMealEvents = Dictionary(grouping: mealEvents) { meal in
            calendar.startOfDay(for: meal.backdatedAt ?? meal.createdAt ?? Date())
        }

        // Display dates are dates with UI data (entries, activities, sleep, or meals)
        let displayDates = Set(groupedEntries.keys)
            .union(Set(groupedActivities.keys))
            .union(Set(groupedSleepEvents.keys))
            .union(Set(groupedMealEvents.keys))

        guard !displayDates.isEmpty else { return [] }

        // For load score calculation, we need the full date range including lookback data
        // This includes dates with only entries/activities (used for decay chain)
        let loadScoreDateRange = Set(groupedEntries.keys).union(Set(groupedActivities.keys)).sorted()

        guard let firstDate = loadScoreDateRange.first, let lastDate = loadScoreDateRange.last else {
            return []
        }

        // Calculate load scores for full range (builds proper decay chain)
        let loadScores = LoadScore.calculateRange(
            from: firstDate,
            to: lastDate,
            activitiesByDate: groupedActivities,
            symptomsByDate: groupedEntries
        )

        // Create a lookup dictionary for load scores
        let loadScoresByDate = Dictionary(uniqueKeysWithValues: loadScores.map { ($0.date, $0) })

        // Only return sections for dates with display data (not just lookback data)
        return displayDates.sorted()
            .map { day in
                let dayEntries = groupedEntries[day] ?? []
                let dayActivities = groupedActivities[day] ?? []
                let daySleepEvents = groupedSleepEvents[day] ?? []
                let dayMealEvents = groupedMealEvents[day] ?? []
                let sorted = dayEntries.sorted {
                    ($0.backdatedAt ?? $0.createdAt ?? Date()) > ($1.backdatedAt ?? $1.createdAt ?? Date())
                }
                let loadScore = loadScoresByDate[day]
                return DaySection(
                    date: day,
                    entries: sorted,
                    activities: dayActivities,
                    sleepEvents: daySleepEvents,
                    mealEvents: dayMealEvents,
                    summary: DaySummary.makeWithLoadScore(for: day, entries: sorted, loadScore: loadScore)
                )
            }
            .sorted { $0.date > $1.date }
    }
}
