// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// TimelineDataController.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Controller managing timeline data fetching and updates.
//
import Foundation
import CoreData
import SwiftUI
import Combine
import os

/// Notification posted when data needs to be refreshed (e.g., after restore)
extension Notification.Name {
    static let timelineDataDidChange = Notification.Name("timelineDataDidChange")
}

/// Centralised data controller for timeline view
/// Manages fetched results controllers, load score cache, and day section grouping
@MainActor
final class TimelineDataController: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var daySections: [DaySection] = []
    @Published private(set) var isLoading: Bool = true

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "app.murmur", category: "TimelineData")
    private let context: NSManagedObjectContext
    private let calendar = Calendar.current
    private let loadScoreCache = LoadScoreCache()
    private var cancellables = Set<AnyCancellable>()

    // Fetched results controllers
    private var entriesFRC: NSFetchedResultsController<SymptomEntry>?
    private var activitiesFRC: NSFetchedResultsController<ActivityEvent>?
    private var sleepEventsFRC: NSFetchedResultsController<SleepEvent>?
    private var mealEventsFRC: NSFetchedResultsController<MealEvent>?
    private var reflectionsFRC: NSFetchedResultsController<DayReflection>?

    // Date ranges
    private var displayStartDate: Date
    private var dataStartDate: Date

    // Cached grouped data for efficient access
    private var groupedEntries: [Date: [SymptomEntry]] = [:]
    private var groupedActivities: [Date: [ActivityEvent]] = [:]
    private var groupedSleepEvents: [Date: [SleepEvent]] = [:]
    private var groupedMealEvents: [Date: [MealEvent]] = [:]
    private var groupedReflections: [Date: Double] = [:]

    // MARK: - Initialisation

    init(context: NSManagedObjectContext) {
        self.context = context

        // Calculate date ranges
        let today = Calendar.current.startOfDay(for: DateUtility.now())
        self.displayStartDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        // Use consistent lookback period from LoadCalculator for all data types
        // Fetch from lookbackDays before the earliest displayed date to ensure full historical context
        self.dataStartDate = calendar.date(byAdding: .day, value: -LoadCalculator.lookbackDays, to: displayStartDate) ?? displayStartDate

        super.init()

        setupFetchedResultsControllers()
        performInitialFetch()
        observeDataChangeNotifications()
    }

    private func observeDataChangeNotifications() {
        // Listen for data change notifications (e.g., after restore)
        NotificationCenter.default.publisher(for: .timelineDataDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.forceRefresh()
            }
            .store(in: &cancellables)

        // Also listen for Core Data remote change notifications
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                // Only refresh if the notification is from a different context
                if let savedContext = notification.object as? NSManagedObjectContext,
                   savedContext != self.context {
                    self.context.perform {
                        self.context.refreshAllObjects()
                    }
                    self.forceRefresh()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Setup

    private func setupFetchedResultsControllers() {
        // All event types use consistent lookback period for accurate load score calculations
        // Symptom entries
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

        // Activity events
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

        // Sleep events (now uses dataStartDate for consistent load calculations)
        let sleepRequest = SleepEvent.fetchRequest()
        sleepRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            dataStartDate as NSDate, dataStartDate as NSDate
        )
        sleepRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SleepEvent.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SleepEvent.createdAt, ascending: false)
        ]
        sleepRequest.fetchBatchSize = 50

        sleepEventsFRC = NSFetchedResultsController(
            fetchRequest: sleepRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        sleepEventsFRC?.delegate = self

        // Meal events (now uses dataStartDate for consistent load calculations)
        let mealsRequest = MealEvent.fetchRequest()
        mealsRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            dataStartDate as NSDate, dataStartDate as NSDate
        )
        mealsRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \MealEvent.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: false)
        ]
        mealsRequest.fetchBatchSize = 50

        mealEventsFRC = NSFetchedResultsController(
            fetchRequest: mealsRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        mealEventsFRC?.delegate = self

        // Day reflections (for load multiplier adjustments)
        let reflectionsRequest = DayReflection.fetchRequest()
        reflectionsRequest.predicate = NSPredicate(
            format: "date >= %@",
            dataStartDate as NSDate
        )
        reflectionsRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \DayReflection.date, ascending: false)
        ]
        reflectionsRequest.fetchBatchSize = 50

        reflectionsFRC = NSFetchedResultsController(
            fetchRequest: reflectionsRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        reflectionsFRC?.delegate = self
    }

    private func performInitialFetch() {
        do {
            try entriesFRC?.performFetch()
            try activitiesFRC?.performFetch()
            try sleepEventsFRC?.performFetch()
            try mealEventsFRC?.performFetch()
            try reflectionsFRC?.performFetch()

            rebuildDaySections()
            isLoading = false

            // Validate FRC data against database counts
            Task {
                await validateDataIntegrity()
            }
        } catch {
            logger.error("Error performing initial fetch: \(error)")
        }
    }

    /// Validates that FRC data matches database reality
    /// If there's a significant mismatch, triggers a force refresh
    private func validateDataIntegrity() async {
        let frcEntryCount = entriesFRC?.fetchedObjects?.count ?? 0
        let frcActivityCount = activitiesFRC?.fetchedObjects?.count ?? 0
        let frcSleepCount = sleepEventsFRC?.fetchedObjects?.count ?? 0
        let frcMealCount = mealEventsFRC?.fetchedObjects?.count ?? 0

        // Query actual database counts
        let dbCounts = await context.perform { [context, dataStartDate] in
            let entryRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
            entryRequest.predicate = NSPredicate(
                format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
                dataStartDate as NSDate, dataStartDate as NSDate
            )

            let activityRequest: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
            activityRequest.predicate = NSPredicate(
                format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
                dataStartDate as NSDate, dataStartDate as NSDate
            )

            let sleepRequest: NSFetchRequest<SleepEvent> = SleepEvent.fetchRequest()
            sleepRequest.predicate = NSPredicate(
                format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
                dataStartDate as NSDate, dataStartDate as NSDate
            )

            let mealRequest: NSFetchRequest<MealEvent> = MealEvent.fetchRequest()
            mealRequest.predicate = NSPredicate(
                format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
                dataStartDate as NSDate, dataStartDate as NSDate
            )

            return (
                entries: (try? context.count(for: entryRequest)) ?? 0,
                activities: (try? context.count(for: activityRequest)) ?? 0,
                sleep: (try? context.count(for: sleepRequest)) ?? 0,
                meals: (try? context.count(for: mealRequest)) ?? 0
            )
        }

        // Check for mismatches
        let entryMismatch = abs(frcEntryCount - dbCounts.entries)
        let activityMismatch = abs(frcActivityCount - dbCounts.activities)
        let sleepMismatch = abs(frcSleepCount - dbCounts.sleep)
        let mealMismatch = abs(frcMealCount - dbCounts.meals)

        let totalFRC = frcEntryCount + frcActivityCount + frcSleepCount + frcMealCount
        let totalDB = dbCounts.entries + dbCounts.activities + dbCounts.sleep + dbCounts.meals
        let totalMismatch = entryMismatch + activityMismatch + sleepMismatch + mealMismatch

        // Trigger refresh if:
        // 1. FRC shows 0 but DB has data (completely stale)
        // 2. Mismatch is more than 10% of total items
        // 3. Mismatch is more than 5 items (for small datasets)
        let needsRefresh: Bool
        if totalFRC == 0 && totalDB > 0 {
            logger.warning("Data integrity: FRC empty but DB has \(totalDB) items - triggering refresh")
            needsRefresh = true
        } else if totalDB > 0 && Double(totalMismatch) / Double(totalDB) > 0.1 {
            logger.warning("Data integrity: \(totalMismatch) item mismatch (>\(10)%) - triggering refresh")
            needsRefresh = true
        } else if totalMismatch > 5 {
            logger.warning("Data integrity: \(totalMismatch) item mismatch - triggering refresh")
            needsRefresh = true
        } else {
            needsRefresh = false
        }

        if needsRefresh {
            logger.info("Data integrity check failed - FRC: \(totalFRC), DB: \(totalDB)")
            forceRefresh()
        } else {
            logger.debug("Data integrity check passed - FRC: \(totalFRC), DB: \(totalDB)")
        }
    }

    // MARK: - Data Grouping and Section Building

    private func rebuildDaySections() {
        // Group data by date
        groupedEntries = groupByDate(entriesFRC?.fetchedObjects ?? [])
        // Use effectiveDate for contributors to match LoadCalculator's grouping logic
        groupedActivities = groupContributorsByDate(activitiesFRC?.fetchedObjects ?? [])
        groupedSleepEvents = groupContributorsByDate(sleepEventsFRC?.fetchedObjects ?? [])
        groupedMealEvents = groupContributorsByDate(mealEventsFRC?.fetchedObjects ?? [])
        // Group reflection multipliers by date
        groupedReflections = LoadCalculator.shared.groupReflectionsByDate(reflectionsFRC?.fetchedObjects ?? [])

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
        // Combine all contributors (activities, meals, sleep) into a single dictionary
        let allDataDates = Set(groupedEntries.keys)
            .union(groupedActivities.keys)
            .union(groupedMealEvents.keys)
            .union(groupedSleepEvents.keys)
        let firstDate = allDataDates.min() ?? displayStartDate
        let lastDate = displayDates.max() ?? displayStartDate

        // Merge all contributors by date
        var contributorsByDate: [Date: [LoadContributor]] = [:]
        for date in allDataDates {
            var contributors: [LoadContributor] = []
            contributors.append(contentsOf: groupedActivities[date] ?? [])
            contributors.append(contentsOf: groupedMealEvents[date] ?? [])
            contributors.append(contentsOf: groupedSleepEvents[date] ?? [])
            contributorsByDate[date] = contributors
        }

        let loadScores = loadScoreCache.calculateRange(
            from: firstDate,
            to: lastDate,
            contributorsByDate: contributorsByDate,
            symptomsByDate: groupedEntries,
            reflectionsByDate: groupedReflections
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
                date = DateUtility.now()
            }
            return calendar.startOfDay(for: date)
        }
    }

    /// Group contributors by their effectiveDate (matches LoadCalculator's grouping logic)
    private func groupContributorsByDate<T: LoadContributor>(_ contributors: [T]) -> [Date: [T]] {
        Dictionary(grouping: contributors) { contributor in
            calendar.startOfDay(for: contributor.effectiveDate)
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

    /// Forces a complete refresh of all data from Core Data
    /// Use this after data restoration or when FRCs may have stale data
    func forceRefresh() {
        logger.info("Force refreshing timeline data")
        isLoading = true

        // Refresh the context to pick up any changes from other contexts
        context.refreshAllObjects()

        // Invalidate all caches
        loadScoreCache.invalidateAll()

        // Re-perform fetch on all FRCs
        do {
            try entriesFRC?.performFetch()
            try activitiesFRC?.performFetch()
            try sleepEventsFRC?.performFetch()
            try mealEventsFRC?.performFetch()
            try reflectionsFRC?.performFetch()

            rebuildDaySections()
        } catch {
            logger.error("Error during force refresh: \(error)")
        }

        isLoading = false
    }

    /// Updates date ranges (e.g., at midnight or when user changes settings)
    func updateDateRanges() {
        let today = calendar.startOfDay(for: DateUtility.now())
        let newDisplayStart = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        // Use consistent lookback period from LoadCalculator for all data types
        // Fetch from lookbackDays before the earliest displayed date to ensure full historical context
        let newDataStart = calendar.date(byAdding: .day, value: -LoadCalculator.lookbackDays, to: newDisplayStart) ?? newDisplayStart

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
        // Cancel notification observers
        cancellables.removeAll()

        // Clear FRC delegates to break retain cycles
        entriesFRC?.delegate = nil
        activitiesFRC?.delegate = nil
        sleepEventsFRC?.delegate = nil
        mealEventsFRC?.delegate = nil
        reflectionsFRC?.delegate = nil

        // Clear cached data
        groupedEntries.removeAll()
        groupedActivities.removeAll()
        groupedSleepEvents.removeAll()
        groupedMealEvents.removeAll()
        groupedReflections.removeAll()
        daySections.removeAll()

        // Prune old cache entries (keep lookback period + buffer)
        loadScoreCache.pruneOlderThan(days: LoadCalculator.lookbackDays)
    }
}
