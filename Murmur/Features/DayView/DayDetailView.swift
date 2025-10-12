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
    @ObservedObject private var loadManager = LoadCapacityManager.shared

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

            // Calibration section
            if loadManager.isCalibrating, let _ = summary {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(palette.accentColor)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Calibration in progress")
                                    .font(.headline)
                                Text("\(loadManager.calibrationDays.count) of 3 good days recorded")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            markGoodDay()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Mark as good day")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(palette.surfaceColor)
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
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        // Stable secondary sort by ID to ensure consistent ordering
        return (lhs.id?.uuidString ?? "") > (rhs.id?.uuidString ?? "")
    }

    private func sortActivities(_ lhs: ActivityEvent, _ rhs: ActivityEvent) -> Bool {
        let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? Date()
        let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? Date()
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        // Stable secondary sort by ID to ensure consistent ordering
        return (lhs.id?.uuidString ?? "") > (rhs.id?.uuidString ?? "")
    }

    private func sortSleepEvents(_ lhs: SleepEvent, _ rhs: SleepEvent) -> Bool {
        let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? Date()
        let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? Date()
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        // Stable secondary sort by ID to ensure consistent ordering
        return (lhs.id?.uuidString ?? "") > (rhs.id?.uuidString ?? "")
    }

    private func sortMealEvents(_ lhs: MealEvent, _ rhs: MealEvent) -> Bool {
        let lhsDate = lhs.backdatedAt ?? lhs.createdAt ?? Date()
        let rhsDate = rhs.backdatedAt ?? rhs.createdAt ?? Date()
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        // Stable secondary sort by ID to ensure consistent ordering
        return (lhs.id?.uuidString ?? "") > (rhs.id?.uuidString ?? "")
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

    private func markGoodDay() {
        guard let loadScore = summary?.loadScore else { return }
        // Use decayedLoad as it represents the actual load impact on this day
        loadManager.recordGoodDay(load: loadScore.decayedLoad)
    }
}

// MARK: - Supporting Views
// Note: Supporting views have been extracted to separate files in the Subviews folder:
// - DayEntryRow.swift
// - DayActivityRow.swift
// - DaySummaryCard.swift (includes MetricTile)
// - DayMetrics.swift
// - LoadScoreCard.swift
// - DaySleepRow.swift
// - DayMealRow.swift
