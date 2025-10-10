//
//  HealthKitExpectedValues.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import Foundation
import HealthKitTestData

/// Provides expected HealthKit values for UI test assertions
/// Uses the same deterministic seeds as UITestConfiguration for reproducible results
struct HealthKitExpectedValues {

    // MARK: - Fixture Presets

    /// Standard fixture with normal health profile (7 days, seed: 42)
    /// Matches UITestConfiguration normal preset
    static let standard = HealthKitExpectedValues(
        preset: .normal,
        daysOfHistory: 7,
        seed: 42
    )

    /// Higher stress fixture (7 days, seed: 100)
    /// Matches UITestConfiguration higherStress preset
    static let higherStress = HealthKitExpectedValues(
        preset: .higherStress,
        daysOfHistory: 7,
        seed: 100
    )

    /// Lower stress fixture (7 days, seed: 200)
    /// Matches UITestConfiguration lowerStress preset
    static let lowerStress = HealthKitExpectedValues(
        preset: .lowerStress,
        daysOfHistory: 7,
        seed: 200
    )

    // MARK: - Configuration

    let preset: GenerationPreset
    let daysOfHistory: Int
    let seed: Int

    private let endDate = Date()
    private var startDate: Date {
        endDate.addingTimeInterval(-TimeInterval(daysOfHistory * 24 * 3600))
    }

    // MARK: - Expected Values

    /// Get expected HRV value for a specific date offset from today
    /// - Parameter daysAgo: Number of days before today (0 = today, 1 = yesterday, etc.)
    /// - Returns: Expected HRV value in milliseconds, or nil if no data
    func expectedHRV(daysAgo: Int) -> Double? {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: endDate) ?? endDate
        let bundle = generateBundle()

        // Find the HRV sample closest to this date
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date

        let samplesForDay = bundle.hrv.filter { sample in
            sample.date >= dayStart && sample.date < dayEnd
        }

        // Return the first (or average) value for the day
        return samplesForDay.first?.value
    }

    /// Get expected resting heart rate for a specific date offset
    /// - Parameter daysAgo: Number of days before today (0 = today, 1 = yesterday, etc.)
    /// - Returns: Expected resting HR in BPM, or nil if no data
    func expectedRestingHR(daysAgo: Int) -> Double? {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: endDate) ?? endDate
        let bundle = generateBundle()

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date

        let samplesForDay = bundle.restingHeartRate.filter { sample in
            sample.date >= dayStart && sample.date < dayEnd
        }

        return samplesForDay.first?.value
    }

    /// Get expected sleep hours for a specific date offset
    /// - Parameter daysAgo: Number of days before today (0 = today, 1 = yesterday, etc.)
    /// - Returns: Expected sleep hours, or nil if no data
    func expectedSleepHours(daysAgo: Int) -> Double? {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: endDate) ?? endDate
        let bundle = generateBundle()

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date

        // Sum all sleep samples for this day
        let samplesForDay = bundle.sleep.filter { sample in
            sample.endDate >= dayStart && sample.endDate < dayEnd
        }

        let totalSeconds = samplesForDay.reduce(0.0) { total, sample in
            total + sample.endDate.timeIntervalSince(sample.startDate)
        }

        return totalSeconds > 0 ? totalSeconds / 3600.0 : nil
    }

    /// Get expected workout minutes for a specific date offset
    /// - Parameter daysAgo: Number of days before today (0 = today, 1 = yesterday, etc.)
    /// - Returns: Expected workout minutes, or nil if no data
    func expectedWorkoutMinutes(daysAgo: Int) -> Double? {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: endDate) ?? endDate
        let bundle = generateBundle()

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date

        let workoutsForDay = bundle.workouts.filter { workout in
            workout.startDate >= dayStart && workout.startDate < dayEnd
        }

        let totalMinutes = workoutsForDay.reduce(into: 0.0) { total, workout in
            total += workout.endDate.timeIntervalSince(workout.startDate) / 60.0
        }

        return totalMinutes > 0 ? totalMinutes : nil
    }

    // MARK: - Bundle Generation

    /// Generate the HealthKit test data bundle for this fixture
    /// This uses the same logic as the seeding to ensure values match
    private func generateBundle() -> ExportedHealthBundle {
        return SyntheticDataGenerator.generateHealthData(
            preset: preset,
            manipulation: .smoothReplace,
            startDate: startDate,
            endDate: endDate,
            seed: seed
        )
    }

    /// Get all expected values for a specific day as a dictionary
    /// Useful for comprehensive test assertions
    func expectedMetrics(daysAgo: Int) -> [String: Any] {
        var metrics: [String: Any] = [:]

        if let hrv = expectedHRV(daysAgo: daysAgo) {
            metrics["hrv"] = hrv
        }
        if let restingHR = expectedRestingHR(daysAgo: daysAgo) {
            metrics["restingHR"] = restingHR
        }
        if let sleep = expectedSleepHours(daysAgo: daysAgo) {
            metrics["sleepHours"] = sleep
        }
        if let workout = expectedWorkoutMinutes(daysAgo: daysAgo) {
            metrics["workoutMinutes"] = workout
        }

        return metrics
    }

    /// Get average HRV across the entire fixture period
    /// Useful for verifying displayed values are in expected range
    func averageHRV() -> Double? {
        let bundle = generateBundle()
        guard !bundle.hrv.isEmpty else { return nil }

        let total = bundle.hrv.reduce(0.0) { $0 + $1.value }
        return total / Double(bundle.hrv.count)
    }

    /// Get average resting HR across the entire fixture period
    func averageRestingHR() -> Double? {
        let bundle = generateBundle()
        guard !bundle.restingHeartRate.isEmpty else { return nil }

        let total = bundle.restingHeartRate.reduce(0.0) { $0 + $1.value }
        return total / Double(bundle.restingHeartRate.count)
    }
}
