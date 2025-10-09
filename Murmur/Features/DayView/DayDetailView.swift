//
//  DayDetailView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CoreData
import CoreLocation
import SwiftUI

struct DayDetailView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @EnvironmentObject private var healthKit: HealthKitAssistant

    private let date: Date
    @FetchRequest private var symptomTypes: FetchedResults<SymptomType>

    @State private var severityByType: [UUID: Double] = [:]
    @State private var noteByType: [UUID: String] = [:]
    @State private var entriesByType: [UUID: SymptomEntry] = [:]
    @State private var dayEntries: [SymptomEntry] = []
    @State private var dayActivities: [ActivityEvent] = []
    @State private var daySleepEvents: [SleepEvent] = []
    @State private var dayMealEvents: [MealEvent] = []
    @State private var summary: DaySummary?
    @State private var previousSummary: DaySummary?
    @State private var metrics: DayMetrics?
    @State private var errorMessage: String?

    private let calendar = Calendar.current

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    private var starredSymptoms: [SymptomType] {
        symptomTypes.filter { $0.isStarred }
    }

    private var unstarredSymptoms: [SymptomType] {
        symptomTypes.filter { !$0.isStarred }
    }

    init(date: Date) {
        self.date = date
        let sort = [
            NSSortDescriptor(keyPath: \SymptomType.isStarred, ascending: false),
            NSSortDescriptor(keyPath: \SymptomType.starOrder, ascending: true),
            NSSortDescriptor(keyPath: \SymptomType.name, ascending: true)
        ]
        _symptomTypes = FetchRequest(entity: SymptomType.entity(), sortDescriptors: sort)
    }

    var body: some View {
        List {
            if let summary {
                Section {
                    DaySummaryCard(summary: summary, comparison: previousSummary, metrics: metrics)
                }
                .listRowBackground(summary.dominantColor(for: colorScheme).opacity(0.1))
            }

            if !dayEntries.isEmpty {
                Section("Symptoms") {
                    ForEach(dayEntries.sorted(by: sortEntries)) { entry in
                        DayEntryRow(entry: entry)
                    }
                    .onDelete(perform: deleteEntries)
                }
                .listRowBackground(palette.surfaceColor)
            }

            if !dayActivities.isEmpty {
                Section("Activities") {
                    ForEach(dayActivities.sorted(by: sortActivities)) { activity in
                        DayActivityRow(activity: activity)
                    }
                    .onDelete(perform: deleteActivities)
                }
                .listRowBackground(palette.surfaceColor)
            }

            if !daySleepEvents.isEmpty {
                Section("Sleep") {
                    ForEach(daySleepEvents.sorted(by: sortSleepEvents)) { sleep in
                        DaySleepRow(sleep: sleep)
                    }
                    .onDelete(perform: deleteSleepEvents)
                }
                .listRowBackground(palette.surfaceColor)
            }

            if !dayMealEvents.isEmpty {
                Section("Meals") {
                    ForEach(dayMealEvents.sorted(by: sortMealEvents)) { meal in
                        DayMealRow(meal: meal)
                    }
                    .onDelete(perform: deleteMealEvents)
                }
                .listRowBackground(palette.surfaceColor)
            }

            if dayEntries.isEmpty && dayActivities.isEmpty && daySleepEvents.isEmpty && dayMealEvents.isEmpty {
                Section {
                    Text("Nothing logged on this day.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(palette.surfaceColor)
            }

            if !dayEntries.isEmpty {
                Section("Accessibility") {
                    AudioGraphButton(entries: dayEntries)
                    DayAudioSummaryButton(entries: dayEntries, date: date)
                }
                .listRowBackground(palette.surfaceColor)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .listRowBackground(palette.surfaceColor)
            }
        }
        .listStyle(.insetGrouped)
        .themedScrollBackground()
        .navigationTitle(formatted(date: date))
        .accessibilityIdentifier(AccessibilityIdentifiers.dayDetailList)
        .onAppear(perform: bootstrap)
    }

    private func bootstrap() {
        do {
            let entries = try fetchEntries(for: date)
            let activities = try fetchActivities(for: date)
            let sleepEvents = try fetchSleepEvents(for: date)
            let mealEvents = try fetchMealEvents(for: date)
            dayActivities = activities.sorted(by: sortActivities)
            daySleepEvents = sleepEvents.sorted(by: sortSleepEvents)
            dayMealEvents = mealEvents.sorted(by: sortMealEvents)

            // Calculate load score with proper decay chain
            let loadScore = try calculateLoadScore(for: date)

            apply(entries: entries, loadScore: loadScore)

            if let previousDay = calendar.date(byAdding: .day, value: -1, to: date) {
                let previousEntries = try fetchEntries(for: previousDay)
                let previousLoadScore = try calculateLoadScore(for: previousDay)
                previousSummary = DaySummary.makeWithLoadScore(for: previousDay, entries: previousEntries, loadScore: previousLoadScore)
            }
            refreshMetrics()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func calculateLoadScore(for targetDate: Date) throws -> LoadScore? {
        // Load scores decay over time, so we only need recent data (60 days before target date)
        let dayStart = calendar.startOfDay(for: targetDate)
        guard let lookbackStart = calendar.date(byAdding: .day, value: -60, to: dayStart) else { return nil }

        let allEntries = try fetchRecentEntries(since: lookbackStart)
        let allActivities = try fetchRecentActivities(since: lookbackStart)

        guard !allEntries.isEmpty || !allActivities.isEmpty else { return nil }

        let groupedEntries = Dictionary(grouping: allEntries) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
        }

        let groupedActivities = Dictionary(grouping: allActivities) { activity in
            calendar.startOfDay(for: activity.backdatedAt ?? activity.createdAt ?? Date())
        }

        let allDates = Set(groupedEntries.keys).union(Set(groupedActivities.keys)).sorted()
        guard let firstDate = allDates.first else { return nil }

        let loadScores = LoadScore.calculateRange(
            from: firstDate,
            to: dayStart,
            activitiesByDate: groupedActivities,
            symptomsByDate: groupedEntries
        )

        return loadScores.first { $0.date == dayStart }
    }

    private func fetchRecentEntries(since date: Date) throws -> [SymptomEntry] {
        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))", date as NSDate, date as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: true),
                                   NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: true)]
        request.relationshipKeyPathsForPrefetching = ["symptomType"]
        return try context.fetch(request)
    }

    private func fetchRecentActivities(since date: Date) throws -> [ActivityEvent] {
        let request = ActivityEvent.fetchRequest()
        request.predicate = NSPredicate(format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))", date as NSDate, date as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivityEvent.backdatedAt, ascending: true),
                                   NSSortDescriptor(keyPath: \ActivityEvent.createdAt, ascending: true)]
        return try context.fetch(request)
    }

    private func refreshMetrics() {
        guard !dayEntries.isEmpty else {
            metrics = nil
            return
        }
        metrics = DayMetrics(entries: dayEntries)
    }

    private func apply(entries: [SymptomEntry], loadScore: LoadScore?) {
        let sorted = entries.sorted(by: sortEntries)
        dayEntries = sorted
        var severity: [UUID: Double] = [:]
        var notes: [UUID: String] = [:]
        var map: [UUID: SymptomEntry] = [:]
        for entry in sorted {
            guard let type = entry.symptomType, let id = type.id else { continue }
            severity[id] = Double(entry.severity)
            if let note = entry.note { notes[id] = note }
            map[id] = entry
        }
        severityByType = severity
        noteByType = notes
        entriesByType = map
        summary = DaySummary.makeWithLoadScore(for: date, entries: sorted, loadScore: loadScore)
        refreshMetrics()
    }

    private func fetchEntries(for targetDate: Date) throws -> [SymptomEntry] {
        let request = SymptomEntry.fetchRequest()
        let dayStart = calendar.startOfDay(for: targetDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            dayStart as NSDate, dayEnd as NSDate, dayStart as NSDate, dayEnd as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
                                   NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)]
        return try context.fetch(request)
    }

    private func fetchActivities(for targetDate: Date) throws -> [ActivityEvent] {
        let request = ActivityEvent.fetchRequest()
        let dayStart = calendar.startOfDay(for: targetDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            dayStart as NSDate, dayEnd as NSDate, dayStart as NSDate, dayEnd as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ActivityEvent.backdatedAt, ascending: false),
                                   NSSortDescriptor(keyPath: \ActivityEvent.createdAt, ascending: false)]
        return try context.fetch(request)
    }

    private func fetchSleepEvents(for targetDate: Date) throws -> [SleepEvent] {
        let request = SleepEvent.fetchRequest()
        let dayStart = calendar.startOfDay(for: targetDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            dayStart as NSDate, dayEnd as NSDate, dayStart as NSDate, dayEnd as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepEvent.backdatedAt, ascending: false),
                                   NSSortDescriptor(keyPath: \SleepEvent.createdAt, ascending: false)]
        return try context.fetch(request)
    }

    private func fetchMealEvents(for targetDate: Date) throws -> [MealEvent] {
        let request = MealEvent.fetchRequest()
        let dayStart = calendar.startOfDay(for: targetDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            dayStart as NSDate, dayEnd as NSDate, dayStart as NSDate, dayEnd as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEvent.backdatedAt, ascending: false),
                                   NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: false)]
        return try context.fetch(request)
    }

    private func updateEntry(for type: SymptomType, severity: Int, note: String?, updateContext: Bool, persistMood: Bool) {
        let severity = max(1, min(5, severity))
        let dayStart = calendar.startOfDay(for: date)
        guard let typeId = type.id else { return }
        let existing = entriesByType[typeId]
        let entry = existing ?? SymptomEntry(context: context)

        if existing == nil {
            entry.id = UUID()
            entry.createdAt = Date()
            entry.backdatedAt = dayStart
            entry.symptomType = type
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedNote, !trimmedNote.isEmpty {
            entry.note = trimmedNote
        } else if note != nil {
            entry.note = nil
        }

        entry.severity = Int16(severity)

        Task { @MainActor in
            if updateContext {
                if let hrv = await healthKit.recentHRV() {
                    entry.hkHRV = NSNumber(value: hrv)
                }
                if let rhr = await healthKit.recentRestingHR() {
                    entry.hkRestingHR = NSNumber(value: rhr)
                }
            }
            do {
                try context.save()
                entriesByType[typeId] = entry
                severityByType[typeId] = Double(severity)
                noteByType[typeId] = entry.note ?? ""
                let refreshed = try fetchEntries(for: date)
                let loadScore = try calculateLoadScore(for: date)
                apply(entries: refreshed, loadScore: loadScore)
            } catch {
                errorMessage = error.localizedDescription
                context.rollback()
            }
        }
    }

    private func formatted(date: Date) -> String {
        DateFormatters.shortDate.string(from: date)
    }

    private func sortEntries(_ lhs: SymptomEntry, _ rhs: SymptomEntry) -> Bool {
        let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? Date()
        let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? Date()
        return lhsDate > rhsDate
    }

    private func sortActivities(_ lhs: ActivityEvent, _ rhs: ActivityEvent) -> Bool {
        let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? Date()
        let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? Date()
        return lhsDate > rhsDate
    }

    private func sortSleepEvents(_ lhs: SleepEvent, _ rhs: SleepEvent) -> Bool {
        let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? Date()
        let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? Date()
        return lhsDate > rhsDate
    }

    private func sortMealEvents(_ lhs: MealEvent, _ rhs: MealEvent) -> Bool {
        let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? Date()
        let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? Date()
        return lhsDate > rhsDate
    }

    private func deleteEntries(at offsets: IndexSet) {
        let sortedEntries = dayEntries.sorted(by: sortEntries)
        for index in offsets {
            let entry = sortedEntries[index]
            context.delete(entry)
            if let typeId = entry.symptomType?.id {
                entriesByType.removeValue(forKey: typeId)
                severityByType.removeValue(forKey: typeId)
                noteByType.removeValue(forKey: typeId)
            }
        }

        do {
            try context.save()
            let refreshed = try fetchEntries(for: date)
            let loadScore = try calculateLoadScore(for: date)
            apply(entries: refreshed, loadScore: loadScore)
        } catch {
            errorMessage = error.localizedDescription
            context.rollback()
        }
    }

    private func deleteActivities(at offsets: IndexSet) {
        let sortedActivities = dayActivities.sorted(by: sortActivities)
        for index in offsets {
            let activity = sortedActivities[index]
            context.delete(activity)
        }

        do {
            try context.save()
            dayActivities = try fetchActivities(for: date).sorted(by: sortActivities)
            // Recalculate load score and summary after activity deletion
            let refreshedEntries = try fetchEntries(for: date)
            let loadScore = try calculateLoadScore(for: date)
            apply(entries: refreshedEntries, loadScore: loadScore)
        } catch {
            errorMessage = error.localizedDescription
            context.rollback()
        }
    }

    private func deleteSleepEvents(at offsets: IndexSet) {
        let sortedSleepEvents = daySleepEvents.sorted(by: sortSleepEvents)
        for index in offsets {
            let sleep = sortedSleepEvents[index]
            context.delete(sleep)
        }

        do {
            try context.save()
            daySleepEvents = try fetchSleepEvents(for: date).sorted(by: sortSleepEvents)
            // Recalculate summary after deletion
            let refreshedEntries = try fetchEntries(for: date)
            let loadScore = try calculateLoadScore(for: date)
            apply(entries: refreshedEntries, loadScore: loadScore)
        } catch {
            errorMessage = error.localizedDescription
            context.rollback()
        }
    }

    private func deleteMealEvents(at offsets: IndexSet) {
        let sortedMealEvents = dayMealEvents.sorted(by: sortMealEvents)
        for index in offsets {
            let meal = sortedMealEvents[index]
            context.delete(meal)
        }

        do {
            try context.save()
            dayMealEvents = try fetchMealEvents(for: date).sorted(by: sortMealEvents)
            // Recalculate summary after deletion
            let refreshedEntries = try fetchEntries(for: date)
            let loadScore = try calculateLoadScore(for: date)
            apply(entries: refreshedEntries, loadScore: loadScore)
        } catch {
            errorMessage = error.localizedDescription
            context.rollback()
        }
    }
}

private struct DayEntryRow: View {
    let entry: SymptomEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(entry.symptomType?.name ?? "Unnamed", systemImage: entry.symptomType?.iconName ?? "circle")
                    .labelStyle(.titleAndIcon)
                Spacer()
                SeverityBadge(value: Double(entry.severity), precision: .integer, isPositive: entry.symptomType?.isPositive ?? false)
            }
            HStack(spacing: 12) {
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let state = physiologicalState {
                    HStack(spacing: 4) {
                        Image(systemName: state.iconName)
                        Text(state.displayText)
                    }
                    .font(.caption2)
                    .foregroundStyle(state.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(state.color.opacity(0.15), in: Capsule())
                }
                if let cycleDay = entry.hkCycleDay?.intValue {
                    Text("Cycle day \(cycleDay)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
            }
            Text(SeverityScale.descriptor(for: Int(entry.severity), isPositive: entry.symptomType?.isPositive ?? false))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(.callout)
            }
            if let location = entry.locationPlacemark, !LocationAssistant.formatted(placemark: location).isEmpty {
                Label(LocationAssistant.formatted(placemark: location), systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Swipe left to delete this entry")
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

        let severityDesc = SeverityScale.descriptor(for: Int(entry.severity), isPositive: entry.symptomType?.isPositive ?? false)
        parts.append("Level \(entry.severity): \(severityDesc)")

        if let state = physiologicalState {
            parts.append(state.displayText)
        }

        if let cycleDay = entry.hkCycleDay?.intValue {
            parts.append("Cycle day \(cycleDay)")
        }

        if let note = entry.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }

        if let location = entry.locationPlacemark {
            let formatted = LocationAssistant.formatted(placemark: location)
            if !formatted.isEmpty {
                parts.append("Location: \(formatted)")
            }
        }

        return parts.joined(separator: ". ")
    }
}

private struct DayActivityRow: View {
    let activity: ActivityEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(activity.name ?? "Unnamed activity", systemImage: "calendar")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.purple)
                Spacer()
            }
            HStack(spacing: 12) {
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let duration = activity.durationMinutes?.intValue {
                    Text("\(duration) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Physical")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        Image(systemName: "figure.walk")
                        Text("\(activity.physicalExertion)")
                    }
                    .font(.caption)
                    .foregroundStyle(.purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cognitive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        Image(systemName: "brain.head.profile")
                        Text("\(activity.cognitiveExertion)")
                    }
                    .font(.caption)
                    .foregroundStyle(.purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Emotional")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        Image(systemName: "heart")
                        Text("\(activity.emotionalLoad)")
                    }
                    .font(.caption)
                    .foregroundStyle(.purple)
                }
            }
            if let note = activity.note, !note.isEmpty {
                Text(note)
                    .font(.callout)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Swipe left to delete this activity")
    }

    private var timeLabel: String {
        let reference = activity.backdatedAt ?? activity.createdAt ?? Date()
        return DateFormatters.shortTime.string(from: reference)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append("Activity: \(activity.name ?? "Unnamed") at \(timeLabel)")

        if let duration = activity.durationMinutes?.intValue {
            parts.append("Duration: \(duration) minutes")
        }

        parts.append("Physical exertion: level \(activity.physicalExertion)")
        parts.append("Cognitive exertion: level \(activity.cognitiveExertion)")
        parts.append("Emotional load: level \(activity.emotionalLoad)")

        if let note = activity.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }

        return parts.joined(separator: ". ")
    }
}

private struct DaySummaryCard: View {
    let summary: DaySummary
    let comparison: DaySummary?
    let metrics: DayMetrics?

    @Environment(\.colorScheme) private var colorScheme

    private var severityTint: Color {
        summary.dominantColor(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average intensity")
                        .font(.headline)
                    ProgressView(value: min(summary.rawAverageSeverity, 5), total: 5)
                        .tint(severityTint)
                }
                Spacer()
                SeverityBadge(value: summary.rawAverageSeverity)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Average intensity: \(SeverityScale.descriptor(for: Int(summary.rawAverageSeverity)))")

            HStack(spacing: 16) {
                MetricTile(title: "Logged", value: "\(summary.entryCount)")
                MetricTile(title: "Different symptoms", value: "\(summary.uniqueSymptoms)")
                if let comparison, let delta = delta(from: comparison) {
                    MetricTile(title: "vs yesterday", value: delta, emphasizesTrend: true)
                }
            }

            if let metrics, (metrics.predominantState != nil || metrics.cycleDay != nil || (metrics.averageHRV ?? 0) > 0 || (metrics.averageRestingHR ?? 0) > 0 || metrics.primaryLocation != nil) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        if let state = metrics.predominantState {
                            MetricTile(title: "Feeling", value: state.displayText)
                        }
                        if let cycleDay = metrics.cycleDay, cycleDay > 0 {
                            MetricTile(title: "Cycle day", value: "Day \(cycleDay)")
                        }
                        if let hrv = metrics.averageHRV, hrv > 0 {
                            MetricTile(title: "HRV", value: String(format: "%.0f ms", hrv))
                        }
                        if let resting = metrics.averageRestingHR, resting > 0 {
                            MetricTile(title: "Heart rate", value: String(format: "%.0f bpm", resting))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())

                    if let location = metrics.primaryLocation {
                        Label(location, systemImage: "location.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let loadScore = summary.loadScore, shouldShowLoadScore(loadScore) {
                LoadScoreCard(loadScore: loadScore)
            }
        }
        .padding(.vertical, 8)
    }

    private func shouldShowLoadScore(_ loadScore: LoadScore) -> Bool {
        // Only show if there's meaningful load (> 0) or activities have been logged
        return loadScore.decayedLoad > 0.1 || loadScore.rawLoad > 0.1
    }

    private func delta(from comparison: DaySummary) -> String? {
        let difference = summary.averageSeverity - comparison.averageSeverity
        guard abs(difference) >= 0.1 else { return "∙" }
        let symbol = difference >= 0 ? "▲" : "▼"
        return "\(symbol) \(String(format: "%.1f", abs(difference)))"
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    var emphasizesTrend: Bool = false
    var secondary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(emphasizesTrend ? .caption.bold() : .body.bold())
                .foregroundStyle(emphasizesTrend ? .orange : .primary)
            if let secondary {
                Text(secondary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DayMetrics {
    let averageHRV: Double?
    let averageRestingHR: Double?
    let primaryLocation: String?
    let predominantState: PhysiologicalState?
    let cycleDay: Int?

    @MainActor
    init(entries: [SymptomEntry]) {
        let hrvValues = entries.compactMap { $0.hkHRV?.doubleValue }
        averageHRV = hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count)
        let restingValues = entries.compactMap { $0.hkRestingHR?.doubleValue }
        averageRestingHR = restingValues.isEmpty ? nil : restingValues.reduce(0, +) / Double(restingValues.count)
        let locationStrings = entries.compactMap { entry -> String? in
            guard let placemark = entry.locationPlacemark else { return nil }
            let formatted = DayMetrics.format(placemark: placemark)
            return formatted.isEmpty ? nil : formatted
        }
        primaryLocation = locationStrings.first

        // Compute predominant physiological state
        let states = entries.compactMap { entry -> PhysiologicalState? in
            PhysiologicalState.compute(
                hrv: entry.hkHRV?.doubleValue,
                restingHR: entry.hkRestingHR?.doubleValue,
                sleepHours: entry.hkSleepHours?.doubleValue,
                workoutMinutes: entry.hkWorkoutMinutes?.doubleValue,
                cycleDay: entry.hkCycleDay?.intValue,
                flowLevel: entry.hkFlowLevel
            )
        }

        if !states.isEmpty {
            let stateCounts = Dictionary(grouping: states, by: { $0 })
            predominantState = stateCounts.max { $0.value.count < $1.value.count }?.key
        } else {
            predominantState = nil
        }

        // Get cycle day from most recent entry
        cycleDay = entries.first?.hkCycleDay?.intValue
    }

    private static func format(placemark: CLPlacemark) -> String {
        [placemark.subLocality, placemark.locality, placemark.country]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

private struct LoadScoreCard: View {
    let loadScore: LoadScore
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .foregroundStyle(colorForRisk)
                Text("Activity load")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(loadScore.decayedLoad))%")
                    .font(.title3.bold())
                    .foregroundStyle(colorForRisk)
            }

            ProgressView(value: min(loadScore.decayedLoad, 100), total: 100)
                .tint(colorForRisk)

            HStack {
                Text(loadScore.riskLevel.description)
                    .font(.caption.bold())
                    .foregroundStyle(colorForRisk)
                Spacer()
                Text(riskAdvice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(colorForRisk.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var colorForRisk: Color {
        loadScore.riskLevel.displayColor
    }

    private var riskAdvice: String {
        switch loadScore.riskLevel {
        case .safe: return "Good capacity"
        case .caution: return "Monitor energy"
        case .high: return "Consider pacing"
        case .critical: return "Prioritise rest"
        }
    }

    private var accessibilityDescription: String {
        "Activity load: \(Int(loadScore.decayedLoad)) percent. Risk level: \(loadScore.riskLevel.description). \(riskAdvice)"
    }
}

private struct DaySleepRow: View {
    let sleep: SleepEvent

    private var hasHealthMetrics: Bool {
        sleep.hkSleepHours != nil || sleep.hkHRV != nil || sleep.hkRestingHR != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Sleep", systemImage: "moon.stars.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.indigo)
                Spacer()
            }
            HStack(spacing: 12) {
                if let bedTime = sleep.bedTime {
                    Text(DateFormatters.shortTime.string(from: bedTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let duration = sleepDuration {
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(sleep.quality)/5")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if hasHealthMetrics {
                HStack(spacing: 12) {
                    if let sleepHours = sleep.hkSleepHours?.doubleValue {
                        Text(String(format: "%.1fh sleep", sleepHours))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let hrv = sleep.hkHRV?.doubleValue {
                        Text(String(format: "%.0f ms HRV", hrv))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let rhr = sleep.hkRestingHR?.doubleValue {
                        Text(String(format: "%.0f bpm", rhr))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let symptoms = sleep.symptoms as? Set<SymptomType>, !symptoms.isEmpty {
                let symptomNames = symptoms.compactMap { $0.name }.sorted()
                Text("Symptoms: \(symptomNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let note = sleep.note, !note.isEmpty {
                Text(note)
                    .font(.callout)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Swipe left to delete this sleep event")
    }

    private var sleepDuration: String? {
        guard let bedTime = sleep.bedTime, let wakeTime = sleep.wakeTime else { return nil }
        let hours = wakeTime.timeIntervalSince(bedTime) / 3600
        return String(format: "%.1fh", hours)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if let bedTime = sleep.bedTime {
            parts.append("Sleep at \(DateFormatters.shortTime.string(from: bedTime))")
        } else {
            parts.append("Sleep")
        }
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
        if let symptoms = sleep.symptoms as? Set<SymptomType>, !symptoms.isEmpty {
            let symptomNames = symptoms.compactMap { $0.name }.sorted()
            parts.append("Symptoms: \(symptomNames.joined(separator: ", "))")
        }
        if let note = sleep.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }
        return parts.joined(separator: ". ")
    }
}

private struct DayMealRow: View {
    let meal: MealEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(meal.mealType?.capitalized ?? "Meal", systemImage: "fork.knife")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.orange)
                Spacer()
            }
            HStack(spacing: 12) {
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let description = meal.mealDescription, !description.isEmpty {
                Text(description)
                    .font(.callout)
            }
            if let note = meal.note, !note.isEmpty {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Swipe left to delete this meal")
    }

    private var timeLabel: String {
        let reference = meal.backdatedAt ?? meal.createdAt ?? Date()
        return DateFormatters.shortTime.string(from: reference)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append("\(meal.mealType?.capitalized ?? "Meal") at \(timeLabel)")
        if let description = meal.mealDescription, !description.isEmpty {
            parts.append("Description: \(description)")
        }
        if let note = meal.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }
        return parts.joined(separator: ". ")
    }
}
