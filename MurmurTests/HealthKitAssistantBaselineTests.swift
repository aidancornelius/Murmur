//
//  HealthKitAssistantBaselineTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import HealthKit
import XCTest
@testable import Murmur

@MainActor
final class HealthKitAssistantBaselineTests: HealthKitAssistantTestCase {

    // MARK: - Baseline calculation tests

    func testUpdateHRVBaselineFetches30DaysOfSamples() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create 30 days of samples
        var samples: [HKQuantitySample] = []
        for day in 0..<30 {
            samples.append(HKQuantitySample.mockHRV(value: Double(40 + day), date: .daysAgo(day)))
        }
        await provider.setMockData(quantitySamples: samples, categorySamples: [], workouts: [])

        // Clear existing baseline
        await MainActor.run {
            HealthMetricBaselines.shared.hrvBaseline = nil
        }

        // Act
        await assistant.updateBaselines()

        // Give baselines time to update
        try await waitForAsyncOperations()

        // Assert: Baseline should be calculated
        let baseline = await MainActor.run { HealthMetricBaselines.shared.hrvBaseline }
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline?.sampleCount, 30)
        XCTAssertGreaterThan(baseline?.mean ?? 0, 0)
        XCTAssertGreaterThan(baseline?.standardDeviation ?? 0, 0)
    }

    func testUpdateRestingHRBaselineCalculatesStatistics() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create samples with known values
        let values: [Double] = [60, 62, 61, 63, 59, 64, 60, 61, 62, 63, 65, 64, 62, 61, 60]
        var samples: [HKQuantitySample] = []
        for (index, value) in values.enumerated() {
            samples.append(HKQuantitySample.mockRestingHR(value: value, date: .daysAgo(index)))
        }
        await provider.setMockData(quantitySamples: samples, categorySamples: [], workouts: [])

        // Clear existing baseline
        await MainActor.run {
            HealthMetricBaselines.shared.restingHRBaseline = nil
        }

        // Act
        await assistant.updateBaselines()

        // Give baselines time to update
        try await waitForAsyncOperations()

        // Assert
        let baseline = await MainActor.run { HealthMetricBaselines.shared.restingHRBaseline }
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline?.sampleCount, 15)
        // Mean should be around 61.73
        XCTAssertEqual(baseline?.mean ?? 0, 61.73, accuracy: 0.5)
    }

    func testUpdateBaselinesHandlesInsufficientData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Only 5 samples (need 10+ for baseline)
        var samples: [HKQuantitySample] = []
        for day in 0..<5 {
            samples.append(HKQuantitySample.mockHRV(value: Double(40 + day), date: .daysAgo(day)))
        }
        await provider.setMockData(quantitySamples: samples, categorySamples: [], workouts: [])

        // Clear existing baseline
        await MainActor.run {
            HealthMetricBaselines.shared.hrvBaseline = nil
        }

        // Act
        await assistant.updateBaselines()

        // Give baselines time to update
        try await waitForAsyncOperations()

        // Assert: Should not create baseline with insufficient data
        let baseline = await MainActor.run { HealthMetricBaselines.shared.hrvBaseline }
        XCTAssertNil(baseline)
    }

    func testUpdateBaselinesRunsInParallel() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create samples for both HRV and HR
        var hrvSamples: [HKQuantitySample] = []
        for day in 0..<30 {
            hrvSamples.append(HKQuantitySample.mockHRV(value: Double(40 + day), date: .daysAgo(day)))
            hrvSamples.append(HKQuantitySample.mockRestingHR(value: Double(60 + day), date: .daysAgo(day)))
        }
        await provider.setMockData(quantitySamples: hrvSamples, categorySamples: [], workouts: [])

        let startTime = Date()

        // Act
        await assistant.updateBaselines()

        let duration = Date().timeIntervalSince(startTime)

        // Assert: Should complete quickly (parallel execution)
        // If sequential, would take longer
        XCTAssertLessThan(duration, 2.0) // Should complete in under 2 seconds
    }
}
