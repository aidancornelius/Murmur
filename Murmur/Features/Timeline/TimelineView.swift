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

    // Centralised data controller for efficient fetching and caching
    @StateObject private var dataController: TimelineDataController

    // Edit sheet state
    @State private var entryToEdit: SymptomEntry?
    @State private var activityToEdit: ActivityEvent?
    @State private var sleepToEdit: SleepEvent?
    @State private var mealToEdit: MealEvent?

    init(context: NSManagedObjectContext) {
        _dataController = StateObject(wrappedValue: TimelineDataController(context: context))
    }

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        List {
            ForEach(dataController.daySections) { section in
                Section(header: sectionHeader(for: section)) {
                    // Group symptoms by type for a cleaner view
                    ForEach(groupedSymptoms(for: section), id: \.type.objectID) { group in
                        TimelineSymptomGroupRow(group: group, palette: palette)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteSymptomGroup(group)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if let entry = group.entries.first {
                                    Button {
                                        entryToEdit = entry
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                            }
                    }
                    // Show activities, sleep, and meals individually (typically fewer)
                    ForEach(section.activities, id: \.objectID) { activity in
                        TimelineActivityRow(activity: activity)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteActivity(activity)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    activityToEdit = activity
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                    ForEach(section.sleepEvents, id: \.objectID) { sleep in
                        TimelineSleepRow(sleep: sleep)
                            .swipeActions(edge: .trailing, allowsFullSwipe: !sleep.isImported) {
                                if !sleep.isImported {
                                    Button(role: .destructive) {
                                        deleteSleep(sleep)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    sleepToEdit = sleep
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                    ForEach(section.mealEvents, id: \.objectID) { meal in
                        TimelineMealRow(meal: meal)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteMeal(meal)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    mealToEdit = meal
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                }
                .listRowBackground(palette.surfaceColor)
            }
            if dataController.daySections.isEmpty && !dataController.isLoading {
                emptyState
            }
        }
        .listStyle(.insetGrouped)
        .themedScrollBackground()
        .navigationTitle("Murmur")
        .accessibilityIdentifier(AccessibilityIdentifiers.timelineList)
        .sheet(item: $entryToEdit) { entry in
            EditEntrySheet(entry: entry, onSave: saveContext)
        }
        .sheet(item: $activityToEdit) { activity in
            EditActivitySheet(activity: activity, onSave: saveContext)
        }
        .sheet(item: $sleepToEdit) { sleep in
            EditSleepSheet(sleep: sleep, onSave: saveContext)
        }
        .sheet(item: $mealToEdit) { meal in
            EditMealSheet(meal: meal, onSave: saveContext)
        }
    }

    // MARK: - Delete Actions

    private func deleteSymptomGroup(_ group: SymptomGroup) {
        for entry in group.entries {
            context.delete(entry)
        }
        saveContext()
    }

    private func deleteActivity(_ activity: ActivityEvent) {
        context.delete(activity)
        saveContext()
    }

    private func deleteSleep(_ sleep: SleepEvent) {
        guard !sleep.isImported else { return } // Don't delete HealthKit imports
        context.delete(sleep)
        saveContext()
    }

    private func deleteMeal(_ meal: MealEvent) {
        context.delete(meal)
        saveContext()
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save after delete: \(error.localizedDescription)")
            context.rollback()
        }
    }

    /// Groups symptom entries by type for consolidated display
    private func groupedSymptoms(for section: DaySection) -> [SymptomGroup] {
        let grouped = Dictionary(grouping: section.entries) { $0.symptomType }
        return grouped.compactMap { (type, entries) -> SymptomGroup? in
            guard let type = type else { return nil }
            let avgSeverity = entries.map { Double($0.severity) }.reduce(0, +) / Double(entries.count)
            let latestTime = entries.compactMap { $0.backdatedAt ?? $0.createdAt }.max() ?? DateUtility.now()
            return SymptomGroup(type: type, entries: entries, averageSeverity: avgSeverity, latestTime: latestTime)
        }.sorted { $0.latestTime > $1.latestTime }
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
                    if let summary = section.summary, let loadScore = summary.loadScore, loadScore.effectiveLoad > 0.1 {
                        HStack(spacing: 5) {
                            Image(systemName: loadIconName(for: loadScore.riskLevel))
                            Text(loadDescriptor(for: loadScore.riskLevel))
                        }
                        .font(.caption)
                        .foregroundStyle(loadIconColour(for: loadScore.riskLevel))
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

    private func loadDescriptor(for riskLevel: LoadScore.RiskLevel) -> String {
        switch riskLevel {
        case .safe: return "Light day"
        case .caution: return "Moderate day"
        case .high: return "Busy day"
        case .critical: return "Heavy day"
        }
    }

    private func loadIconName(for riskLevel: LoadScore.RiskLevel) -> String {
        switch riskLevel {
        case .safe: return "leaf.fill"
        case .caution: return "wind"
        case .high: return "flame"
        case .critical: return "flame.fill"
        }
    }

    private func loadIconColour(for riskLevel: LoadScore.RiskLevel) -> Color {
        switch riskLevel {
        case .safe: return palette.color(for: "loadSafe")
        case .caution: return palette.color(for: "loadCaution")
        case .high: return palette.color(for: "loadHigh")
        case .critical: return palette.color(for: "loadCritical")
        }
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

/// Represents a group of symptom entries of the same type
struct SymptomGroup {
    let type: SymptomType
    let entries: [SymptomEntry]
    let averageSeverity: Double
    let latestTime: Date
}

/// Compact row showing grouped symptoms with a severity colour dot
private struct TimelineSymptomGroupRow: View {
    let group: SymptomGroup
    let palette: ColorPalette

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Severity colour dot using the palette
            Circle()
                .fill(severityColour)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(group.type.name ?? "Unnamed")
                        .font(.subheadline.weight(.medium))
                    if group.entries.count > 1 {
                        Text("×\(group.entries.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(timeRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Severity indicator badge
            SeverityBadge(value: group.averageSeverity, precision: .integer, isPositive: group.type.isPositive)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier(AccessibilityIdentifiers.entryCell(group.entries.first?.id?.uuidString ?? "unknown"))
    }

    private var severityColour: Color {
        let level = Int(round(group.averageSeverity))
        return palette.color(for: "severity\(max(1, min(5, level)))")
    }

    private var timeRange: String {
        let times = group.entries.compactMap { $0.backdatedAt ?? $0.createdAt }
        guard let earliest = times.min(), let latest = times.max() else {
            return ""
        }
        if group.entries.count == 1 {
            return DateFormatters.shortTime.string(from: latest)
        }
        return "\(DateFormatters.shortTime.string(from: earliest)) – \(DateFormatters.shortTime.string(from: latest))"
    }

    private var accessibilityDescription: String {
        let count = group.entries.count
        let severityDesc = SeverityScale.descriptor(for: Int(group.averageSeverity), isPositive: group.type.isPositive)
        if count == 1 {
            return "\(group.type.name ?? "Unnamed"), \(severityDesc)"
        }
        return "\(group.type.name ?? "Unnamed"), \(count) entries, average \(severityDesc)"
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
        let reference = entry.backdatedAt ?? entry.createdAt ?? DateUtility.now()
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
            Circle()
                .fill(Color.purple.opacity(0.7))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(activity.name ?? "Unnamed activity")
                        .font(.subheadline.weight(.medium))
                    if let duration = activity.durationMinutes?.intValue {
                        Text("\(duration) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    Text(timeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ExertionBadge(icon: "figure.walk", value: activity.physicalExertion)
                        ExertionBadge(icon: "brain.head.profile", value: activity.cognitiveExertion)
                        ExertionBadge(icon: "heart", value: activity.emotionalLoad)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var timeLabel: String {
        let reference = activity.backdatedAt ?? activity.createdAt ?? DateUtility.now()
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
    @ObservedObject var sleep: SleepEvent

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.indigo.opacity(0.7))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Sleep")
                        .font(.subheadline.weight(.medium))
                    if let duration = sleepDuration {
                        Text(duration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "moon.fill")
                            .font(.caption2)
                        Text("\(sleep.quality)/5")
                            .font(.caption)
                    }
                    .foregroundStyle(.indigo)
                }
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var timeLabel: String {
        if let bedTime = sleep.bedTime {
            return DateFormatters.shortTime.string(from: bedTime)
        }
        let reference = sleep.backdatedAt ?? sleep.createdAt ?? DateUtility.now()
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
            Circle()
                .fill(Color.orange.opacity(0.7))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(meal.mealType?.capitalized ?? "Meal")
                        .font(.subheadline.weight(.medium))
                    if let description = meal.mealDescription, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var timeLabel: String {
        let reference = meal.backdatedAt ?? meal.createdAt ?? DateUtility.now()
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

enum TimelineItem: Identifiable {
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
            return entry.backdatedAt ?? entry.createdAt ?? DateUtility.now()
        case .activity(let activity):
            return activity.backdatedAt ?? activity.createdAt ?? DateUtility.now()
        case .sleep(let sleep):
            return sleep.backdatedAt ?? sleep.createdAt ?? DateUtility.now()
        case .meal(let meal):
            return meal.backdatedAt ?? meal.createdAt ?? DateUtility.now()
        }
    }
}

struct DaySection: Identifiable, Equatable {
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
        let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? DateUtility.now()
        let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? DateUtility.now()
        return lhsDate > rhsDate
    }

    func sortActivities(_ lhs: ActivityEvent, _ rhs: ActivityEvent) -> Bool {
        let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? DateUtility.now()
        let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? DateUtility.now()
        return lhsDate > rhsDate
    }

    @MainActor
    static func sectionsFromArrays(entries: [SymptomEntry], activities: [ActivityEvent], sleepEvents: [SleepEvent], mealEvents: [MealEvent]) -> [DaySection] {
        let calendar = Calendar.current

        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? DateUtility.now())
        }

        let groupedActivities = Dictionary(grouping: activities) { activity in
            calendar.startOfDay(for: activity.backdatedAt ?? activity.createdAt ?? DateUtility.now())
        }

        let groupedSleepEvents = Dictionary(grouping: sleepEvents) { sleep in
            calendar.startOfDay(for: sleep.backdatedAt ?? sleep.createdAt ?? DateUtility.now())
        }

        let groupedMealEvents = Dictionary(grouping: mealEvents) { meal in
            calendar.startOfDay(for: meal.backdatedAt ?? meal.createdAt ?? DateUtility.now())
        }

        // Display dates are dates with UI data (entries, activities, sleep, or meals)
        let displayDates = Set(groupedEntries.keys)
            .union(Set(groupedActivities.keys))
            .union(Set(groupedSleepEvents.keys))
            .union(Set(groupedMealEvents.keys))

        guard !displayDates.isEmpty else { return [] }

        // For load score calculation, combine all contributors
        var allContributors: [LoadContributor] = []
        allContributors.append(contentsOf: activities as [LoadContributor])
        allContributors.append(contentsOf: mealEvents as [LoadContributor])
        allContributors.append(contentsOf: sleepEvents as [LoadContributor])

        // Group contributors by date
        let groupedContributors = LoadCalculator.shared.groupContributorsByDate(allContributors)

        // Get date range for load calculation
        let loadScoreDateRange = Set(groupedEntries.keys)
            .union(Set(groupedContributors.keys))
            .sorted()

        guard let firstDate = loadScoreDateRange.first, let lastDate = loadScoreDateRange.last else {
            return []
        }

        // Calculate load scores for full range using new calculator
        let loadScores = LoadCalculator.shared.calculateRange(
            from: firstDate,
            to: lastDate,
            contributorsByDate: groupedContributors,
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
                    ($0.backdatedAt ?? $0.createdAt ?? DateUtility.now()) > ($1.backdatedAt ?? $1.createdAt ?? DateUtility.now())
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
