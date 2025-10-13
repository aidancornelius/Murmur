//
//  HealthKitIntegrationTests.swift
//  Murmur
//
//  Consolidated test suite for HealthKit integration scenarios: error handling, permissions, and manual tracking
//
//  Originally from:
//  - HealthKitAssistantErrorHandlingTests.swift (6 tests)
//  - HealthKitAssistantManualTrackingTests.swift (3 tests)
//

import HealthKit
import XCTest
@testable import Murmur
final class HealthKitAssistantErrorHandlingTests: HealthKitAssistantTestCase {

    // MARK: - Error Handling Tests

    func testRecentHRVHandlesQueryError() async throws {
        // Arrange: Simulate query error
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        await provider.setShouldThrowError(NSError(domain: HKErrorDomain, code: HKError.errorDatabaseInaccessible.rawValue))

        // Act
        let hrv = await assistant.recentHRV()

        // Assert: Should return nil on error
        XCTAssertNil(hrv)
    }

    func testRecentRestingHRHandlesError() async throws {
        // Arrange
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        await provider.setShouldThrowError(NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationDenied.rawValue))

        // Act
        let result = await assistant.recentRestingHR()

        // Assert
        XCTAssertNil(result)
    }

    // MARK: - Permission and Availability Tests

    func testRequestPermissionsRequestsAllRequiredTypes() async throws {
        // Arrange
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Act
        try await assistant.requestPermissions()

        // Assert
        let requestAuthorizationCalled = await provider.requestAuthorizationCalled
        XCTAssertTrue(requestAuthorizationCalled)
        let requestedReadTypes = await provider.requestedReadTypes
        let readTypes = try XCTUnwrap(requestedReadTypes)
        let shareTypes = await provider.requestedShareTypes
        let shareTypesCount = shareTypes?.count ?? 0
        XCTAssertEqual(shareTypesCount, 0) // No write access

        // Verify specific types requested
        XCTAssertTrue(readTypes.contains(where: { ($0 as? HKQuantityType)?.identifier == HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue }))
        XCTAssertTrue(readTypes.contains(where: { ($0 as? HKQuantityType)?.identifier == HKQuantityTypeIdentifier.restingHeartRate.rawValue }))
        XCTAssertTrue(readTypes.contains(where: { ($0 as? HKCategoryType)?.identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue }))
        XCTAssertTrue(readTypes.contains(HKObjectType.workoutType()))
        XCTAssertTrue(readTypes.contains(where: { ($0 as? HKCategoryType)?.identifier == HKCategoryTypeIdentifier.menstrualFlow.rawValue }))
    }

    func testRequestPermissionsHandlesDenial() async throws {
        // Arrange
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        await provider.setAuthorizationError(NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationDenied.rawValue))

        // Act & Assert
        do {
            try await assistant.requestPermissions()
            XCTFail("Should have thrown error")
        } catch {
            // Expected
        }
    }

    func testBootstrapAuthorizationsRunsCompleteFlow() async throws {
        // Arrange
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        await provider.setMockData(
            quantitySamples: [HKQuantitySample.mockHRV(value: 45.0, date: Date())],
            categorySamples: [],
            workouts: []
        )

        // Act
        await assistant.bootstrapAuthorizations()

        // Give async tasks time to complete
        try await waitForAsyncOperations()

        // Assert: Should have requested permissions
        let requestAuthorizationCalled = await provider.requestAuthorizationCalled
        XCTAssertTrue(requestAuthorizationCalled)
        // Should have executed queries for context refresh
        let executeCount = await provider.executeCount
        XCTAssertGreaterThan(executeCount, 0)
    }

    func testBootstrapAuthorizationsHandlesErrors() async throws {
        // Arrange: Simulate authorisation failure
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        await provider.setAuthorizationError(NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationNotDetermined.rawValue))

        // Act: Should not crash
        await assistant.bootstrapAuthorizations()

        // Assert: Error should be handled gracefully
        // (logging happens internally, we just verify no crash)
    }
}

// MARK: - Manual Tracking Integration Tests

final class HealthKitAssistantManualTrackingTests: HealthKitAssistantTestCase {

    // MARK: - Manual cycle tracker integration tests

    func testRecentCycleDayUsesManualTrackerWhenEnabled() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Set up manual tracker with data
        let manualTracker = configureManualCycleTracker(enabled: true, cycleDay: 15)
        assistant.manualCycleTracker = manualTracker

        // Also have HealthKit data (should be ignored)
        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [
                HKCategorySample.mockMenstrualFlow(value: .medium, date: .daysAgo(10))
            ],
            workouts: []
        )

        // Act
        let cycleDay = await assistant.recentCycleDay()

        // Assert: Should use manual tracker value
        XCTAssertEqual(cycleDay, 15)
        // Should not have queried HealthKit
        let executeCount = await provider.executeCount
        XCTAssertEqual(executeCount, 0)
    }

    func testRecentFlowLevelUsesManualTrackerWhenEnabled() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        let today = Date()
        let manualTracker = configureManualCycleTracker(
            enabled: true,
            flowEntries: [today: "heavy"]
        )
        assistant.manualCycleTracker = manualTracker

        // Give tracker time to refresh
        try await Task.sleep(nanoseconds: 100_000_000)

        // Act
        let flowLevel = await assistant.recentFlowLevel()

        // Assert: Should use manual tracker
        XCTAssertEqual(flowLevel, "heavy")
        let executeCount = await provider.executeCount
        XCTAssertEqual(executeCount, 0)
    }

    func testCycleDataFallsBackToHealthKitWhenManualDisabled() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Manual tracker disabled
        let manualTracker = configureManualCycleTracker(enabled: false)
        assistant.manualCycleTracker = manualTracker

        // HealthKit data available
        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [
                HKCategorySample.mockMenstrualFlow(value: .medium, date: .daysAgo(7))
            ],
            workouts: []
        )

        // Act
        let cycleDay = await assistant.recentCycleDay()

        // Assert: Should use HealthKit
        XCTAssertEqual(cycleDay, 8) // 7 days ago + 1
        let executeCount = await provider.executeCount
        XCTAssertGreaterThan(executeCount, 0)
    }
}
