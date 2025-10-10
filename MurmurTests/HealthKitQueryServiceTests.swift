//
//  HealthKitQueryServiceTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import XCTest
import HealthKit
@testable import Murmur

@MainActor
final class HealthKitQueryServiceTests: XCTestCase {

    var mockDataProvider: MockHealthKitDataProvider!
    var queryService: HealthKitQueryService!

    override func setUp() async throws {
        try await super.setUp()
        mockDataProvider = MockHealthKitDataProvider()
        queryService = HealthKitQueryService(dataProvider: mockDataProvider)
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
        mockDataProvider.mockQuantitySamples = mockSamples

        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            XCTFail("HRV type unavailable")
            return
        }

        // When
        let start = Date.daysAgo(3)
        let end = Date()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let samples = try await queryService.fetchQuantitySamples(
            for: hrvType,
            start: start,
            end: end,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sort]
        )

        // Then
        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(mockDataProvider.fetchQuantityCount, 1)
    }

    func testFetchQuantitySamples_WithLimit() async throws {
        // Given
        let mockSamples = [
            HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(1)),
            HKQuantitySample.mockHRV(value: 50.0, date: .daysAgo(2)),
            HKQuantitySample.mockHRV(value: 42.0, date: .daysAgo(3))
        ]
        mockDataProvider.mockQuantitySamples = mockSamples

        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            XCTFail("HRV type unavailable")
            return
        }

        // When
        let start = Date.daysAgo(5)
        let end = Date()
        let samples = try await queryService.fetchQuantitySamples(
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
        mockDataProvider.shouldThrowError = NSError(domain: "TestError", code: 1)

        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            XCTFail("HRV type unavailable")
            return
        }

        // When/Then
        do {
            _ = try await queryService.fetchQuantitySamples(
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
        mockDataProvider.mockCategorySamples = mockSamples

        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            XCTFail("Sleep type unavailable")
            return
        }

        // When
        let start = Date.hoursAgo(12)
        let end = Date()
        let samples = try await queryService.fetchCategorySamples(
            for: sleepType,
            start: start,
            end: end,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        )

        // Then
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(mockDataProvider.fetchCategoryCount, 1)
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
        mockDataProvider.mockWorkouts = mockWorkouts

        // When
        let start = Date.hoursAgo(5)
        let end = Date()
        let workouts = try await queryService.fetchWorkouts(
            start: start,
            end: end,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        )

        // Then
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(mockDataProvider.fetchWorkoutsCount, 1)
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
        mockDataProvider.mockStatistics = nil

        // When
        let stats = try await queryService.fetchStatistics(
            quantityType: hrvType,
            start: start,
            end: end,
            options: [.discreteAverage]
        )

        // Then
        XCTAssertEqual(mockDataProvider.fetchStatisticsCount, 1)
        // With mock returning nil, stats should be nil
        XCTAssertNil(stats)
    }

    // MARK: - Authorization Tests

    func testRequestPermissions_Success() async throws {
        // When
        try await queryService.requestPermissions()

        // Then
        XCTAssertTrue(mockDataProvider.requestAuthorizationCalled)
    }

    func testRequestPermissions_Error() async {
        // Given
        mockDataProvider.authorizationError = NSError(domain: "AuthError", code: 2)

        // When/Then
        do {
            try await queryService.requestPermissions()
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
