//
//  TimelineDataController.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell
//

import Foundation
import CoreData
import SwiftUI
import Combine

/// Centralised data controller for timeline view
/// Manages fetched results controllers, load score cache, and day section grouping
@MainActor
final class TimelineDataController: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var daySections: [DaySection] = []
    @Published private(set) var isLoading: Bool = true

    // MARK: - Private Properties

    private let context: NSManagedObjectContext
    private let calendar = Calendar.current
    private let loadScoreCache = LoadScoreCache()

    // Fetched results controllers
    private var entriesFRC: NSFetchedResultsController<SymptomEntry>?
    private var activitiesFRC: NSFetchedResultsController<ActivityEvent>?
    private var sleepEventsFRC: NSFetchedResultsController<SleepEvent>?
    private var mealEventsFRC: NSFetchedResultsController<MealEvent>?

    // Date ranges
    private var displayStartDate: Date
    private var dataStartDate: Date

    // Cached grouped data for efficient access
    private var groupedEntries: [Date: [SymptomEntry]] = [:]
    private var groupedActivities: [Date: [ActivityEvent]] = [:]
    private var groupedSleepEvents: [Date: [SleepEvent]] = [:]
    private var groupedMealEvents: [Date: [MealEvent]] = [:]

    // MARK: - Initialisation

    init(context: NSManagedObjectContext) {
        self.context = context

        // Calculate date ranges
        let today = Calendar.current.startOfDay(for: Date())
        self.displayStartDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        self.dataStartDate = calendar.date(byAdding: .day, value: -90, to: today) ?? today

        super.init()

        setupFetchedResultsControllers()
        performInitialFetch()
    }

    // MARK: - Setup

    private func setupFetchedResultsControllers() {
        // Symptom entries (90 days for load score calculation)
        let entriesRequest = SymptomEntry.fetchRequest()
        entriesRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            dataStartDate as NSDate, dataStartDate as NSDate
        )
        entriesRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
        ]
        entriesRequest.relationshipKeyPathsForPrefetching = ["symptomType"]
        entriesRequest.fetchBatchSize = 50

        entriesFRC = NSFetchedResultsController(
            fetchRequest: entriesRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        entriesFRC?.delegate = self

        // Activity events (90 days for load score calculation)
        let activitiesRequest = ActivityEvent.fetchRequest()
        activitiesRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            dataStartDate as NSDate, dataStartDate as NSDate
        )
        activitiesRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \ActivityEvent.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \ActivityEvent.createdAt, ascending: false)
        ]
        activitiesRequest.fetchBatchSize = 50

        activitiesFRC = NSFetchedResultsController(
            fetchRequest: activitiesRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        activitiesFRC?.delegate = self

        // Sleep events (30 days display only)
        let sleepRequest = SleepEvent.fetchRequest()
        sleepRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            displayStartDate as NSDate, displayStartDate as NSDate
        )
        sleepRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SleepEvent.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SleepEvent.createdAt, ascending: false)
        ]
        sleepRequest.fetchBatchSize = 20

        sleepEventsFRC = NSFetchedResultsController(
            fetchRequest: sleepRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        sleepEventsFRC?.delegate = self

        // Meal events (30 days display only)
        let mealsRequest = MealEvent.fetchRequest()
        mealsRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            displayStartDate as NSDate, displayStartDate as NSDate
        )
        mealsRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \MealEvent.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: false)
        ]
        mealsRequest.fetchBatchSize = 20

        mealEventsFRC = NSFetchedResultsController(
            fetchRequest: mealsRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        mealEventsFRC?.delegate = self
    }

    private func performInitialFetch() {
        do {
            try entriesFRC?.performFetch()
            try activitiesFRC?.performFetch()
            try sleepEventsFRC?.performFetch()
            try mealEventsFRC?.performFetch()

            rebuildDaySections()
            isLoading = false
        } catch {
            print("Error performing initial fetch: \(error)")
        }
    }

    // MARK: - Data Grouping and Section Building

    private func rebuildDaySections() {
        // Group data by date
        groupedEntries = groupByDate(entriesFRC?.fetchedObjects ?? [])
        groupedActivities = groupByDate(activitiesFRC?.fetchedObjects ?? [])
        groupedSleepEvents = groupByDate(sleepEventsFRC?.fetchedObjects ?? [])
        groupedMealEvents = groupByDate(mealEventsFRC?.fetchedObjects ?? [])

        // Calculate display dates (union of all dates with display data)
        let displayDates = Set(groupedEntries.keys)
            .union(groupedActivities.keys)
            .union(groupedSleepEvents.keys)
            .union(groupedMealEvents.keys)
            .filter { $0 >= displayStartDate }

        guard !displayDates.isEmpty else {
            daySections = []
            return
        }

        // Calculate load score range using cache
        let allDataDates = Set(groupedEntries.keys).union(groupedActivities.keys)
        let firstDate = allDataDates.min() ?? displayStartDate
        let lastDate = displayDates.max() ?? displayStartDate

        let loadScores = loadScoreCache.calculateRange(
            from: firstDate,
            to: lastDate,
            activitiesByDate: groupedActivities,
            symptomsByDate: groupedEntries
        )

        let loadScoresByDate: [Date: LoadScore] = Dictionary(uniqueKeysWithValues: loadScores.map { ($0.date, $0) })

        // Build day sections
        daySections = displayDates.sorted(by: >).map { date in
            createDaySection(
                for: date,
                entries: groupedEntries[date] ?? [],
                activities: groupedActivities[date] ?? [],
                sleepEvents: groupedSleepEvents[date] ?? [],
                mealEvents: groupedMealEvents[date] ?? [],
                loadScore: loadScoresByDate[date]
            )
        }
    }

    private func groupByDate<T: NSManagedObject>(_ objects: [T]) -> [Date: [T]] {
        Dictionary(grouping: objects) { object in
            let date: Date
            if let backdatedAt = object.value(forKey: "backdatedAt") as? Date {
                date = backdatedAt
            } else if let createdAt = object.value(forKey: "createdAt") as? Date {
                date = createdAt
            } else {
                date = Date()
            }
            return calendar.startOfDay(for: date)
        }
    }

    private func createDaySection(for date: Date, entries: [SymptomEntry],
                                  activities: [ActivityEvent], sleepEvents: [SleepEvent],
                                  mealEvents: [MealEvent], loadScore: LoadScore?) -> DaySection {
        // Sort entries by time (most recent first)
        let sortedEntries = entries.sorted { a, b in
            let dateA = a.backdatedAt ?? a.createdAt ?? Date.distantPast
            let dateB = b.backdatedAt ?? b.createdAt ?? Date.distantPast
            return dateA > dateB
        }

        let summary = DaySummary.makeWithLoadScore(for: date, entries: sortedEntries, loadScore: loadScore)

        return DaySection(
            date: date,
            entries: sortedEntries,
            activities: activities,
            sleepEvents: sleepEvents,
            mealEvents: mealEvents,
            summary: summary
        )
    }

    // MARK: - Public API

    /// Updates date ranges (e.g., at midnight or when user changes settings)
    func updateDateRanges() {
        let today = calendar.startOfDay(for: Date())
        let newDisplayStart = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let newDataStart = calendar.date(byAdding: .day, value: -90, to: today) ?? today

        guard newDisplayStart != displayStartDate || newDataStart != dataStartDate else {
            return
        }

        displayStartDate = newDisplayStart
        dataStartDate = newDataStart

        // Update predicates and refetch
        setupFetchedResultsControllers()
        performInitialFetch()
    }

    /// Invalidates load score cache when configuration changes
    func invalidateLoadScoreCache() {
        loadScoreCache.invalidateAll()
        rebuildDaySections()
    }

    /// Returns cache statistics for debugging
    func cacheStatistics() -> (entries: Int, hits: Int, misses: Int, hitRate: Double) {
        loadScoreCache.statistics()
    }

    /// Prunes old cache entries to manage memory
    func pruneOldCacheEntries(olderThan days: Int = 120) {
        loadScoreCache.pruneOlderThan(days: days)
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension TimelineDataController: NSFetchedResultsControllerDelegate {
    nonisolated func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        Task { @MainActor in
            // Changes to any data affect the timeline
            // Invalidate cache and rebuild (conservative approach)
            loadScoreCache.invalidateAll()
            rebuildDaySections()
        }
    }
}

// Note: DaySection is defined in TimelineView.swift and used here

// MARK: - ResourceManageable conformance

extension TimelineDataController: ResourceManageable {
    nonisolated func start() async throws {
        // Fetched results controllers are set up in init
        // No additional initialisation required
    }

    nonisolated func cleanup() {
        Task { @MainActor in
            _cleanup()
        }
    }

    @MainActor
    private func _cleanup() {
        // Clear FRC delegates to break retain cycles
        entriesFRC?.delegate = nil
        activitiesFRC?.delegate = nil
        sleepEventsFRC?.delegate = nil
        mealEventsFRC?.delegate = nil

        // Clear cached data
        groupedEntries.removeAll()
        groupedActivities.removeAll()
        groupedSleepEvents.removeAll()
        groupedMealEvents.removeAll()
        daySections.removeAll()

        // Prune old cache entries (keep last 90 days)
        loadScoreCache.pruneOlderThan(days: 90)
    }
}
