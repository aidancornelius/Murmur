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
actor MockHealthKitDataProvider: HealthKitDataProvider {

    // MARK: - Mock Configuration

    nonisolated(unsafe) var mockQuantitySamples: [HKQuantitySample] = []
    nonisolated(unsafe) var mockCategorySamples: [HKCategorySample] = []
    nonisolated(unsafe) var mockWorkouts: [HKWorkout] = []
    nonisolated(unsafe) var mockStatistics: HKStatistics?
    nonisolated(unsafe) var shouldThrowError: Error?
    nonisolated(unsafe) var authorizationError: Error?

    // MARK: - Tracking

    nonisolated(unsafe) private(set) var fetchQuantityCount = 0
    nonisolated(unsafe) private(set) var fetchCategoryCount = 0
    nonisolated(unsafe) private(set) var fetchWorkoutsCount = 0
    nonisolated(unsafe) private(set) var fetchStatisticsCount = 0
    nonisolated(unsafe) private(set) var requestAuthorizationCalled = false
    nonisolated(unsafe) private(set) var requestedReadTypes: Set<HKObjectType>?
    nonisolated(unsafe) private(set) var requestedShareTypes: Set<HKSampleType>?

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

    func fetchStatistics(
        quantityType: HKQuantityType,
        predicate: NSPredicate?,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics? {
        fetchStatisticsCount += 1

        if let error = shouldThrowError {
            throw error
        }

        return mockStatistics
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
        return (samples as NSArray).sortedArray(using: sortDescriptors) as? [T] ?? samples
    }

    // MARK: - Configuration Helper

    /// Set mock data for testing (actor-safe method)
    func setMockData(
        quantitySamples: [HKQuantitySample],
        categorySamples: [HKCategorySample],
        workouts: [HKWorkout]
    ) {
        self.mockQuantitySamples = quantitySamples
        self.mockCategorySamples = categorySamples
        self.mockWorkouts = workouts
    }

    /// Set error for query operations (actor-safe method)
    func setShouldThrowError(_ error: Error?) {
        self.shouldThrowError = error
    }

    /// Set error for authorization operations (actor-safe method)
    func setAuthorizationError(_ error: Error?) {
        self.authorizationError = error
    }

    // MARK: - Reset

    nonisolated func reset() {
        mockQuantitySamples.removeAll()
        mockCategorySamples.removeAll()
        mockWorkouts.removeAll()
        mockStatistics = nil
        shouldThrowError = nil
        authorizationError = nil
        fetchQuantityCount = 0
        fetchCategoryCount = 0
        fetchWorkoutsCount = 0
        fetchStatisticsCount = 0
        requestAuthorizationCalled = false
        requestedReadTypes = nil
        requestedShareTypes = nil
    }

    /// Property for backwards compatibility with existing tests
    nonisolated var executeCount: Int {
        fetchQuantityCount + fetchCategoryCount + fetchWorkoutsCount + fetchStatisticsCount
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

    // MARK: - Historical Data (ForDate Methods)

    func hrvForDate(_ date: Date) async -> Double? {
        hrvCallCount += 1
        return mockHRV
    }

    func restingHRForDate(_ date: Date) async -> Double? {
        restingHRCallCount += 1
        return mockRestingHR
    }

    func sleepHoursForDate(_ date: Date) async -> Double? {
        sleepCallCount += 1
        return mockSleepHours
    }

    func workoutMinutesForDate(_ date: Date) async -> Double? {
        workoutCallCount += 1
        return mockWorkoutMinutes
    }

    func cycleDayForDate(_ date: Date) async -> Int? {
        cycleDayCallCount += 1
        return mockCycleDay
    }

    func flowLevelForDate(_ date: Date) async -> String? {
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

// MARK: - Mock Query Service

/// Mock implementation of HealthKitQueryServiceProtocol for testing
actor MockHealthKitQueryService: HealthKitQueryServiceProtocol {

    // MARK: - HealthKitQueryServiceProtocol Properties

    var dataProvider: HealthKitDataProvider
    nonisolated(unsafe) var isHealthDataAvailable: Bool = true

    // MARK: - Mock Configuration

    var mockQuantitySamples: [HKQuantitySample] = []
    var mockCategorySamples: [HKCategorySample] = []
    var mockWorkouts: [HKWorkout] = []
    var mockStatistics: HKStatistics?
    var shouldThrowError: Error?
    var authorizationError: Error?

    // MARK: - Call Tracking

    private(set) var fetchQuantityCount = 0
    private(set) var fetchCategoryCount = 0
    private(set) var fetchWorkoutsCount = 0
    private(set) var fetchStatisticsCount = 0
    private(set) var requestAuthorizationCalled = false

    // MARK: - Init

    init(dataProvider: HealthKitDataProvider) {
        self.dataProvider = dataProvider
    }

    // MARK: - HealthKitQueryServiceProtocol Implementation

    func fetchQuantitySamples(
        for quantityType: HKQuantityType,
        start: Date,
        end: Date,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKQuantitySample] {
        fetchQuantityCount += 1

        if let error = shouldThrowError {
            throw error
        }

        var filtered = mockQuantitySamples.filter { $0.startDate >= start && $0.startDate < end }

        if let sortDescriptors = sortDescriptors, !sortDescriptors.isEmpty {
            filtered = (filtered as NSArray).sortedArray(using: sortDescriptors) as? [HKQuantitySample] ?? filtered
        }

        if limit != HKObjectQueryNoLimit && limit > 0 {
            filtered = Array(filtered.prefix(limit))
        }

        return filtered
    }

    func fetchCategorySamples(
        for categoryType: HKCategoryType,
        start: Date,
        end: Date,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKCategorySample] {
        fetchCategoryCount += 1

        if let error = shouldThrowError {
            throw error
        }

        var filtered = mockCategorySamples.filter { $0.startDate >= start && $0.startDate < end }

        if let sortDescriptors = sortDescriptors, !sortDescriptors.isEmpty {
            filtered = (filtered as NSArray).sortedArray(using: sortDescriptors) as? [HKCategorySample] ?? filtered
        }

        if limit != HKObjectQueryNoLimit && limit > 0 {
            filtered = Array(filtered.prefix(limit))
        }

        return filtered
    }

    func fetchWorkouts(
        start: Date,
        end: Date,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKWorkout] {
        fetchWorkoutsCount += 1

        if let error = shouldThrowError {
            throw error
        }

        var filtered = mockWorkouts.filter { $0.startDate >= start && $0.startDate < end }

        if let sortDescriptors = sortDescriptors, !sortDescriptors.isEmpty {
            filtered = (filtered as NSArray).sortedArray(using: sortDescriptors) as? [HKWorkout] ?? filtered
        }

        if limit != HKObjectQueryNoLimit && limit > 0 {
            filtered = Array(filtered.prefix(limit))
        }

        return filtered
    }

    func fetchStatistics(
        quantityType: HKQuantityType,
        start: Date,
        end: Date,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics? {
        fetchStatisticsCount += 1

        if let error = shouldThrowError {
            throw error
        }

        return mockStatistics
    }

    func requestPermissions() async throws {
        requestAuthorizationCalled = true

        if let error = authorizationError {
            throw error
        }
    }

    func fetchSleepSamples(
        start: Date,
        end: Date
    ) async throws -> [HKCategorySample] {
        // Return filtered category samples
        return mockCategorySamples.filter { $0.startDate >= start && $0.startDate < end }
    }

    func fetchDetailedSleepData() async -> (bedTime: Date?, wakeTime: Date?, totalHours: Double?)? {
        // Return nil for tests - override in specific tests if needed
        return nil
    }

    // MARK: - Configuration Helper

    /// Set error for testing (actor-safe method)
    func setError(_ error: Error?) {
        self.shouldThrowError = error
    }

    // MARK: - Reset

    func reset() {
        mockQuantitySamples.removeAll()
        mockCategorySamples.removeAll()
        mockWorkouts.removeAll()
        mockStatistics = nil
        shouldThrowError = nil
        authorizationError = nil
        fetchQuantityCount = 0
        fetchCategoryCount = 0
        fetchWorkoutsCount = 0
        fetchStatisticsCount = 0
        requestAuthorizationCalled = false
    }
}

// MARK: - Mock Cache Service

/// Mock implementation of HealthKitCacheServiceProtocol for testing
actor MockHealthKitCacheService: HealthKitCacheServiceProtocol {

    // MARK: - Storage

    private var lastSampleDates: [HealthMetric: Date] = [:]
    private var historicalCache: [String: Any] = [:]

    // MARK: - Call Tracking

    private(set) var getLastSampleDateCallCount = 0
    private(set) var setLastSampleDateCallCount = 0
    private(set) var shouldRefreshCallCount = 0
    private(set) var getCachedValueCallCount = 0
    private(set) var setCachedValueCallCount = 0
    private(set) var clearCacheCallCount = 0

    // MARK: - HealthKitCacheServiceProtocol Implementation

    func getLastSampleDate(for metric: HealthMetric) -> Date? {
        getLastSampleDateCallCount += 1
        return lastSampleDates[metric]
    }

    func setLastSampleDate(_ date: Date, for metric: HealthMetric) {
        setLastSampleDateCallCount += 1
        lastSampleDates[metric] = date
    }

    func shouldRefresh(metric: HealthMetric, cacheDuration: TimeInterval, force: Bool) -> Bool {
        shouldRefreshCallCount += 1
        if force { return true }
        guard let lastDate = getLastSampleDate(for: metric) else { return true }
        return Date().timeIntervalSince(lastDate) >= cacheDuration
    }

    func getCachedValue<T>(for metric: HealthMetric, date: Date) -> T? {
        getCachedValueCallCount += 1
        let key = cacheKey(for: metric, date: date)
        return historicalCache[key] as? T
    }

    func setCachedValue<T>(_ value: T, for metric: HealthMetric, date: Date) {
        setCachedValueCallCount += 1
        let key = cacheKey(for: metric, date: date)
        historicalCache[key] = value
    }

    func clearCache() {
        clearCacheCallCount += 1
        lastSampleDates.removeAll()
        historicalCache.removeAll()
    }

    // MARK: - Helpers

    private func cacheKey(for metric: HealthMetric, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(metric)-\(formatter.string(from: date))"
    }

    func reset() {
        lastSampleDates.removeAll()
        historicalCache.removeAll()
        getLastSampleDateCallCount = 0
        setLastSampleDateCallCount = 0
        shouldRefreshCallCount = 0
        getCachedValueCallCount = 0
        setCachedValueCallCount = 0
        clearCacheCallCount = 0
    }
}

// MARK: - Mock Baseline Calculator

/// Mock implementation of HealthKitBaselineCalculatorProtocol for testing
@MainActor
final class MockHealthKitBaselineCalculator: HealthKitBaselineCalculatorProtocol {

    // MARK: - Call Tracking

    private(set) var updateBaselinesCallCount = 0
    private(set) var updateHRVBaselineCallCount = 0
    private(set) var updateRestingHRBaselineCallCount = 0

    // MARK: - Mock Configuration

    var shouldThrowError: Error?

    // MARK: - HealthKitBaselineCalculatorProtocol Implementation

    func updateBaselines() async {
        updateBaselinesCallCount += 1
        await updateHRVBaseline()
        await updateRestingHRBaseline()
    }

    func updateHRVBaseline() async {
        updateHRVBaselineCallCount += 1
    }

    func updateRestingHRBaseline() async {
        updateRestingHRBaselineCallCount += 1
    }

    // MARK: - Reset

    func reset() {
        updateBaselinesCallCount = 0
        updateHRVBaselineCallCount = 0
        updateRestingHRBaselineCallCount = 0
        shouldThrowError = nil
    }
}

