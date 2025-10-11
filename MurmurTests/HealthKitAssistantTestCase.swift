//
//  HealthKitAssistantTestCase.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import HealthKit
import XCTest
@testable import Murmur

/// Base test case for HealthKitAssistant tests
/// Provides common setup, teardown, and helper utilities for all HealthKit assistant test suites
@MainActor
class HealthKitAssistantTestCase: XCTestCase {

    // MARK: - Properties

    /// Mock data provider for HealthKit queries
    private(set) var mockDataProvider: MockHealthKitDataProvider?

    /// The HealthKitAssistant instance under test
    private(set) var healthKit: HealthKitAssistant?

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Initialize mock data provider
        let provider = MockHealthKitDataProvider()
        mockDataProvider = provider

        // Initialize HealthKitAssistant with mock provider
        healthKit = HealthKitAssistant(dataProvider: provider)
    }

    override func tearDown() async throws {
        // Clean up mock data
        mockDataProvider?.reset()
        mockDataProvider = nil

        // Clean up assistant instance
        healthKit = nil

        try await super.tearDown()
    }

    // MARK: - Helper Methods

    /// Configure the mock data provider with sample data for common test scenarios
    func configureMockData(
        hrv: [HKQuantitySample] = [],
        restingHR: [HKQuantitySample] = [],
        sleep: [HKCategorySample] = [],
        workouts: [HKWorkout] = [],
        menstrualFlow: [HKCategorySample] = []
    ) {
        guard let provider = mockDataProvider else {
            XCTFail("mockDataProvider not initialized - setUp() may not have been called")
            return
        }
        provider.mockQuantitySamples = hrv + restingHR
        provider.mockCategorySamples = sleep + menstrualFlow
        provider.mockWorkouts = workouts
    }

    /// Helper to invalidate cache for a specific metric
    func invalidateCache(for key: String, date: Date = .daysAgo(1)) {
        guard let assistant = healthKit else {
            XCTFail("healthKit not initialized - setUp() may not have been called")
            return
        }
        assistant._setCacheTimestamp(date, for: key)
    }

    /// Helper to configure a manual cycle tracker with test data
    func configureManualCycleTracker(
        enabled: Bool,
        cycleDay: Int? = nil,
        flowEntries: [Date: String] = [:]
    ) -> ManualCycleTracker {
        let testStack = InMemoryCoreDataStack()
        let tracker = ManualCycleTracker(context: testStack!.context)

        tracker.setEnabled(enabled)

        if let cycleDay = cycleDay {
            tracker.setCycleDay(cycleDay)
        }

        for (date, flowLevel) in flowEntries {
            try? tracker.addEntry(date: date, flowLevel: flowLevel)
        }

        return tracker
    }

    /// Wait for async operations to complete
    func waitForAsyncOperations(milliseconds: UInt64 = 500) async throws {
        try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
    }
}
