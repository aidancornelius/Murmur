//
//  HealthKitUtilityExampleTests.swift
//  MurmurTests
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import HealthKit
import HealthKitTestData
import XCTest
@testable import Murmur

/// Focused smoke tests demonstrating HealthKitTestData integration
/// These tests verify that the conversion layer and mock provider integration work correctly
@MainActor
final class HealthKitUtilityExampleTests: XCTestCase {

    // MARK: - Basic Integration Tests

    func testNormalDataGenerationAndConversion() async throws {
        // Arrange: Create a mock provider populated with normal health data
        let mockProvider = createMockProviderWithRealisticData(preset: .normal)
        let healthKit = HealthKitAssistant(dataProvider: mockProvider)

        // Act: Fetch recent HRV
        let hrv = await healthKit.recentHRV()

        // Assert: Should have realistic HRV data
        XCTAssertNotNil(hrv, "Should have HRV data from synthetic generator")
        XCTAssertGreaterThan(hrv ?? 0, 0, "HRV should be positive")

        // Normal HRV is typically between 20-100ms
        XCTAssertGreaterThan(hrv ?? 0, 20, "Normal HRV should be at least 20ms")
        XCTAssertLessThan(hrv ?? 0, 100, "Normal HRV should be less than 100ms")
    }

    func testStressComparisonDemonstration() async throws {
        // Arrange: Create two different stress profiles
        let normalProvider = createMockProviderWithRealisticData(preset: .normal, seed: 12345)
        let stressProvider = createMockProviderWithRealisticData(preset: .higherStress, seed: 12345)

        let normalHealthKit = HealthKitAssistant(dataProvider: normalProvider)
        let stressHealthKit = HealthKitAssistant(dataProvider: stressProvider)

        // Act: Fetch HRV from both
        async let normalHRV = normalHealthKit.recentHRV()
        async let stressHRV = stressHealthKit.recentHRV()

        let (normalValue, stressValue) = await (normalHRV, stressHRV)

        // Assert: Both should have values
        XCTAssertNotNil(normalValue, "Should have normal HRV")
        XCTAssertNotNil(stressValue, "Should have stress HRV")

        // Document the difference (not asserting direction as it depends on generation logic)
        if let normal = normalValue, let stress = stressValue {
            let difference = normal - stress
            print("HRV comparison: Normal=\(normal)ms, HigherStress=\(stress)ms, Difference=\(difference)ms")
        }
    }

    func testBaselineCalculationWithSyntheticData() async throws {
        // Arrange: Create a realistic 30-day dataset
        let mockProvider = createMockProviderWithRealisticData(
            preset: .normal,
            startDate: .daysAgo(30),
            endDate: Date(),
            seed: 54321
        )
        let healthKit = HealthKitAssistant(dataProvider: mockProvider)

        // Clear any existing baselines
        await MainActor.run {
            HealthMetricBaselines.shared.hrvBaseline = nil
            HealthMetricBaselines.shared.restingHRBaseline = nil
        }

        // Act: Update baselines (requires 10+ samples)
        await healthKit.updateBaselines()

        // Give async baseline calculation time to complete
        try await Task.sleep(nanoseconds: 500_000_000)

        // Assert: Should have calculated baselines
        let hrvBaseline = await MainActor.run { HealthMetricBaselines.shared.hrvBaseline }
        let hrBaseline = await MainActor.run { HealthMetricBaselines.shared.restingHRBaseline }

        XCTAssertNotNil(hrvBaseline, "Should have calculated HRV baseline")
        XCTAssertNotNil(hrBaseline, "Should have calculated HR baseline")

        if let hrvBaseline = hrvBaseline {
            XCTAssertGreaterThan(hrvBaseline.sampleCount, 10, "Should have sufficient samples for baseline")
            XCTAssertGreaterThan(hrvBaseline.mean, 0, "Baseline mean should be positive")
            XCTAssertGreaterThan(hrvBaseline.standardDeviation, 0, "Baseline SD should be positive")
            print("HRV Baseline - Mean: \(hrvBaseline.mean), SD: \(hrvBaseline.standardDeviation), Samples: \(hrvBaseline.sampleCount)")
        }

        if let hrBaseline = hrBaseline {
            XCTAssertGreaterThan(hrBaseline.sampleCount, 10, "Should have sufficient samples for baseline")
            XCTAssertGreaterThan(hrBaseline.mean, 30, "Resting HR mean should be realistic")
            XCTAssertLessThan(hrBaseline.mean, 100, "Resting HR mean should be realistic")
            print("HR Baseline - Mean: \(hrBaseline.mean), SD: \(hrBaseline.standardDeviation), Samples: \(hrBaseline.sampleCount)")
        }
    }

    func testConversionLayerProducesValidSamples() {
        // Arrange: Generate a small bundle
        let bundle = HealthKitUtilityTestHelper.generateNormalData(
            startDate: .daysAgo(3),
            endDate: Date(),
            seed: 99999
        )

        // Act: Convert to HKSamples
        let (quantitySamples, categorySamples, workouts) = HealthKitUtilityTestHelper.convertToHKSamples(bundle: bundle)

        // Assert: Should have samples of each type
        XCTAssertFalse(quantitySamples.isEmpty, "Should have quantity samples")
        XCTAssertFalse(categorySamples.isEmpty, "Should have category samples (sleep)")
        XCTAssertFalse(workouts.isEmpty, "Should have workout samples")

        // Verify HRV samples
        let hrvSamples = quantitySamples.filter { $0.quantityType.identifier == HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue }
        XCTAssertFalse(hrvSamples.isEmpty, "Should have HRV samples")

        // Verify resting HR samples
        let hrSamples = quantitySamples.filter { $0.quantityType.identifier == HKQuantityTypeIdentifier.restingHeartRate.rawValue }
        XCTAssertFalse(hrSamples.isEmpty, "Should have resting HR samples")

        // Verify sleep samples
        let sleepSamples = categorySamples.filter { $0.categoryType.identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue }
        XCTAssertFalse(sleepSamples.isEmpty, "Should have sleep samples")

        print("Converted samples - HRV: \(hrvSamples.count), HR: \(hrSamples.count), Sleep: \(sleepSamples.count), Workouts: \(workouts.count)")
    }
}
