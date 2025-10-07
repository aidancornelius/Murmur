//
//  HealthKitTestHelpers.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import HealthKit
import XCTest
@testable import Murmur

// MARK: - Mock HealthKit Data Provider

/// Mock implementation of HealthKitDataProvider for testing
/// This properly implements the data provider protocol without trying to access HKQuery internals
@MainActor
final class MockHealthKitDataProvider: HealthKitDataProvider {

    // MARK: - Mock Configuration

    var mockQuantitySamples: [HKQuantitySample] = []
    var mockCategorySamples: [HKCategorySample] = []
    var mockWorkouts: [HKWorkout] = []
    var shouldThrowError: Error?
    var authorizationError: Error?

    // MARK: - Tracking

    private(set) var fetchQuantityCount = 0
    private(set) var fetchCategoryCount = 0
    private(set) var fetchWorkoutsCount = 0
    private(set) var requestAuthorizationCalled = false
    private(set) var requestedReadTypes: Set<HKObjectType>?
    private(set) var requestedShareTypes: Set<HKSampleType>?

    // MARK: - HealthKitDataProvider Implementation

    func fetchQuantitySamples(
        type: HKQuantityType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKQuantitySample] {
        fetchQuantityCount += 1

        if let error = shouldThrowError {
            throw error
        }

        var filtered = filterSamples(mockQuantitySamples, with: predicate)
        filtered = sortSamples(filtered, using: sortDescriptors)

        if limit != HKObjectQueryNoLimit && limit > 0 {
            filtered = Array(filtered.prefix(limit))
        }

        return filtered
    }

    func fetchCategorySamples(
        type: HKCategoryType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKCategorySample] {
        fetchCategoryCount += 1

        if let error = shouldThrowError {
            throw error
        }

        var filtered = filterSamples(mockCategorySamples, with: predicate)
        filtered = sortSamples(filtered, using: sortDescriptors)

        if limit != HKObjectQueryNoLimit && limit > 0 {
            filtered = Array(filtered.prefix(limit))
        }

        return filtered
    }

    func fetchWorkouts(
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKWorkout] {
        fetchWorkoutsCount += 1

        if let error = shouldThrowError {
            throw error
        }

        var filtered = filterSamples(mockWorkouts, with: predicate)
        filtered = sortSamples(filtered, using: sortDescriptors)

        if limit != HKObjectQueryNoLimit && limit > 0 {
            filtered = Array(filtered.prefix(limit))
        }

        return filtered
    }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {
        requestAuthorizationCalled = true
        requestedShareTypes = typesToShare
        requestedReadTypes = typesToRead

        if let error = authorizationError {
            throw error
        }
    }

    // MARK: - Helper Methods

    private func filterSamples<T: HKSample>(_ samples: [T], with predicate: NSPredicate?) -> [T] {
        guard let predicate = predicate else { return samples }
        return samples.filter { predicate.evaluate(with: $0) }
    }

    private func sortSamples<T: HKSample>(_ samples: [T], using sortDescriptors: [NSSortDescriptor]?) -> [T] {
        guard let sortDescriptors = sortDescriptors, !sortDescriptors.isEmpty else { return samples }
        return (samples as NSArray).sortedArray(using: sortDescriptors) as! [T]
    }

    // MARK: - Reset

    func reset() {
        mockQuantitySamples.removeAll()
        mockCategorySamples.removeAll()
        mockWorkouts.removeAll()
        shouldThrowError = nil
        authorizationError = nil
        fetchQuantityCount = 0
        fetchCategoryCount = 0
        fetchWorkoutsCount = 0
        requestAuthorizationCalled = false
        requestedReadTypes = nil
        requestedShareTypes = nil
    }

    /// Property for backwards compatibility with existing tests
    var executeCount: Int {
        fetchQuantityCount + fetchCategoryCount + fetchWorkoutsCount
    }
}

// MARK: - Mock Sample Creation Helpers

extension HKQuantitySample {
    /// Create a mock HRV sample
    static func mockHRV(value: Double, date: Date = Date()) -> HKQuantitySample {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let quantity = HKQuantity(unit: HKUnit.secondUnit(with: .milli), doubleValue: value)
        return HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
    }

    /// Create a mock resting heart rate sample
    static func mockRestingHR(value: Double, date: Date = Date()) -> HKQuantitySample {
        let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        return HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
    }
}

extension HKCategorySample {
    /// Create a mock sleep sample
    static func mockSleep(
        value: HKCategoryValueSleepAnalysis,
        start: Date,
        duration: TimeInterval
    ) -> HKCategorySample {
        let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let end = start.addingTimeInterval(duration)
        return HKCategorySample(type: type, value: value.rawValue, start: start, end: end)
    }

    /// Create a mock menstrual flow sample
    static func mockMenstrualFlow(
        value: HKCategoryValueVaginalBleeding,
        date: Date
    ) -> HKCategorySample {
        let type = HKCategoryType.categoryType(forIdentifier: .menstrualFlow)!
        let end = date.addingTimeInterval(60) // 1 minute duration
        return HKCategorySample(type: type, value: value.rawValue, start: date, end: end)
    }
}

extension HKWorkout {
    /// Create a mock workout
    static func mockWorkout(
        activityType: HKWorkoutActivityType = .running,
        start: Date,
        duration: TimeInterval
    ) -> HKWorkout {
        let end = start.addingTimeInterval(duration)
        return HKWorkout(
            activityType: activityType,
            start: start,
            end: end
        )
    }
}

// MARK: - Date Helpers for Testing

extension Date {
    /// Create a date with specific offset from now (in seconds)
    static func offset(_ seconds: TimeInterval) -> Date {
        Date().addingTimeInterval(seconds)
    }

    /// Create a date representing days ago
    static func daysAgo(_ days: Int) -> Date {
        Date().addingTimeInterval(-TimeInterval(days * 24 * 3600))
    }

    /// Create a date representing hours ago
    static func hoursAgo(_ hours: Int) -> Date {
        Date().addingTimeInterval(-TimeInterval(hours * 3600))
    }

    /// Create a date representing minutes ago
    static func minutesAgo(_ minutes: Int) -> Date {
        Date().addingTimeInterval(-TimeInterval(minutes * 60))
    }
}

// MARK: - Mock HealthKitAssistant

/// Mock implementation of HealthKitAssistantProtocol for integration testing
@MainActor
final class MockHealthKitAssistant: HealthKitAssistantProtocol {

    // MARK: - Mock Configuration

    var mockHRV: Double?
    var mockRestingHR: Double?
    var mockSleepHours: Double?
    var mockWorkoutMinutes: Double?
    var mockCycleDay: Int?
    var mockFlowLevel: String?

    // MARK: - Call Tracking

    private(set) var hrvCallCount = 0
    private(set) var restingHRCallCount = 0
    private(set) var sleepCallCount = 0
    private(set) var workoutCallCount = 0
    private(set) var cycleDayCallCount = 0
    private(set) var flowLevelCallCount = 0

    // MARK: - HealthKitAssistantProtocol Implementation

    func recentHRV() async -> Double? {
        hrvCallCount += 1
        return mockHRV
    }

    func recentRestingHR() async -> Double? {
        restingHRCallCount += 1
        return mockRestingHR
    }

    func recentSleepHours() async -> Double? {
        sleepCallCount += 1
        return mockSleepHours
    }

    func recentWorkoutMinutes() async -> Double? {
        workoutCallCount += 1
        return mockWorkoutMinutes
    }

    func recentCycleDay() async -> Int? {
        cycleDayCallCount += 1
        return mockCycleDay
    }

    func recentFlowLevel() async -> String? {
        flowLevelCallCount += 1
        return mockFlowLevel
    }

    // MARK: - Helpers

    /// Configure all HealthKit metrics at once
    func configureAllMetrics(
        hrv: Double? = 45.2,
        restingHR: Double? = 62.0,
        sleepHours: Double? = 7.5,
        workoutMinutes: Double? = 30.0,
        cycleDay: Int? = 14,
        flowLevel: String? = "light"
    ) {
        mockHRV = hrv
        mockRestingHR = restingHR
        mockSleepHours = sleepHours
        mockWorkoutMinutes = workoutMinutes
        mockCycleDay = cycleDay
        mockFlowLevel = flowLevel
    }

    /// Reset all mock data and call counts
    func reset() {
        mockHRV = nil
        mockRestingHR = nil
        mockSleepHours = nil
        mockWorkoutMinutes = nil
        mockCycleDay = nil
        mockFlowLevel = nil
        hrvCallCount = 0
        restingHRCallCount = 0
        sleepCallCount = 0
        workoutCallCount = 0
        cycleDayCallCount = 0
        flowLevelCallCount = 0
    }
}

