//
//  HealthKitHistoricalService.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import Foundation
import HealthKit
import os.log

// MARK: - Protocols

/// Service responsible for querying historical health data for specific dates
protocol HealthKitHistoricalServiceProtocol: Sendable {
    /// Get HRV for a specific date (cached per calendar day)
    func hrvForDate(_ date: Date) async -> Double?

    /// Get resting heart rate for a specific date (cached per calendar day)
    func restingHRForDate(_ date: Date) async -> Double?

    /// Get sleep hours for a specific date (cached per calendar day)
    func sleepHoursForDate(_ date: Date) async -> Double?

    /// Get workout minutes for a specific date (cached per calendar day)
    func workoutMinutesForDate(_ date: Date) async -> Double?

    /// Get cycle day for a specific date (cached per calendar day)
    func cycleDayForDate(_ date: Date) async -> Int?

    /// Get menstrual flow level for a specific date (cached per calendar day)
    func flowLevelForDate(_ date: Date) async -> String?
}

// MARK: - Implementation

/// Handles historical health data queries for specific dates
/// Uses caching to avoid redundant HealthKit queries for same-day lookups
final class HealthKitHistoricalService: HealthKitHistoricalServiceProtocol, @unchecked Sendable {
    private let logger = Logger(subsystem: "app.murmur", category: "HealthKitHistorical")

    private let queryService: HealthKitQueryServiceProtocol
    private let cacheService: HealthKitCacheServiceProtocol

    private lazy var hrvType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
    private lazy var restingHeartType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
    private lazy var sleepType: HKCategoryType? = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
    private lazy var menstrualFlowType: HKCategoryType? = HKCategoryType.categoryType(forIdentifier: .menstrualFlow)

    init(queryService: HealthKitQueryServiceProtocol, cacheService: HealthKitCacheServiceProtocol) {
        self.queryService = queryService
        self.cacheService = cacheService
    }

    // MARK: - Historical Data Methods

    func hrvForDate(_ date: Date) async -> Double? {
        if let cached: Double = cacheService.getCachedValue(for: .hrv, date: date) {
            return cached
        }

        guard let hrvType else {
            logger.warning("HRV type not available on this device")
            return nil
        }

        do {
            let (start, end) = dayBounds(for: date)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let samples = try await queryService.fetchQuantitySamples(
                for: hrvType,
                start: start,
                end: end,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            )

            if let sample = samples.first {
                let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                cacheService.setCachedValue(value, for: .hrv, date: date)
                return value
            }
        } catch {
            logger.error("Failed to fetch HRV for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    func restingHRForDate(_ date: Date) async -> Double? {
        if let cached: Double = cacheService.getCachedValue(for: .restingHR, date: date) {
            return cached
        }

        guard let restingHeartType else {
            logger.warning("Resting heart rate type not available on this device")
            return nil
        }

        do {
            let (start, end) = dayBounds(for: date)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let samples = try await queryService.fetchQuantitySamples(
                for: restingHeartType,
                start: start,
                end: end,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            )

            if let sample = samples.first {
                let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let value = sample.quantity.doubleValue(for: unit)
                cacheService.setCachedValue(value, for: .restingHR, date: date)
                return value
            }
        } catch {
            logger.error("Failed to fetch resting HR for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    func sleepHoursForDate(_ date: Date) async -> Double? {
        if let cached: Double = cacheService.getCachedValue(for: .sleep, date: date) {
            return cached
        }

        guard sleepType != nil else {
            logger.warning("Sleep type not available on this device")
            return nil
        }

        do {
            let calendar = Calendar.current
            let (dayStart, dayEnd) = DateUtility.dayBounds(for: date, calendar: calendar)

            // Extend backwards to catch sleep that started the night before
            let searchStart = calendar.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart

            let samples = try await queryService.fetchSleepSamples(
                start: searchStart,
                end: dayEnd
            )

            // Sum all sleep samples for this day
            let totalSeconds = samples.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }

            let hours = totalSeconds / 3600.0
            if hours > 0 {
                cacheService.setCachedValue(hours, for: .sleep, date: date)
                return hours
            }
        } catch {
            logger.error("Failed to fetch sleep for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    func workoutMinutesForDate(_ date: Date) async -> Double? {
        if let cached: Double = cacheService.getCachedValue(for: .workout, date: date) {
            return cached
        }

        do {
            let (start, end) = dayBounds(for: date)

            let samples = try await queryService.fetchWorkouts(
                start: start,
                end: end,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            )

            let totalSeconds = samples.reduce(0.0) { total, workout in
                total + workout.duration
            }

            let minutes = totalSeconds / 60.0
            if minutes > 0 {
                cacheService.setCachedValue(minutes, for: .workout, date: date)
                return minutes
            }
        } catch {
            logger.error("Failed to fetch workouts for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    func cycleDayForDate(_ date: Date) async -> Int? {
        if let cached: Int = cacheService.getCachedValue(for: .cycleDay, date: date) {
            return cached
        }

        guard let menstrualFlowType else {
            logger.warning("Menstrual flow type not available on this device")
            return nil
        }

        do {
            // Look back 45 days to find the most recent period start before this date
            let calendar = Calendar.current
            let searchEnd = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let searchStart = calendar.date(byAdding: .day, value: -45, to: date) ?? date

            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let samples = try await queryService.fetchCategorySamples(
                for: menstrualFlowType,
                start: searchStart,
                end: searchEnd,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            )

            // Find most recent period start before or on this date
            let periodStarts = samples.filter { sample in
                let value = HKCategoryValueVaginalBleeding(rawValue: sample.value)
                return value != .unspecified && value != Optional<HKCategoryValueVaginalBleeding>.none &&
                       sample.startDate <= searchEnd
            }

            if let mostRecentPeriodStart = periodStarts.first {
                let daysSinceStart = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: mostRecentPeriodStart.startDate),
                    to: calendar.startOfDay(for: date)
                ).day ?? 0
                let cycleDay = daysSinceStart + 1
                cacheService.setCachedValue(cycleDay, for: .cycleDay, date: date)
                return cycleDay
            }
        } catch {
            logger.error("Failed to fetch cycle day for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    func flowLevelForDate(_ date: Date) async -> String? {
        if let cached: String = cacheService.getCachedValue(for: .flowLevel, date: date) {
            return cached
        }

        guard let menstrualFlowType else {
            logger.warning("Menstrual flow type not available on this device")
            return nil
        }

        do {
            let (start, end) = dayBounds(for: date)

            let samples = try await queryService.fetchCategorySamples(
                for: menstrualFlowType,
                start: start,
                end: end,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            )

            if let sample = samples.first {
                let flowValue = HKCategoryValueVaginalBleeding(rawValue: sample.value)
                let flowLevel: String?
                switch flowValue {
                case .light: flowLevel = "light"
                case .medium: flowLevel = "medium"
                case .heavy: flowLevel = "heavy"
                case .unspecified: flowLevel = "spotting"
                default: flowLevel = nil
                }

                if let flowLevel {
                    cacheService.setCachedValue(flowLevel, for: .flowLevel, date: date)
                    return flowLevel
                }
            }
        } catch {
            logger.error("Failed to fetch flow level for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Helper Methods

    private func dayBounds(for date: Date) -> (start: Date, end: Date) {
        DateUtility.dayBounds(for: date, calendar: .current)
    }
}
