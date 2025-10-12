//
//  HealthKitBaselineCalculatorTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import XCTest
import HealthKit
@testable import Murmur

@MainActor
final class HealthKitBaselineCalculatorTests: XCTestCase {

    var mockDataProvider: MockHealthKitDataProvider?
    var mockQueryService: MockHealthKitQueryService?
    var baselineCalculator: HealthKitBaselineCalculator?

    override func setUp() async throws {
        try await super.setUp()
        mockDataProvider = MockHealthKitDataProvider()
        mockQueryService = MockHealthKitQueryService(dataProvider: mockDataProvider!)
        baselineCalculator = HealthKitBaselineCalculator(queryService: mockQueryService!)
    }

    override func tearDown() async throws {
        mockDataProvider?.reset()
        mockDataProvider = nil
        mockQueryService = nil
        baselineCalculator = nil
        try await super.tearDown()
    }

    // MARK: - Update HRV Baseline Tests

    func testUpdateHRVBaseline_Success() async {
        // Given
        let mockSamples = [
            HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(1)),
            HKQuantitySample.mockHRV(value: 50.0, date: .daysAgo(5)),
            HKQuantitySample.mockHRV(value: 42.0, date: .daysAgo(10)),
            HKQuantitySample.mockHRV(value: 48.0, date: .daysAgo(15)),
            HKQuantitySample.mockHRV(value: 46.0, date: .daysAgo(20))
        ]
        await mockDataProvider!.setMockData(quantitySamples: mockSamples, categorySamples: [], workouts: [])

        // When
        await baselineCalculator!.updateHRVBaseline()

        // Then
        let fetchCount = mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)

        // Verify baseline was updated (check singleton)
        let baseline = HealthMetricBaselines.shared.hrvBaseline
        XCTAssertNotNil(baseline)
        if let baseline = baseline {
            XCTAssertGreaterThan(baseline.mean, 0)
        } else {
            XCTFail("Baseline should not be nil")
        }
    }

    func testUpdateHRVBaseline_NoSamples() async {
        // Given
        await mockDataProvider!.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

        // When
        await baselineCalculator!.updateHRVBaseline()

        // Then
        let fetchCount = mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)
        // Baseline should remain unchanged or be nil
    }

    func testUpdateHRVBaseline_WithError() async {
        // Given
        await mockDataProvider!.setMockData(quantitySamples: [], categorySamples: [], workouts: [])
        await mockQueryService!.setError(NSError(domain: "TestError", code: 1))

        // When
        await baselineCalculator!.updateHRVBaseline()

        // Then
        let fetchCount = await mockQueryService!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)
        // Should handle error gracefully without crashing
    }

    // MARK: - Update Resting HR Baseline Tests

    func testUpdateRestingHRBaseline_Success() async {
        // Given
        let mockSamples = [
            HKQuantitySample.mockRestingHR(value: 62.0, date: .daysAgo(1)),
            HKQuantitySample.mockRestingHR(value: 64.0, date: .daysAgo(5)),
            HKQuantitySample.mockRestingHR(value: 60.0, date: .daysAgo(10)),
            HKQuantitySample.mockRestingHR(value: 63.0, date: .daysAgo(15)),
            HKQuantitySample.mockRestingHR(value: 61.0, date: .daysAgo(20))
        ]
        await mockDataProvider!.setMockData(quantitySamples: mockSamples, categorySamples: [], workouts: [])

        // When
        await baselineCalculator!.updateRestingHRBaseline()

        // Then
        let fetchCount = mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)

        // Verify baseline was updated
        let baseline = HealthMetricBaselines.shared.restingHRBaseline
        XCTAssertNotNil(baseline)
        if let baseline = baseline {
            XCTAssertGreaterThan(baseline.mean, 0)
        } else {
            XCTFail("Baseline should not be nil")
        }
    }

    func testUpdateRestingHRBaseline_NoSamples() async {
        // Given
        await mockDataProvider!.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

        // When
        await baselineCalculator!.updateRestingHRBaseline()

        // Then
        let fetchCount = mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)
    }

    func testUpdateRestingHRBaseline_WithError() async {
        // Given
        await mockDataProvider!.setMockData(quantitySamples: [], categorySamples: [], workouts: [])
        await mockQueryService!.setError(NSError(domain: "TestError", code: 1))

        // When
        await baselineCalculator!.updateRestingHRBaseline()

        // Then
        let fetchCount = await mockQueryService!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)
        // Should handle error gracefully
    }

    // MARK: - Update All Baselines Tests

    func testUpdateBaselines_Success() async {
        // Given
        let hrvSamples = [
            HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(1)),
            HKQuantitySample.mockHRV(value: 50.0, date: .daysAgo(5))
        ]

        let hrSamples = [
            HKQuantitySample.mockRestingHR(value: 62.0, date: .daysAgo(1)),
            HKQuantitySample.mockRestingHR(value: 64.0, date: .daysAgo(5))
        ]

        await mockDataProvider!.setMockData(quantitySamples: hrvSamples + hrSamples, categorySamples: [], workouts: [])

        // When
        await baselineCalculator!.updateBaselines()

        // Then
        // Should call both HRV and resting HR fetches
        let fetchCount = mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 2, "Should fetch both HRV and resting HR")
    }

    func testUpdateBaselines_ConcurrentExecution() async {
        // Given
        await mockDataProvider!.setMockData(
            quantitySamples: [
                HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(1)),
                HKQuantitySample.mockRestingHR(value: 62.0, date: .daysAgo(1))
            ],
            categorySamples: [],
            workouts: []
        )

        // When
        let startTime = Date()
        await baselineCalculator!.updateBaselines()
        let duration = Date().timeIntervalSince(startTime)

        // Then
        let fetchCount = mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 2)
        // Should complete quickly since it's concurrent (not a strict test, but validates structure)
        XCTAssertLessThan(duration, 1.0, "Should execute concurrently")
    }

    // MARK: - Baseline Value Calculation Tests

    func testHRVBaseline_CalculatesCorrectValue() async {
        // Given - 30 days of samples with known values
        let values = [45.0, 50.0, 42.0, 48.0, 46.0, 44.0, 47.0, 49.0, 43.0, 45.0]
        let mockSamples = values.enumerated().map { index, value in
            HKQuantitySample.mockHRV(value: value, date: .daysAgo(index + 1))
        }
        await mockDataProvider!.setMockData(quantitySamples: mockSamples, categorySamples: [], workouts: [])

        // Clear existing baseline
        HealthMetricBaselines.shared.updateHRVBaseline(from: [])

        // When
        await baselineCalculator!.updateHRVBaseline()

        // Then
        let baseline = HealthMetricBaselines.shared.hrvBaseline
        if let baseline = baseline {
            XCTAssertGreaterThan(baseline.mean, 0)

            // Baseline should be within range of input values
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 0
            XCTAssertGreaterThanOrEqual(baseline.mean, minValue)
            XCTAssertLessThanOrEqual(baseline.mean, maxValue)
        } else {
            XCTFail("Baseline should not be nil")
        }
    }

    func testRestingHRBaseline_CalculatesCorrectValue() async {
        // Given
        let values = [62.0, 64.0, 60.0, 63.0, 61.0, 65.0, 59.0, 62.0, 63.0, 61.0]
        let mockSamples = values.enumerated().map { index, value in
            HKQuantitySample.mockRestingHR(value: value, date: .daysAgo(index + 1))
        }
        await mockDataProvider!.setMockData(quantitySamples: mockSamples, categorySamples: [], workouts: [])

        // Clear existing baseline
        HealthMetricBaselines.shared.updateRestingHRBaseline(from: [])

        // When
        await baselineCalculator!.updateRestingHRBaseline()

        // Then
        let baseline = HealthMetricBaselines.shared.restingHRBaseline
        if let baseline = baseline {
            XCTAssertGreaterThan(baseline.mean, 0)

            // Baseline should be within range of input values
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 0
            XCTAssertGreaterThanOrEqual(baseline.mean, minValue)
            XCTAssertLessThanOrEqual(baseline.mean, maxValue)
        } else {
            XCTFail("Baseline should not be nil")
        }
    }

    // MARK: - Date Range Tests

    func testUpdateBaselines_Queries30Days() async {
        // Given
        await mockDataProvider!.setMockData(
            quantitySamples: [
                HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(1))
            ],
            categorySamples: [],
            workouts: []
        )

        // When
        await baselineCalculator!.updateHRVBaseline()

        // Then
        let fetchCount = mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)
        // Note: We can't directly verify the date range in mock, but the implementation
        // should query 30 days. This could be enhanced with more sophisticated mocking.
    }
}
