//
//  HealthKitTestHelpers.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import HealthKit
import XCTest
@testable import Murmur

// MARK: - Mock HealthKit Store

/// Mock implementation of HealthKitStoreProtocol for testing
@MainActor
final class MockHealthKitStore: HealthKitStoreProtocol {

    // MARK: - Mock Configuration

    var mockQuantitySamples: [HKQuantitySample] = []
    var mockCategorySamples: [HKCategorySample] = []
    var mockWorkouts: [HKWorkout] = []
    var shouldThrowError: Error?
    var authorizationError: Error?

    // MARK: - Tracking

    private(set) var executeCount = 0
    private(set) var stopCount = 0
    private(set) var requestAuthorizationCalled = false
    private(set) var requestedReadTypes: Set<HKObjectType>?
    private(set) var requestedShareTypes: Set<HKSampleType>?
    private(set) var executedQueries: [HKQuery] = []

    // MARK: - HealthKitStoreProtocol Implementation

    func execute(_ query: HKQuery) {
        executeCount += 1
        executedQueries.append(query)

        // Simulate async callback
        Task { @MainActor in
            if let error = shouldThrowError {
                self.deliverError(error, to: query)
                return
            }

            self.deliverResults(to: query)
        }
    }

    func stop(_ query: HKQuery) {
        stopCount += 1
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

    private func deliverError(_ error: Error, to query: HKQuery) {
        if let sampleQuery = query as? HKSampleQuery {
            sampleQuery.resultsHandler?(sampleQuery, nil, error)
        }
    }

    private func deliverResults(to query: HKQuery) {
        guard let sampleQuery = query as? HKSampleQuery else { return }

        // Determine which samples to return based on query type
        let sampleType = sampleQuery.sampleType

        if sampleType is HKQuantityType {
            // Filter by predicate if present
            let filteredSamples = filterSamples(mockQuantitySamples, with: sampleQuery.predicate)

            // Apply sort descriptors
            let sortedSamples = sortSamples(filteredSamples, using: sampleQuery.sortDescriptors)

            // Apply limit
            let limitedSamples = Array(sortedSamples.prefix(sampleQuery.limit == HKObjectQueryNoLimit ? sortedSamples.count : sampleQuery.limit))

            sampleQuery.resultsHandler?(sampleQuery, limitedSamples, nil)
        } else if sampleType is HKCategoryType {
            // Filter category samples
            let filteredSamples = filterSamples(mockCategorySamples, with: sampleQuery.predicate)
            let sortedSamples = sortSamples(filteredSamples, using: sampleQuery.sortDescriptors)
            let limitedSamples = Array(sortedSamples.prefix(sampleQuery.limit == HKObjectQueryNoLimit ? sortedSamples.count : sampleQuery.limit))

            sampleQuery.resultsHandler?(sampleQuery, limitedSamples, nil)
        } else if sampleType is HKWorkoutType {
            // Filter workouts
            let filteredWorkouts = filterSamples(mockWorkouts, with: sampleQuery.predicate)
            let sortedWorkouts = sortSamples(filteredWorkouts, using: sampleQuery.sortDescriptors)
            let limitedWorkouts = Array(sortedWorkouts.prefix(sampleQuery.limit == HKObjectQueryNoLimit ? sortedWorkouts.count : sampleQuery.limit))

            sampleQuery.resultsHandler?(sampleQuery, limitedWorkouts, nil)
        }
    }

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
        executeCount = 0
        stopCount = 0
        requestAuthorizationCalled = false
        requestedReadTypes = nil
        requestedShareTypes = nil
        executedQueries.removeAll()
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

