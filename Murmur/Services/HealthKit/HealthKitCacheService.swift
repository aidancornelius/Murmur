//
//  HealthKitCacheService.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import Foundation

// MARK: - Protocols

/// Service responsible for caching HealthKit data to reduce redundant queries
/// Note: Sendable conformance removed - actors are implicitly Sendable
/// Actor isolation: This protocol should only be adopted by actors
protocol HealthKitCacheServiceProtocol: Actor {
    // MARK: - Recent Data Cache (Timestamp-based)
    func getLastSampleDate(for metric: HealthMetric) -> Date?
    func setLastSampleDate(_ date: Date, for metric: HealthMetric)
    func shouldRefresh(metric: HealthMetric, cacheDuration: TimeInterval, force: Bool) -> Bool

    // MARK: - Historical Data Cache (Day-based)
    func getCachedValue<T>(for metric: HealthMetric, date: Date) -> T?
    func setCachedValue<T>(_ value: T, for metric: HealthMetric, date: Date)
    func clearCache()
}

/// Metric types that can be cached
enum HealthMetric {
    case hrv
    case restingHR
    case sleep
    case workout
    case cycleDay
    case flowLevel
}

// MARK: - Implementation

/// Manages caching of HealthKit data with timestamp and day-based strategies
/// Actor provides thread-safe access to all cache state
actor HealthKitCacheService: HealthKitCacheServiceProtocol {
    // MARK: - Recent Data Cache
    // Stores the timestamp of the last sample fetched for each metric
    private var lastHRVSampleDate: Date?
    private var lastRestingSampleDate: Date?
    private var lastSleepSampleDate: Date?
    private var lastWorkoutSampleDate: Date?
    private var lastCycleSampleDate: Date?

    // MARK: - Historical Data Cache
    // Key format: "YYYY-MM-DD"
    private var historicalHRVCache: [String: Double] = [:]
    private var historicalRestingHRCache: [String: Double] = [:]
    private var historicalSleepCache: [String: Double] = [:]
    private var historicalWorkoutCache: [String: Double] = [:]
    private var historicalCycleDayCache: [String: Int] = [:]
    private var historicalFlowLevelCache: [String: String] = [:]

    // MARK: - Recent Data Cache Methods

    func getLastSampleDate(for metric: HealthMetric) -> Date? {
        switch metric {
        case .hrv: return lastHRVSampleDate
        case .restingHR: return lastRestingSampleDate
        case .sleep: return lastSleepSampleDate
        case .workout: return lastWorkoutSampleDate
        case .cycleDay, .flowLevel: return lastCycleSampleDate
        }
    }

    func setLastSampleDate(_ date: Date, for metric: HealthMetric) {
        switch metric {
        case .hrv: lastHRVSampleDate = date
        case .restingHR: lastRestingSampleDate = date
        case .sleep: lastSleepSampleDate = date
        case .workout: lastWorkoutSampleDate = date
        case .cycleDay, .flowLevel: lastCycleSampleDate = date
        }
    }

    func shouldRefresh(metric: HealthMetric, cacheDuration: TimeInterval, force: Bool) -> Bool {
        if force { return true }
        guard let lastDate = getLastSampleDate(for: metric) else { return true }
        return DateUtility.now().timeIntervalSince(lastDate) >= cacheDuration
    }

    // MARK: - Historical Data Cache Methods

    func getCachedValue<T>(for metric: HealthMetric, date: Date) -> T? {
        let key = dayKey(for: date)

        switch metric {
        case .hrv: return historicalHRVCache[key] as? T
        case .restingHR: return historicalRestingHRCache[key] as? T
        case .sleep: return historicalSleepCache[key] as? T
        case .workout: return historicalWorkoutCache[key] as? T
        case .cycleDay: return historicalCycleDayCache[key] as? T
        case .flowLevel: return historicalFlowLevelCache[key] as? T
        }
    }

    func setCachedValue<T>(_ value: T, for metric: HealthMetric, date: Date) {
        let key = dayKey(for: date)

        switch metric {
        case .hrv:
            if let doubleValue = value as? Double {
                historicalHRVCache[key] = doubleValue
            }
        case .restingHR:
            if let doubleValue = value as? Double {
                historicalRestingHRCache[key] = doubleValue
            }
        case .sleep:
            if let doubleValue = value as? Double {
                historicalSleepCache[key] = doubleValue
            }
        case .workout:
            if let doubleValue = value as? Double {
                historicalWorkoutCache[key] = doubleValue
            }
        case .cycleDay:
            if let intValue = value as? Int {
                historicalCycleDayCache[key] = intValue
            }
        case .flowLevel:
            if let stringValue = value as? String {
                historicalFlowLevelCache[key] = stringValue
            }
        }
    }

    func clearCache() {
        // Clear recent cache
        lastHRVSampleDate = nil
        lastRestingSampleDate = nil
        lastSleepSampleDate = nil
        lastWorkoutSampleDate = nil
        lastCycleSampleDate = nil

        // Clear historical cache
        historicalHRVCache.removeAll()
        historicalRestingHRCache.removeAll()
        historicalSleepCache.removeAll()
        historicalWorkoutCache.removeAll()
        historicalCycleDayCache.removeAll()
        historicalFlowLevelCache.removeAll()
    }

    // MARK: - Helper Methods

    /// Generate a cache key for a specific day (format: "YYYY-MM-DD")
    private func dayKey(for date: Date) -> String {
        DateUtility.dayKey(for: date, timeZone: .current)
    }

    // MARK: - Debug Helpers (for testing)

    #if DEBUG
    /// Expose cache timestamps for testing purposes
    func _setCacheTimestamp(_ date: Date, for metric: HealthMetric) {
        setLastSampleDate(date, for: metric)
    }
    #endif
}
