// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// LoadScoreCache.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// In-memory cache for computed load scores.
//
import Foundation
import CoreData

/// Cache for LoadScore calculations with intelligent invalidation
/// Stores load scores by date and tracks data dependencies for efficient updates
/// Uses LRU (Least Recently Used) eviction when cache exceeds maximum size
@MainActor
final class LoadScoreCache {

    // MARK: - Constants

    /// Maximum number of entries the cache can hold before LRU eviction occurs
    private static let maxCacheSize = 500

    // MARK: - Types

    /// Represents a cached load score with its dependencies
    private struct CachedEntry {
        let loadScore: LoadScore
        let dataHash: DataHash
        let timestamp: Date
        /// Tracks when this entry was last accessed for LRU eviction
        var lastAccessTime: Date

        /// Hash representing the input data for this calculation
        struct DataHash: Hashable {
            let contributorsHash: Int
            let symptomsHash: Int
            let previousLoad: Double
            let configHash: Int
            let reflectionMultiplier: Double?

            init(contributors: [LoadContributor], symptoms: [SymptomEntry],
                 previousLoad: Double, config: LoadConfiguration,
                 reflectionMultiplier: Double? = nil) {
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

                // Include reflection multiplier
                self.reflectionMultiplier = reflectionMultiplier
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
             previousLoad: Double, config: LoadConfiguration,
             reflectionMultiplier: Double? = nil) -> LoadScore? {
        let dayStart = calendar.startOfDay(for: date)

        guard var entry = cache[dayStart] else {
            misses += 1
            return nil
        }

        let currentHash = CachedEntry.DataHash(
            contributors: contributors,
            symptoms: symptoms,
            previousLoad: previousLoad,
            config: config,
            reflectionMultiplier: reflectionMultiplier
        )

        if entry.dataHash == currentHash {
            hits += 1
            // Update last access time for LRU tracking
            entry.lastAccessTime = DateUtility.now()
            cache[dayStart] = entry
            return entry.loadScore
        } else {
            misses += 1
            return nil
        }
    }

    /// Stores a load score in the cache with its dependencies
    func set(_ loadScore: LoadScore, for date: Date, contributors: [LoadContributor],
             symptoms: [SymptomEntry], previousLoad: Double, config: LoadConfiguration,
             reflectionMultiplier: Double? = nil) {
        let dayStart = calendar.startOfDay(for: date)
        let dataHash = CachedEntry.DataHash(
            contributors: contributors,
            symptoms: symptoms,
            previousLoad: previousLoad,
            config: config,
            reflectionMultiplier: reflectionMultiplier
        )
        let now = DateUtility.now()
        let entry = CachedEntry(
            loadScore: loadScore,
            dataHash: dataHash,
            timestamp: now,
            lastAccessTime: now
        )
        cache[dayStart] = entry

        // Evict least recently used entries if cache exceeds maximum size
        evictIfNeeded()
    }

    /// Calculates load scores for a date range, using cache when possible
    /// Only recalculates from the first changed date forward to maintain decay chain
    func calculateRange(from startDate: Date, to endDate: Date,
                       contributorsByDate: [Date: [LoadContributor]],
                       symptomsByDate: [Date: [SymptomEntry]],
                       reflectionsByDate: [Date: Double] = [:],
                       config: LoadConfiguration? = nil) -> [LoadScore] {
        var scores: [LoadScore] = []
        var previousEffectiveLoad: Double = 0.0
        var currentDate = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        while currentDate <= endDay {
            let contributors = contributorsByDate[currentDate] ?? []
            let symptoms = symptomsByDate[currentDate] ?? []
            let reflectionMultiplier = reflectionsByDate[currentDate]

            // Get configuration
            let activeConfig = config ?? LoadCapacityManager.shared.configuration

            // Try to get from cache
            if let cachedScore = get(for: currentDate, contributors: contributors,
                                    symptoms: symptoms, previousLoad: previousEffectiveLoad,
                                    config: activeConfig, reflectionMultiplier: reflectionMultiplier) {
                scores.append(cachedScore)
                // Use effective load (felt load if available) for the decay chain
                previousEffectiveLoad = cachedScore.effectiveLoad
            } else {
                // Cache miss - calculate and store using LoadCalculator
                let score = LoadCalculator.shared.calculate(
                    for: currentDate,
                    contributors: contributors,
                    symptoms: symptoms,
                    previousLoad: previousEffectiveLoad,
                    reflectionMultiplier: reflectionMultiplier,
                    configuration: config
                )

                set(score, for: currentDate, contributors: contributors,
                    symptoms: symptoms, previousLoad: previousEffectiveLoad,
                    config: activeConfig, reflectionMultiplier: reflectionMultiplier)

                scores.append(score)
                // Use effective load (felt load if available) for the decay chain
                previousEffectiveLoad = score.effectiveLoad
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

    // MARK: - Private Methods

    /// Evicts least recently used entries when cache exceeds maximum size
    private func evictIfNeeded() {
        guard cache.count > Self.maxCacheSize else { return }

        // Sort entries by last access time (oldest first)
        let sortedKeys = cache.keys.sorted { key1, key2 in
            let entry1 = cache[key1]!
            let entry2 = cache[key2]!
            return entry1.lastAccessTime < entry2.lastAccessTime
        }

        // Remove oldest entries until we're at 90% capacity to avoid frequent evictions
        let targetSize = Int(Double(Self.maxCacheSize) * 0.9)
        let entriesToRemove = cache.count - targetSize

        for i in 0..<entriesToRemove {
            cache.removeValue(forKey: sortedKeys[i])
        }
    }
}
