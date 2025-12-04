// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// HealthKitSampleFactory.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Factory for creating HealthKit test samples.
//
import HealthKit
import Foundation

/// Factory for creating HealthKit samples for testing
/// Provides consistent, reusable sample generation across all HealthKit tests
enum HealthKitSampleFactory {

    // MARK: - Quantity Samples

    /// Create HRV (Heart Rate Variability) samples
    static func makeHRVSamples(
        values: [Double],
        startDate: Date = Date(),
        interval: TimeInterval = 24 * 3600
    ) -> [HKQuantitySample] {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        return values.enumerated().map { index, value in
            let date = startDate.addingTimeInterval(-Double(index) * interval)
            let quantity = HKQuantity(unit: HKUnit.secondUnit(with: .milli), doubleValue: value)
            return HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        }
    }

    /// Create a single HRV sample
    static func makeHRVSample(value: Double, date: Date = Date()) -> HKQuantitySample {
        makeHRVSamples(values: [value], startDate: date).first!
    }

    /// Create resting heart rate samples
    static func makeRestingHRSamples(
        values: [Double],
        startDate: Date = Date(),
        interval: TimeInterval = 24 * 3600
    ) -> [HKQuantitySample] {
        let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())

        return values.enumerated().map { index, value in
            let date = startDate.addingTimeInterval(-Double(index) * interval)
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            return HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        }
    }

    /// Create a single resting heart rate sample
    static func makeRestingHRSample(value: Double, date: Date = Date()) -> HKQuantitySample {
        makeRestingHRSamples(values: [value], startDate: date).first!
    }

    // MARK: - Category Samples

    /// Create sleep analysis samples
    static func makeSleepSamples(
        sessions: [(value: HKCategoryValueSleepAnalysis, start: Date, duration: TimeInterval)]
    ) -> [HKCategorySample] {
        let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

        return sessions.map { session in
            let end = session.start.addingTimeInterval(session.duration)
            return HKCategorySample(
                type: type,
                value: session.value.rawValue,
                start: session.start,
                end: end
            )
        }
    }

    /// Create menstrual flow samples
    static func makeMenstrualFlowSamples(
        entries: [(value: HKCategoryValueVaginalBleeding, date: Date)]
    ) -> [HKCategorySample] {
        let type = HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!

        return entries.map { entry in
            let end = entry.date.addingTimeInterval(60) // 1 minute duration
            return HKCategorySample(
                type: type,
                value: entry.value.rawValue,
                start: entry.date,
                end: end
            )
        }
    }

    // MARK: - Workout Samples

    /// Create workout samples
    static func makeWorkouts(
        workouts: [(activityType: HKWorkoutActivityType, start: Date, durationMinutes: Double)]
    ) -> [HKWorkout] {
        workouts.map { workout in
            let duration = workout.durationMinutes * 60
            let end = workout.start.addingTimeInterval(duration)
            return HKWorkout(
                activityType: workout.activityType,
                start: workout.start,
                end: end
            )
        }
    }

    /// Create a single workout
    static func makeWorkout(
        activityType: HKWorkoutActivityType = .running,
        start: Date,
        durationMinutes: Double
    ) -> HKWorkout {
        makeWorkouts(workouts: [(activityType, start, durationMinutes)]).first!
    }
}
