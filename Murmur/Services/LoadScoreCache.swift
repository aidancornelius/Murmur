//
//  LoadScoreCache.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell
//

import Foundation
import CoreData

/// Cache for LoadScore calculations with intelligent invalidation
/// Stores load scores by date and tracks data dependencies for efficient updates
@MainActor
final class LoadScoreCache {

    // MARK: - Types

    /// Represents a cached load score with its dependencies
    private struct CachedEntry {
        let loadScore: LoadScore
        let dataHash: DataHash
        let timestamp: Date

        /// Hash representing the input data for this calculation
        struct DataHash: Hashable {
            let contributorsHash: Int
            let symptomsHash: Int
            let previousLoad: Double
            let configHash: Int

            init(contributors: [LoadContributor], symptoms: [SymptomEntry],
                 previousLoad: Double, config: LoadConfiguration) {
                // Hash based on object IDs for Core Data objects
                self.contributorsHash = contributors.compactMap { contributor in
                    // Cast to NSManagedObject to get objectID
                    (contributor as? NSManagedObject)?.objectID.hashValue
                }.reduce(0, ^)

                self.symptomsHash = symptoms.map {
                    $0.objectID.hashValue
                }.reduce(0, ^)

                self.previousLoad = previousLoad

                // Hash configuration
                self.configHash = config.hashValue
            }
        }
    }

    // MARK: - Properties

    private var cache: [Date: CachedEntry] = [:]
    private let calendar = Calendar.current

    /// Statistics for monitoring cache performance
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0

    // MARK: - Initialisation

    init() {}

    // MARK: - Public API

    /// Retrieves a cached load score if valid, otherwise returns nil
    func get(for date: Date, contributors: [LoadContributor], symptoms: [SymptomEntry],
             previousLoad: Double, config: LoadConfiguration) -> LoadScore? {
        let dayStart = calendar.startOfDay(for: date)

        guard let entry = cache[dayStart] else {
            misses += 1
            return nil
        }

        let currentHash = CachedEntry.DataHash(
            contributors: contributors,
            symptoms: symptoms,
            previousLoad: previousLoad,
            config: config
        )

        if entry.dataHash == currentHash {
            hits += 1
            return entry.loadScore
        } else {
            misses += 1
            return nil
        }
    }

    /// Stores a load score in the cache with its dependencies
    func set(_ loadScore: LoadScore, for date: Date, contributors: [LoadContributor],
             symptoms: [SymptomEntry], previousLoad: Double, config: LoadConfiguration) {
        let dayStart = calendar.startOfDay(for: date)
        let dataHash = CachedEntry.DataHash(
            contributors: contributors,
            symptoms: symptoms,
            previousLoad: previousLoad,
            config: config
        )
        let entry = CachedEntry(loadScore: loadScore, dataHash: dataHash, timestamp: DateUtility.now())
        cache[dayStart] = entry
    }

    /// Calculates load scores for a date range, using cache when possible
    /// Only recalculates from the first changed date forward to maintain decay chain
    func calculateRange(from startDate: Date, to endDate: Date,
                       contributorsByDate: [Date: [LoadContributor]],
                       symptomsByDate: [Date: [SymptomEntry]],
                       config: LoadConfiguration? = nil) -> [LoadScore] {
        var scores: [LoadScore] = []
        var previousLoad: Double = 0.0
        var currentDate = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while currentDate <= endDay {
            let contributors = contributorsByDate[currentDate] ?? []
            let symptoms = symptomsByDate[currentDate] ?? []

            // Get configuration
            let activeConfig = config ?? LoadCapacityManager.shared.configuration

            // Try to get from cache
            if let cachedScore = get(for: currentDate, contributors: contributors,
                                    symptoms: symptoms, previousLoad: previousLoad,
                                    config: activeConfig) {
                scores.append(cachedScore)
                previousLoad = cachedScore.decayedLoad
            } else {
                // Cache miss - calculate and store using new LoadCalculator
                let score = LoadCalculator.shared.calculate(
                    for: currentDate,
                    contributors: contributors,
                    symptoms: symptoms,
                    previousLoad: previousLoad,
                    configuration: config
                )

                set(score, for: currentDate, contributors: contributors,
                    symptoms: symptoms, previousLoad: previousLoad, config: activeConfig)

                scores.append(score)
                previousLoad = score.decayedLoad
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return scores
    }

    /// Invalidates cache entries for a specific date and all subsequent dates
    /// Use this when data changes for a specific day (decay chain must be recalculated forward)
    func invalidateFrom(date: Date) {
        let dayStart = calendar.startOfDay(for: date)
        let keysToRemove = cache.keys.filter { $0 >= dayStart }
        keysToRemove.forEach { cache.removeValue(forKey: $0) }
    }

    /// Invalidates cache entries for a specific date only
    /// Use this when you know only a single day changed and decay chain doesn't need update
    func invalidate(date: Date) {
        let dayStart = calendar.startOfDay(for: date)
        cache.removeValue(forKey: dayStart)
    }

    /// Invalidates all cache entries (e.g., when configuration changes)
    func invalidateAll() {
        cache.removeAll()
    }

    /// Removes cache entries older than the specified number of days
    /// Helps manage memory for long-running apps
    func pruneOlderThan(days: Int) {
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: DateUtility.now()) ?? DateUtility.now()
        let keysToRemove = cache.keys.filter { $0 < cutoffDate }
        keysToRemove.forEach { cache.removeValue(forKey: $0) }
    }

    /// Returns cache statistics for debugging and monitoring
    func statistics() -> (entries: Int, hits: Int, misses: Int, hitRate: Double) {
        let total = hits + misses
        let hitRate = total > 0 ? Double(hits) / Double(total) : 0.0
        return (cache.count, hits, misses, hitRate)
    }

    /// Clears statistics (useful for testing and benchmarking)
    func resetStatistics() {
        hits = 0
        misses = 0
    }
}
