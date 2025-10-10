//
//  HealthKitUtilitySmokeTests.swift
//  MurmurTests
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import XCTest
import HealthKit
import HealthKitTestData
@testable import Murmur

/// Focused tests verifying HealthKitUtility synthetic data generation
/// These tests verify the underlying data library works correctly
@MainActor
final class HealthKitUtilitySmokeTests: XCTestCase {

    func testSameParametersProduceIdenticalData() async throws {
        let startDate = Date().addingTimeInterval(-7 * 86400)
        let endDate = Date()

        let bundle1 = SyntheticDataGenerator.generateHealthData(
            preset: .normal,
            manipulation: .smoothReplace,
            startDate: startDate,
            endDate: endDate,
            seed: 42
        )

        let bundle2 = SyntheticDataGenerator.generateHealthData(
            preset: .normal,
            manipulation: .smoothReplace,
            startDate: startDate,
            endDate: endDate,
            seed: 42
        )

        // Verify determinism
        XCTAssertEqual(bundle1.hrv.count, bundle2.hrv.count,
            "Same seed should produce same number of HRV samples")

        if let first1 = bundle1.hrv.first,
           let first2 = bundle2.hrv.first {
            XCTAssertEqual(first1.value, first2.value, accuracy: 0.001,
                "Same seed should produce identical HRV values")
        }
    }

    func testConversionPreservesValues() async throws {
        let bundle = SyntheticDataGenerator.generateHealthData(
            preset: .normal,
            manipulation: .smoothReplace,
            startDate: Date().addingTimeInterval(-7 * 86400),
            endDate: Date(),
            seed: 42
        )

        let (quantitySamples, _, _) = HealthKitUtilityTestHelper.convertToHKSamples(bundle: bundle)

        let hrvSamples = quantitySamples.filter {
            $0.quantityType == HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        }

        XCTAssertEqual(hrvSamples.count, bundle.hrv.count,
            "Conversion should preserve number of HRV samples")
    }
}
