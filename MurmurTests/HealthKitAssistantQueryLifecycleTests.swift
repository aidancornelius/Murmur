//
//  HealthKitAssistantQueryLifecycleTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import HealthKit
import XCTest
@testable import Murmur

@MainActor
final class HealthKitAssistantQueryLifecycleTests: HealthKitAssistantTestCase {

    // MARK: - Cache Management Tests

    func testRefreshContextForcesRefreshOfAllMetrics() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Populate all caches
        provider.mockQuantitySamples = [
            HKQuantitySample.mockHRV(value: 45.0, date: Date()),
            HKQuantitySample.mockRestingHR(value: 65.0, date: Date())
        ]
        provider.mockCategorySamples = [
            HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 7 * 3600),
            HKCategorySample.mockMenstrualFlow(value: .medium, date: Calendar.current.startOfDay(for: .daysAgo(5)))
        ]
        provider.mockWorkouts = [
            HKWorkout.mockWorkout(start: .hoursAgo(5), duration: 30 * 60)
        ]

        // Act
        await assistant.refreshContext()

        // Assert: All metrics should be queried
        // Note: We expect 5 queries (HRV, HR, Sleep, Workout, Cycle)
        XCTAssertGreaterThanOrEqual(provider.executeCount, 5)
    }

    func testForceRefreshAllBypassesCaches() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Populate caches with initial values
        provider.mockQuantitySamples = [HKQuantitySample.mockHRV(value: 45.0, date: Date())]
        _ = await assistant.recentHRV()
        XCTAssertEqual(provider.executeCount, 1)

        // Update mock data
        provider.mockQuantitySamples = [HKQuantitySample.mockHRV(value: 55.0, date: Date())]

        // Act: Force refresh should bypass cache
        await assistant.forceRefreshAll()

        // Assert: Should have executed new query
        XCTAssertGreaterThan(provider.executeCount, 1)
    }

    // MARK: - Query Lifecycle Tests

    func testQueriesAddedToActiveQueriesOnExecution() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        provider.mockQuantitySamples = [HKQuantitySample.mockHRV(value: 45.0, date: Date())]

        // Act
        _ = await assistant.recentHRV()

        // Assert: Query should have been added and then removed
        XCTAssertEqual(assistant._activeQueriesCount, 0) // Should be cleaned up
        XCTAssertEqual(provider.executeCount, 1)
    }

    func testQueriesRemovedAfterCompletion() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        provider.mockQuantitySamples = [HKQuantitySample.mockHRV(value: 45.0, date: Date())]

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
        provider.mockQuantitySamples = samples

        // Act
        let hrv = await assistant.recentHRV()

        // Assert: Should return most recent (52.0)
        XCTAssertEqual(hrv ?? 0, 52.0, accuracy: 0.01)
    }
}
