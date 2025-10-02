import SwiftUI
import CoreData
import os.log

struct TimelineView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var daySections: [DaySection] = []
    @State private var fetchedDays: Int = 30 // Start with 30 days
    @State private var isLoadingMore = false
    @State private var refreshTrigger = UUID()

    private let daysPerPage = 30
    private let logger = Logger(subsystem: "app.murmur", category: "Timeline")

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)],
        animation: .default
    ) private var allEntries: FetchedResults<SymptomEntry>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ActivityEvent.createdAt, ascending: false)],
        animation: .default
    ) private var allActivities: FetchedResults<ActivityEvent>

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
                        }
                    }
                }
                .onAppear {
                    // Load more when we're near the bottom
                    if section == daySections.last {
                        loadMoreDays()
                    }
                }
            }
            if daySections.isEmpty {
                emptyState
            } else if isLoadingMore {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Murmur")
        .task {
            await loadInitialData()
        }
        .onChange(of: allEntries.count) { _, _ in
            Task {
                await fetchDaySections(days: fetchedDays)
            }
        }
        .onChange(of: allActivities.count) { _, _ in
            Task {
                await fetchDaySections(days: fetchedDays)
            }
        }
    }

    private func loadInitialData() async {
        await fetchDaySections(days: fetchedDays)
    }

    private func loadMoreDays() {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        fetchedDays += daysPerPage
        Task {
            await fetchDaySections(days: fetchedDays)
            isLoadingMore = false
        }
    }

    @MainActor
    private func fetchDaySections(days: Int) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return }

        let sections = await context.perform {
            do {
                // Fetch entries within date range
                let entriesRequest = SymptomEntry.fetchRequest()
                entriesRequest.predicate = NSPredicate(
                    format: "((backdatedAt >= %@) OR (backdatedAt == nil AND createdAt >= %@))",
                    startDate as NSDate, startDate as NSDate
                )
                entriesRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: true),
                    NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: true)
                ]
                let entries = try self.context.fetch(entriesRequest)

                // Fetch activities within date range
                let activitiesRequest = ActivityEvent.fetchRequest()
                activitiesRequest.predicate = NSPredicate(
                    format: "((backdatedAt >= %@) OR (backdatedAt == nil AND createdAt >= %@))",
                    startDate as NSDate, startDate as NSDate
                )
                activitiesRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \ActivityEvent.backdatedAt, ascending: true),
                    NSSortDescriptor(keyPath: \ActivityEvent.createdAt, ascending: true)
                ]
                let activities = try self.context.fetch(activitiesRequest)

                return DaySection.sectionsFromArrays(entries: entries, activities: activities)
            } catch {
                self.logger.error("Error fetching timeline data: \(error.localizedDescription)")
                return []
            }
        }

        self.daySections = sections
    }

    private func sectionHeader(for section: DaySection) -> some View {
        NavigationLink(destination: DayDetailView(date: section.date)) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(section.summary?.dominantColor ?? Color.gray.opacity(0.3))
                    .frame(width: 6, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.date, style: .date)
                        .font(.headline)
                    if let summary = section.summary {
                        HStack(spacing: 6) {
                            Text(String(format: "%.1f average • %d logged", summary.averageSeverity, summary.entryCount))
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
    }

    private func daySummaryLabel(for section: DaySection) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none

        let dateString = dateFormatter.string(from: section.date)

        guard let summary = section.summary else {
            return dateString
        }

        let severityDesc = SeverityScale.descriptor(for: Int(summary.averageSeverity))
        return "\(dateString). \(summary.entryCount) \(summary.entryCount == 1 ? "entry" : "entries"). Average: Level \(Int(summary.averageSeverity)), \(severityDesc)"
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
                HStack(spacing: 8) {
                    Text(timeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let state = physiologicalState {
                        Label(state.displayText, systemImage: state.iconName)
                            .font(.caption2)
                            .foregroundStyle(state.color)
                    }
                }
                Text(SeverityScale.descriptor(for: Int(entry.severity)))
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
            SeverityBadge(value: Double(entry.severity), precision: .integer)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var timeLabel: String {
        let reference = entry.backdatedAt ?? entry.createdAt ?? Date()
        return DateFormatters.shortTime.string(from: reference)
    }

    private var physiologicalState: PhysiologicalState? {
        PhysiologicalState.compute(
            hrv: entry.hkHRV?.doubleValue,
            restingHR: entry.hkRestingHR?.doubleValue,
            sleepHours: entry.hkSleepHours?.doubleValue,
            workoutMinutes: entry.hkWorkoutMinutes?.doubleValue,
            cycleDay: entry.hkCycleDay?.intValue,
            flowLevel: entry.hkFlowLevel
        )
    }

    private var accessibilityDescription: String {
        var parts: [String] = []

        parts.append("\(entry.symptomType?.name ?? "Unnamed") at \(timeLabel)")

        let severityDesc = SeverityScale.descriptor(for: Int(entry.severity))
        parts.append("Level \(entry.severity): \(severityDesc)")

        if let state = physiologicalState {
            parts.append(state.displayText)
        }

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

private enum TimelineItem: Identifiable {
    case symptom(SymptomEntry)
    case activity(ActivityEvent)

    var id: UUID {
        switch self {
        case .symptom(let entry):
            return entry.id ?? UUID()
        case .activity(let activity):
            return activity.id ?? UUID()
        }
    }

    var date: Date {
        switch self {
        case .symptom(let entry):
            return entry.backdatedAt ?? entry.createdAt ?? Date()
        case .activity(let activity):
            return activity.backdatedAt ?? activity.createdAt ?? Date()
        }
    }
}

private struct DaySection: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let entries: [SymptomEntry]
    let activities: [ActivityEvent]
    let summary: DaySummary?

    static func == (lhs: DaySection, rhs: DaySection) -> Bool {
        lhs.date == rhs.date
    }

    var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        items.append(contentsOf: entries.map { TimelineItem.symptom($0) })
        items.append(contentsOf: activities.map { TimelineItem.activity($0) })
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

    static func sectionsFromArrays(entries: [SymptomEntry], activities: [ActivityEvent]) -> [DaySection] {
        let calendar = Calendar.current

        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
        }

        let groupedActivities = Dictionary(grouping: activities) { activity in
            calendar.startOfDay(for: activity.backdatedAt ?? activity.createdAt ?? Date())
        }

        // Get all unique dates and sort chronologically (oldest first for decay calculation)
        let allDates = Set(groupedEntries.keys).union(Set(groupedActivities.keys)).sorted()

        guard !allDates.isEmpty else { return [] }

        // Calculate load scores progressively with decay chain
        let loadScores = LoadScore.calculateRange(
            from: allDates.first!,
            to: allDates.last!,
            activitiesByDate: groupedActivities,
            symptomsByDate: groupedEntries
        )

        // Create a lookup dictionary for load scores
        let loadScoresByDate = Dictionary(uniqueKeysWithValues: loadScores.map { ($0.date, $0) })

        return allDates
            .map { day in
                let dayEntries = groupedEntries[day] ?? []
                let dayActivities = groupedActivities[day] ?? []
                let sorted = dayEntries.sorted {
                    ($0.backdatedAt ?? $0.createdAt ?? Date()) > ($1.backdatedAt ?? $1.createdAt ?? Date())
                }
                let loadScore = loadScoresByDate[day]
                return DaySection(
                    date: day,
                    entries: sorted,
                    activities: dayActivities,
                    summary: DaySummary.makeWithLoadScore(for: day, entries: sorted, loadScore: loadScore)
                )
            }
            .sorted { $0.date > $1.date }
    }
}
