//
//  HealthKitAssistantManualTrackingTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import HealthKit
import XCTest
@testable import Murmur

@MainActor
final class HealthKitAssistantManualTrackingTests: HealthKitAssistantTestCase {

    // MARK: - Manual cycle tracker integration tests

    func testRecentCycleDayUsesManualTrackerWhenEnabled() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Set up manual tracker with data
        let manualTracker = configureManualCycleTracker(enabled: true, cycleDay: 15)
        assistant.manualCycleTracker = manualTracker

        // Also have HealthKit data (should be ignored)
        provider.mockCategorySamples = [
            HKCategorySample.mockMenstrualFlow(value: .medium, date: .daysAgo(10))
        ]

        // Act
        let cycleDay = await assistant.recentCycleDay()

        // Assert: Should use manual tracker value
        XCTAssertEqual(cycleDay, 15)
        // Should not have queried HealthKit
        XCTAssertEqual(provider.executeCount, 0)
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
        XCTAssertEqual(provider.executeCount, 0)
    }

    func testCycleDataFallsBackToHealthKitWhenManualDisabled() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Manual tracker disabled
        let manualTracker = configureManualCycleTracker(enabled: false)
        assistant.manualCycleTracker = manualTracker

        // HealthKit data available
        provider.mockCategorySamples = [
            HKCategorySample.mockMenstrualFlow(value: .medium, date: .daysAgo(7))
        ]

        // Act
        let cycleDay = await assistant.recentCycleDay()

        // Assert: Should use HealthKit
        XCTAssertEqual(cycleDay, 8) // 7 days ago + 1
        XCTAssertGreaterThan(provider.executeCount, 0)
    }
}
