// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// HealthKitSeedAdapter.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Adapter for seeding HealthKit data in tests.
//
import Foundation
import HealthKit
import os.log

// MARK: - Health Metrics Container

/// Helper struct to hold health metrics queried from HealthKit
struct HealthMetrics {
    let hrv: Double
    let restingHR: Double
    let sleepHours: Double?
    let workoutMinutes: Double?
    let cycleDay: Int?
    let flowLevel: String?
}

// MARK: - Adapter

/// Adapter for fetching HealthKit metrics during data seeding
/// Bridges HealthKit queries with the SeededDataGenerator fallback system
struct HealthKitSeedAdapter {
    private static let logger = Logger(subsystem: "app.murmur", category: "HealthKitSeed")

    /// Fetch health metrics from HealthKit for a specific date
    /// - Parameters:
    ///   - date: The date to query metrics for
    ///   - dayType: The type of day (for fallback generation)
    ///   - seed: Deterministic seed for fallback values
    ///   - dataProvider: Optional HealthKitDataProvider for dependency injection (defaults to RealHealthKitDataProvider)
    /// - Returns: HealthMetrics containing queried or fallback values
    static func fetchHealthKitMetrics(for date: Date, dayType: DayType, seed: Int, dataProvider: HealthKitDataProvider? = nil) async -> HealthMetrics {
        // Use provided dataProvider or create a new one
        let provider: HealthKitDataProvider
        if let dataProvider = dataProvider {
            provider = dataProvider
        } else {
            guard HKHealthStore.isHealthDataAvailable() else {
                return HealthMetrics(
                    hrv: SeededDataGenerator.getFallbackHRV(for: dayType, seed: seed),
                    restingHR: SeededDataGenerator.getFallbackRestingHR(for: dayType, seed: seed),
                    sleepHours: nil,
                    workoutMinutes: nil,
                    cycleDay: nil,
                    flowLevel: nil
                )
            }

            let newProvider = RealHealthKitDataProvider()
            let readTypes: Set<HKObjectType> = Set([
                HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
                HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
                HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
                HKObjectType.workoutType(),
                HKCategoryType.categoryType(forIdentifier: .menstrualFlow)
            ].compactMap { $0 })

            do {
                try await newProvider.requestAuthorization(toShare: [], read: readTypes)
                provider = newProvider
            } catch {
                logger.warning("HealthKit authorisation failed: \(error.localizedDescription)")
                return HealthMetrics(
                    hrv: SeededDataGenerator.getFallbackHRV(for: dayType, seed: seed),
                    restingHR: SeededDataGenerator.getFallbackRestingHR(for: dayType, seed: seed),
                    sleepHours: nil,
                    workoutMinutes: nil,
                    cycleDay: nil,
                    flowLevel: nil
                )
            }
        }

        // Shared date range for all queries
        let calendar = Calendar.current
        let (startOfDay, endOfDay) = DateUtility.dayBounds(for: date, calendar: calendar)

        // Query HRV
        let hrv: Double? = try? await {
            guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return nil }
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let statistics = try await provider.fetchStatistics(quantityType: hrvType, predicate: predicate, options: .discreteAverage)
            return statistics?.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli))
        }()

        // Query resting heart rate
        let restingHR: Double? = try? await {
            guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let statistics = try await provider.fetchStatistics(quantityType: restingHRType, predicate: predicate, options: .discreteAverage)
            return statistics?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }()

        // Query sleep hours
        let sleepHours: Double? = try? await {
            guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let categorySamples = try await provider.fetchCategorySamples(type: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil)

            // Filter for asleep states
            let asleepSamples = categorySamples.filter { sample in
                if #available(iOS 16.0, *) {
                    return [
                        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    ].contains(sample.value)
                } else {
                    return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                }
            }

            // Sum total sleep duration in hours
            let totalSeconds = asleepSamples.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }

            let hours = totalSeconds / 3600.0
            return hours > 0 ? hours : nil
        }()

        // Query workout minutes
        let workoutMinutes: Double? = try? await {
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let workouts = try await provider.fetchWorkouts(predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil)

            // Sum total workout duration in minutes
            let totalSeconds = workouts.reduce(0.0) { total, workout in
                total + workout.duration
            }

            let minutes = totalSeconds / 60.0
            return minutes > 0 ? minutes : nil
        }()

        // Query cycle day (days since last period start)
        let cycleDay: Int? = try? await {
            guard let flowType = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) else { return nil }

            // Look back up to 60 days for last period start
            let lookbackDate = calendar.date(byAdding: .day, value: -60, to: date) ?? date
            let predicate = HKQuery.predicateForSamples(withStart: lookbackDate, end: date, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let flowSamples = try await provider.fetchCategorySamples(type: flowType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor])

            // Find most recent period start (flow > none)
            let periodStarts = flowSamples.filter { sample in
                if #available(iOS 18.0, *) {
                    return sample.value > HKCategoryValueVaginalBleeding.none.rawValue
                } else {
                    return sample.value > HKCategoryValueMenstrualFlow.none.rawValue
                }
            }

            guard let lastPeriodStart = periodStarts.first else {
                return nil
            }

            // Calculate days since period start
            return calendar.dateComponents([.day], from: lastPeriodStart.startDate, to: date).day
        }()

        // Query flow level for the day
        let flowLevel: String? = try? await {
            guard let flowType = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) else { return nil }
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            let flowSamples = try await provider.fetchCategorySamples(type: flowType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil)

            guard !flowSamples.isEmpty else {
                return nil
            }

            // Find highest flow value for the day
            let maxFlow: Int
            let flowString: String

            if #available(iOS 18.0, *) {
                maxFlow = flowSamples.map(\.value).max() ?? HKCategoryValueVaginalBleeding.none.rawValue
                switch maxFlow {
                case HKCategoryValueVaginalBleeding.none.rawValue:
                    flowString = "none"
                case HKCategoryValueVaginalBleeding.light.rawValue:
                    flowString = "light"
                case HKCategoryValueVaginalBleeding.medium.rawValue:
                    flowString = "medium"
                case HKCategoryValueVaginalBleeding.heavy.rawValue:
                    flowString = "heavy"
                default:
                    flowString = "unspecified"
                }
            } else {
                maxFlow = flowSamples.map(\.value).max() ?? HKCategoryValueMenstrualFlow.none.rawValue
                switch maxFlow {
                case HKCategoryValueMenstrualFlow.none.rawValue:
                    flowString = "none"
                case HKCategoryValueMenstrualFlow.light.rawValue:
                    flowString = "light"
                case HKCategoryValueMenstrualFlow.medium.rawValue:
                    flowString = "medium"
                case HKCategoryValueMenstrualFlow.heavy.rawValue:
                    flowString = "heavy"
                default:
                    flowString = "unspecified"
                }
            }

            return flowString
        }()

        // Return metrics with fallbacks for nil values
        return HealthMetrics(
            hrv: hrv ?? SeededDataGenerator.getFallbackHRV(for: dayType, seed: seed),
            restingHR: restingHR ?? SeededDataGenerator.getFallbackRestingHR(for: dayType, seed: seed),
            sleepHours: sleepHours,
            workoutMinutes: workoutMinutes,
            cycleDay: cycleDay,
            flowLevel: flowLevel
        )
    }
}
