// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// HealthKitQueryTests.swift
// Created by Aidan Cornelius-Bell on 13/10/2025.
// Tests for HealthKit query construction.
//
import XCTest
import HealthKit
@testable import Murmur

// MARK: - Query Service Tests

@MainActor
final class HealthKitQueryServiceTests: XCTestCase {

    var mockDataProvider: MockHealthKitDataProvider?
    var queryService: HealthKitQueryService?

    override func setUp() async throws {
        try await super.setUp()
        mockDataProvider = MockHealthKitDataProvider()
        queryService = HealthKitQueryService(dataProvider: mockDataProvider!)
    }

    override func tearDown() async throws {
        mockDataProvider = nil
        queryService = nil
        try await super.tearDown()
    }

    // MARK: - Quantity Sample Tests

    func testFetchQuantitySamples_Success() async throws {
        // Given
        let mockSamples = [
            HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(1)),
            HKQuantitySample.mockHRV(value: 50.0, date: .daysAgo(2))
        ]
        await mockDataProvider!.setMockData(quantitySamples: mockSamples, categorySamples: [], workouts: [])

        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            XCTFail("HRV type unavailable")
            return
        }

        // When
        let start = Date.daysAgo(3)
        let end = Date()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let samples = try await queryService!.fetchQuantitySamples(
            for: hrvType,
            start: start,
            end: end,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        )

        // Then
        XCTAssertEqual(samples.count, 2)
        let fetchCount = await mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)
    }

    func testFetchQuantitySamples_WithLimit() async throws {
        // Given
        let mockSamples = [
            HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(1)),
            HKQuantitySample.mockHRV(value: 50.0, date: .daysAgo(2)),
            HKQuantitySample.mockHRV(value: 42.0, date: .daysAgo(3))
        ]
        await mockDataProvider!.setMockData(quantitySamples: mockSamples, categorySamples: [], workouts: [])

        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            XCTFail("HRV type unavailable")
            return
        }

        // When
        let start = Date.daysAgo(5)
        let end = Date()
        let samples = try await queryService!.fetchQuantitySamples(
            for: hrvType,
            start: start,
            end: end,
            limit: 2,
            sortDescriptors: nil
        )

        // Then
        XCTAssertEqual(samples.count, 2)
    }

    func testFetchQuantitySamples_Error() async {
        // Given
        await mockDataProvider!.setShouldThrowError(NSError(domain: "TestError", code: 1))

        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            XCTFail("HRV type unavailable")
            return
        }

        // When/Then
        do {
            _ = try await queryService!.fetchQuantitySamples(
                for: hrvType,
                start: Date.daysAgo(1),
                end: Date(),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            )
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Category Sample Tests

    func testFetchCategorySamples_Success() async throws {
        // Given
        let mockSamples = [
            HKCategorySample.mockSleep(
                value: .asleepCore,
                start: .hoursAgo(8),
                duration: 8 * 3600
            )
        ]
        await mockDataProvider!.setMockData(quantitySamples: [], categorySamples: mockSamples, workouts: [])

        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            XCTFail("Sleep type unavailable")
            return
        }

        // When
        let start = Date.hoursAgo(12)
        let end = Date()
        let samples = try await queryService!.fetchCategorySamples(
            for: sleepType,
            start: start,
            end: end,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        )

        // Then
        XCTAssertEqual(samples.count, 1)
        let fetchCount = await mockDataProvider!.fetchCategoryCount
        XCTAssertEqual(fetchCount, 1)
    }

    // MARK: - Workout Tests

    func testFetchWorkouts_Success() async throws {
        // Given
        let mockWorkouts = [
            HKWorkout.mockWorkout(
                activityType: .running,
                start: .hoursAgo(2),
                duration: 30 * 60
            )
        ]
        await mockDataProvider!.setMockData(quantitySamples: [], categorySamples: [], workouts: mockWorkouts)

        // When
        let start = Date.hoursAgo(5)
        let end = Date()
        let workouts = try await queryService!.fetchWorkouts(
            start: start,
            end: end,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        )

        // Then
        XCTAssertEqual(workouts.count, 1)
        let fetchCount = await mockDataProvider!.fetchWorkoutsCount
        XCTAssertEqual(fetchCount, 1)
    }

    // MARK: - Statistics Tests

    func testFetchStatistics_Success() async throws {
        // Given
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            XCTFail("HRV type unavailable")
            return
        }

        let start = Date.daysAgo(1)
        let end = Date()

        // Note: HKStatistics has no public initializer, so we test with nil
        // The important part is verifying the query method is called correctly
        await mockDataProvider!.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

        // When
        let stats = try await queryService!.fetchStatistics(
            quantityType: hrvType,
            start: start,
            end: end,
            options: [.discreteAverage]
        )

        // Then
        let fetchCount = await mockDataProvider!.fetchStatisticsCount
        XCTAssertEqual(fetchCount, 1)
        // With mock returning nil, stats should be nil
        XCTAssertNil(stats)
    }

    // MARK: - Authorization Tests

    func testRequestPermissions_Success() async throws {
        // When
        try await queryService!.requestPermissions()

        // Then
        let authCalled = await mockDataProvider!.requestAuthorizationCalled
        XCTAssertTrue(authCalled)
    }

    func testRequestPermissions_Error() async {
        // Given
        await mockDataProvider!.setAuthorizationError(NSError(domain: "AuthError", code: 2))

        // When/Then
        do {
            try await queryService!.requestPermissions()
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}

// MARK: - Cache Service Tests

final class HealthKitCacheServiceTests: XCTestCase {

    var cacheService: HealthKitCacheService!

    override func setUp() {
        super.setUp()
        cacheService = HealthKitCacheService()
    }

    override func tearDown() {
        cacheService = nil
        super.tearDown()
    }

    // MARK: - Last Sample Date Tests

    func testGetLastSampleDate_InitiallyNil() async {
        // When
        let date = await cacheService.getLastSampleDate(for: .hrv)

        // Then
        XCTAssertNil(date)
    }

    func testSetAndGetLastSampleDate() async {
        // Given
        let now = Date()

        // When
        await cacheService.setLastSampleDate(now, for: .hrv)
        let retrieved = await cacheService.getLastSampleDate(for: .hrv)

        // Then
        XCTAssertNotNil(retrieved)
        if let retrieved = retrieved {
            XCTAssertEqual(retrieved.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
        }
    }

    func testLastSampleDate_IndependentPerMetric() async {
        // Given
        let hrvDate = Date()
        let hrDate = Date().addingTimeInterval(-3600)

        // When
        await cacheService.setLastSampleDate(hrvDate, for: .hrv)
        await cacheService.setLastSampleDate(hrDate, for: .restingHR)

        // Then
        let retrievedHRV = await cacheService.getLastSampleDate(for: .hrv)
        let retrievedHR = await cacheService.getLastSampleDate(for: .restingHR)

        if let retrievedHRV = retrievedHRV {
            XCTAssertEqual(retrievedHRV.timeIntervalSince1970, hrvDate.timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail("HRV date should not be nil")
        }
        if let retrievedHR = retrievedHR {
            XCTAssertEqual(retrievedHR.timeIntervalSince1970, hrDate.timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail("HR date should not be nil")
        }
    }

    // MARK: - Should Refresh Tests

    func testShouldRefresh_NoCacheReturnsTrue() async {
        // When
        let shouldRefresh = await cacheService.shouldRefresh(metric: .hrv, cacheDuration: 300, force: false)

        // Then
        XCTAssertTrue(shouldRefresh)
    }

    func testShouldRefresh_ForceAlwaysReturnsTrue() async {
        // Given
        await cacheService.setLastSampleDate(Date(), for: .hrv)

        // When
        let shouldRefresh = await cacheService.shouldRefresh(metric: .hrv, cacheDuration: 300, force: true)

        // Then
        XCTAssertTrue(shouldRefresh)
    }

    func testShouldRefresh_WithinDurationReturnsFalse() async {
        // Given
        await cacheService.setLastSampleDate(Date(), for: .hrv)

        // When
        let shouldRefresh = await cacheService.shouldRefresh(metric: .hrv, cacheDuration: 300, force: false)

        // Then
        XCTAssertFalse(shouldRefresh)
    }

    func testShouldRefresh_ExpiredReturnsTrue() async {
        // Given
        let oldDate = Date().addingTimeInterval(-600) // 10 minutes ago
        await cacheService.setLastSampleDate(oldDate, for: .hrv)

        // When
        let shouldRefresh = await cacheService.shouldRefresh(metric: .hrv, cacheDuration: 300, force: false) // 5 min cache

        // Then
        XCTAssertTrue(shouldRefresh)
    }

    // MARK: - Historical Cache Tests

    func testGetCachedValue_InitiallyNil() async {
        // When
        let value: Double? = await cacheService.getCachedValue(for: .hrv, date: Date())

        // Then
        XCTAssertNil(value)
    }

    func testSetAndGetCachedValue_Double() async {
        // Given
        let date = Date()
        let hrvValue = 45.2

        // When
        await cacheService.setCachedValue(hrvValue, for: .hrv, date: date)
        let retrieved: Double? = await cacheService.getCachedValue(for: .hrv, date: date)

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, hrvValue)
    }

    func testSetAndGetCachedValue_Int() async {
        // Given
        let date = Date()
        let cycleDayValue = 14

        // When
        await cacheService.setCachedValue(cycleDayValue, for: .cycleDay, date: date)
        let retrieved: Int? = await cacheService.getCachedValue(for: .cycleDay, date: date)

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, cycleDayValue)
    }

    func testSetAndGetCachedValue_String() async {
        // Given
        let date = Date()
        let flowValue = "light"

        // When
        await cacheService.setCachedValue(flowValue, for: .flowLevel, date: date)
        let retrieved: String? = await cacheService.getCachedValue(for: .flowLevel, date: date)

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, flowValue)
    }

    func testCachedValue_IndependentPerMetric() async {
        // Given
        let date = Date()

        // When
        await cacheService.setCachedValue(45.2, for: .hrv, date: date)
        await cacheService.setCachedValue(65.0, for: .restingHR, date: date)

        // Then
        let hrv: Double? = await cacheService.getCachedValue(for: .hrv, date: date)
        let hr: Double? = await cacheService.getCachedValue(for: .restingHR, date: date)

        XCTAssertEqual(hrv, 45.2)
        XCTAssertEqual(hr, 65.0)
    }

    func testCachedValue_IndependentPerDate() async {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        // When
        await cacheService.setCachedValue(45.2, for: .hrv, date: today)
        await cacheService.setCachedValue(50.0, for: .hrv, date: yesterday)

        // Then
        let todayValue: Double? = await cacheService.getCachedValue(for: .hrv, date: today)
        let yesterdayValue: Double? = await cacheService.getCachedValue(for: .hrv, date: yesterday)

        XCTAssertEqual(todayValue, 45.2)
        XCTAssertEqual(yesterdayValue, 50.0)
    }

    func testCachedValue_SameDayReturnsSameValue() async {
        // Given
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let evening = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!

        // When
        await cacheService.setCachedValue(45.2, for: .hrv, date: morning)
        let retrievedEvening: Double? = await cacheService.getCachedValue(for: .hrv, date: evening)

        // Then
        XCTAssertEqual(retrievedEvening, 45.2, "Same day should return cached value")
    }

    // MARK: - Clear Cache Tests

    func testClearCache_ClearsRecentData() async {
        // Given
        await cacheService.setLastSampleDate(Date(), for: .hrv)
        await cacheService.setLastSampleDate(Date(), for: .restingHR)

        // When
        await cacheService.clearCache()

        // Then
        let hrvDate = await cacheService.getLastSampleDate(for: .hrv)
        let hrDate = await cacheService.getLastSampleDate(for: .restingHR)
        XCTAssertNil(hrvDate)
        XCTAssertNil(hrDate)
    }

    func testClearCache_ClearsHistoricalData() async {
        // Given
        let date = Date()
        await cacheService.setCachedValue(45.2, for: .hrv, date: date)
        await cacheService.setCachedValue(65.0, for: .restingHR, date: date)

        // When
        await cacheService.clearCache()

        // Then
        let hrv: Double? = await cacheService.getCachedValue(for: .hrv, date: date)
        let hr: Double? = await cacheService.getCachedValue(for: .restingHR, date: date)

        XCTAssertNil(hrv)
        XCTAssertNil(hr)
    }

    // MARK: - Type Safety Tests

    func testCachedValue_WrongTypeReturnsNil() async {
        // Given
        let date = Date()
        await cacheService.setCachedValue(45.2, for: .hrv, date: date)

        // When - Try to retrieve as wrong type
        let wrongType: Int? = await cacheService.getCachedValue(for: .hrv, date: date)

        // Then
        XCTAssertNil(wrongType, "Should return nil when retrieving with wrong type")
    }

    // MARK: - All Metrics Tests

    func testAllMetricTypes() async {
        // Given
        let date = Date()
        let metrics: [(HealthMetric, Any)] = [
            (.hrv, 45.2),
            (.restingHR, 65.0),
            (.sleep, 7.5),
            (.workout, 30.0),
            (.cycleDay, 14),
            (.flowLevel, "light")
        ]

        // When
        for (metric, value) in metrics {
            if let doubleValue = value as? Double {
                await cacheService.setCachedValue(doubleValue, for: metric, date: date)
            } else if let intValue = value as? Int {
                await cacheService.setCachedValue(intValue, for: metric, date: date)
            } else if let stringValue = value as? String {
                await cacheService.setCachedValue(stringValue, for: metric, date: date)
            }
        }

        // Then
        let hrv: Double? = await cacheService.getCachedValue(for: .hrv, date: date)
        let restingHR: Double? = await cacheService.getCachedValue(for: .restingHR, date: date)
        let sleep: Double? = await cacheService.getCachedValue(for: .sleep, date: date)
        let workout: Double? = await cacheService.getCachedValue(for: .workout, date: date)
        let cycleDay: Int? = await cacheService.getCachedValue(for: .cycleDay, date: date)
        let flowLevel: String? = await cacheService.getCachedValue(for: .flowLevel, date: date)

        XCTAssertEqual(hrv, 45.2)
        XCTAssertEqual(restingHR, 65.0)
        XCTAssertEqual(sleep, 7.5)
        XCTAssertEqual(workout, 30.0)
        XCTAssertEqual(cycleDay, 14)
        XCTAssertEqual(flowLevel, "light")
    }
}

// MARK: - Query Lifecycle Tests

@MainActor
final class HealthKitAssistantQueryLifecycleTests: HealthKitAssistantTestCase {

    // MARK: - Cache Management Tests

    func testRefreshContextForcesRefreshOfAllMetrics() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Populate all caches
        await provider.setMockData(
            quantitySamples: [
                HKQuantitySample.mockHRV(value: 45.0, date: Date()),
                HKQuantitySample.mockRestingHR(value: 65.0, date: Date())
            ],
            categorySamples: [
                HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 7 * 3600),
                HKCategorySample.mockMenstrualFlow(value: .medium, date: Calendar.current.startOfDay(for: .daysAgo(5)))
            ],
            workouts: [
                HKWorkout.mockWorkout(start: .hoursAgo(5), duration: 30 * 60)
            ]
        )

        // Act
        await assistant.refreshContext()

        // Assert: All metrics should be queried
        // Note: We expect 5 queries (HRV, HR, Sleep, Workout, Cycle)
        let executeCount = await provider.executeCount
        XCTAssertGreaterThanOrEqual(executeCount, 5)
    }

    func testForceRefreshAllBypassesCaches() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Populate caches with initial values
        await provider.setMockData(
            quantitySamples: [HKQuantitySample.mockHRV(value: 45.0, date: Date())],
            categorySamples: [],
            workouts: []
        )
        _ = await assistant.recentHRV()
        let initialExecuteCount = await provider.executeCount
        XCTAssertEqual(initialExecuteCount, 1)

        // Update mock data
        await provider.setMockData(
            quantitySamples: [HKQuantitySample.mockHRV(value: 55.0, date: Date())],
            categorySamples: [],
            workouts: []
        )

        // Act: Force refresh should bypass cache
        await assistant.forceRefreshAll()

        // Assert: Should have executed new query
        let finalExecuteCount = await provider.executeCount
        XCTAssertGreaterThan(finalExecuteCount, 1)
    }

    // MARK: - Query Lifecycle Tests

    func testQueriesAddedToActiveQueriesOnExecution() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        await provider.setMockData(
            quantitySamples: [HKQuantitySample.mockHRV(value: 45.0, date: Date())],
            categorySamples: [],
            workouts: []
        )

        // Act
        _ = await assistant.recentHRV()

        // Assert: Query should have been added and then removed
        XCTAssertEqual(assistant._activeQueriesCount, 0) // Should be cleaned up
        let executeCount = await provider.executeCount
        XCTAssertEqual(executeCount, 1)
    }

    func testQueriesRemovedAfterCompletion() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        await provider.setMockData(
            quantitySamples: [HKQuantitySample.mockHRV(value: 45.0, date: Date())],
            categorySamples: [],
            workouts: []
        )

        // Act: Execute multiple queries
        async let hrv = assistant.recentHRV()
        async let hr = assistant.recentRestingHR()

        _ = await hrv
        _ = await hr

        // Give cleanup time to complete
        try await waitForAsyncOperations(milliseconds: 100)

        // Assert: All queries should be cleaned up
        XCTAssertEqual(assistant._activeQueriesCount, 0)
    }

    // MARK: - Behavioural Tests

    func testMostRecentSamplesPrioritised() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Multiple samples, newest should be returned
        let samples = [
            HKQuantitySample.mockHRV(value: 40.0, date: .hoursAgo(70)),
            HKQuantitySample.mockHRV(value: 45.0, date: .hoursAgo(50)),
            HKQuantitySample.mockHRV(value: 50.0, date: .hoursAgo(10)),
            HKQuantitySample.mockHRV(value: 52.0, date: .hoursAgo(1))
        ]
        await provider.setMockData(
            quantitySamples: samples,
            categorySamples: [],
            workouts: []
        )

        // Act
        let hrv = await assistant.recentHRV()

        // Assert: Should return most recent (52.0)
        XCTAssertEqual(hrv ?? 0, 52.0, accuracy: 0.01)
    }
}
