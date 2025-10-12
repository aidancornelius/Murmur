//
//  HealthKitAssistantErrorHandlingTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import HealthKit
import XCTest
@testable import Murmur

@MainActor
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
