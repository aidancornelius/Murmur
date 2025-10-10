//
//  SeededDataGeneratorTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import XCTest
@testable import Murmur

final class SeededDataGeneratorTests: XCTestCase {

    // MARK: - SeededRandom Tests

    func testSeededRandom_Deterministic() {
        // Given
        var rng1 = SeededRandom(seed: 12345)
        var rng2 = SeededRandom(seed: 12345)

        // When
        let values1 = (0..<10).map { _ in rng1.next() }
        let values2 = (0..<10).map { _ in rng2.next() }

        // Then
        XCTAssertEqual(values1, values2, "Same seed should produce same sequence")
    }

    func testSeededRandom_DifferentSeeds() {
        // Given
        var rng1 = SeededRandom(seed: 12345)
        var rng2 = SeededRandom(seed: 54321)

        // When
        let values1 = (0..<10).map { _ in rng1.next() }
        let values2 = (0..<10).map { _ in rng2.next() }

        // Then
        XCTAssertNotEqual(values1, values2, "Different seeds should produce different sequences")
    }

    func testSeededRandom_RangeDouble() {
        // Given
        var rng = SeededRandom(seed: 12345)
        let range = 10.0...20.0

        // When
        let values = (0..<100).map { _ in rng.next(in: range) }

        // Then
        for value in values {
            XCTAssertGreaterThanOrEqual(value, range.lowerBound)
            XCTAssertLessThanOrEqual(value, range.upperBound)
        }
    }

    func testSeededRandom_RangeInt() {
        // Given
        var rng = SeededRandom(seed: 12345)
        let range = 1...10

        // When
        let values = (0..<100).map { _ in rng.nextInt(in: range) }

        // Then
        for value in values {
            XCTAssertGreaterThanOrEqual(value, range.lowerBound)
            XCTAssertLessThanOrEqual(value, range.upperBound)
        }
    }

    func testSeededRandom_ZeroSeedHandled() {
        // Given
        var rng = SeededRandom(seed: 0)

        // When
        let value = rng.next()

        // Then
        XCTAssertGreaterThanOrEqual(value, 0.0)
        XCTAssertLessThan(value, 1.0)
    }

    // MARK: - Fallback HRV Tests

    func testGetFallbackHRV_PEMDay() {
        // When
        let hrv = SeededDataGenerator.getFallbackHRV(for: .pem, seed: 12345)

        // Then
        XCTAssertGreaterThan(hrv, 15.0, "PEM HRV should be low")
        XCTAssertLessThan(hrv, 30.0)
    }

    func testGetFallbackHRV_FlareDay() {
        // When
        let hrv = SeededDataGenerator.getFallbackHRV(for: .flare, seed: 12345)

        // Then
        XCTAssertGreaterThan(hrv, 15.0, "Flare HRV should be low")
        XCTAssertLessThan(hrv, 30.0)
    }

    func testGetFallbackHRV_BetterDay() {
        // When
        let hrv = SeededDataGenerator.getFallbackHRV(for: .better, seed: 12345)

        // Then
        XCTAssertGreaterThan(hrv, 45.0, "Better day HRV should be high")
        XCTAssertLessThan(hrv, 65.0)
    }

    func testGetFallbackHRV_NormalDay() {
        // When
        let hrv = SeededDataGenerator.getFallbackHRV(for: .normal, seed: 12345)

        // Then
        XCTAssertGreaterThan(hrv, 28.0, "Normal HRV should be moderate")
        XCTAssertLessThan(hrv, 48.0)
    }

    func testGetFallbackHRV_Deterministic() {
        // When
        let hrv1 = SeededDataGenerator.getFallbackHRV(for: .normal, seed: 12345)
        let hrv2 = SeededDataGenerator.getFallbackHRV(for: .normal, seed: 12345)

        // Then
        XCTAssertEqual(hrv1, hrv2, "Same seed should produce same HRV")
    }

    func testGetFallbackHRV_DifferentSeedsDifferentValues() {
        // When
        let hrv1 = SeededDataGenerator.getFallbackHRV(for: .normal, seed: 12345)
        let hrv2 = SeededDataGenerator.getFallbackHRV(for: .normal, seed: 54321)

        // Then
        XCTAssertNotEqual(hrv1, hrv2, "Different seeds should produce different HRV")
    }

    // MARK: - Fallback Resting HR Tests

    func testGetFallbackRestingHR_PEMDay() {
        // When
        let hr = SeededDataGenerator.getFallbackRestingHR(for: .pem, seed: 12345)

        // Then
        XCTAssertGreaterThan(hr, 72.0, "PEM resting HR should be elevated")
        XCTAssertLessThan(hr, 84.0)
    }

    func testGetFallbackRestingHR_BetterDay() {
        // When
        let hr = SeededDataGenerator.getFallbackRestingHR(for: .better, seed: 12345)

        // Then
        XCTAssertGreaterThan(hr, 52.0, "Better day resting HR should be lower")
        XCTAssertLessThan(hr, 64.0)
    }

    func testGetFallbackRestingHR_NormalDay() {
        // When
        let hr = SeededDataGenerator.getFallbackRestingHR(for: .normal, seed: 12345)

        // Then
        XCTAssertGreaterThan(hr, 59.0, "Normal resting HR should be moderate")
        XCTAssertLessThan(hr, 71.0)
    }

    func testGetFallbackRestingHR_Deterministic() {
        // When
        let hr1 = SeededDataGenerator.getFallbackRestingHR(for: .normal, seed: 12345)
        let hr2 = SeededDataGenerator.getFallbackRestingHR(for: .normal, seed: 12345)

        // Then
        XCTAssertEqual(hr1, hr2, "Same seed should produce same resting HR")
    }

    // MARK: - Fallback Sleep Hours Tests

    func testGetFallbackSleepHours_PEMDay() {
        // When
        let sleep = SeededDataGenerator.getFallbackSleepHours(for: .pem, seed: 12345)

        // Then
        XCTAssertGreaterThan(sleep, 3.5, "PEM sleep should be lower")
        XCTAssertLessThan(sleep, 7.5)
    }

    func testGetFallbackSleepHours_BetterDay() {
        // When
        let sleep = SeededDataGenerator.getFallbackSleepHours(for: .better, seed: 12345)

        // Then
        XCTAssertGreaterThan(sleep, 7.0, "Better day sleep should be higher")
        XCTAssertLessThan(sleep, 9.0)
    }

    func testGetFallbackSleepHours_NormalDay() {
        // When
        let sleep = SeededDataGenerator.getFallbackSleepHours(for: .normal, seed: 12345)

        // Then
        XCTAssertGreaterThan(sleep, 6.0, "Normal sleep should be moderate")
        XCTAssertLessThan(sleep, 9.0)
    }

    func testGetFallbackSleepHours_Deterministic() {
        // When
        let sleep1 = SeededDataGenerator.getFallbackSleepHours(for: .normal, seed: 12345)
        let sleep2 = SeededDataGenerator.getFallbackSleepHours(for: .normal, seed: 12345)

        // Then
        XCTAssertEqual(sleep1, sleep2, "Same seed should produce same sleep hours")
    }

    // MARK: - Fallback Workout Minutes Tests

    func testGetFallbackWorkoutMinutes_PEMDay() {
        // When
        let workout = SeededDataGenerator.getFallbackWorkoutMinutes(for: .pem, seed: 12345)

        // Then
        XCTAssertGreaterThanOrEqual(workout, 0.0, "PEM workout should be minimal")
        XCTAssertLessThan(workout, 12.0)
    }

    func testGetFallbackWorkoutMinutes_BetterDay() {
        // When
        let workout = SeededDataGenerator.getFallbackWorkoutMinutes(for: .better, seed: 12345)

        // Then
        XCTAssertGreaterThan(workout, 20.0, "Better day workout should be higher")
        XCTAssertLessThan(workout, 55.0)
    }

    func testGetFallbackWorkoutMinutes_NormalDay() {
        // When
        let workout = SeededDataGenerator.getFallbackWorkoutMinutes(for: .normal, seed: 12345)

        // Then
        XCTAssertGreaterThan(workout, 10.0, "Normal workout should be moderate")
        XCTAssertLessThan(workout, 40.0)
    }

    func testGetFallbackWorkoutMinutes_Deterministic() {
        // When
        let workout1 = SeededDataGenerator.getFallbackWorkoutMinutes(for: .normal, seed: 12345)
        let workout2 = SeededDataGenerator.getFallbackWorkoutMinutes(for: .normal, seed: 12345)

        // Then
        XCTAssertEqual(workout1, workout2, "Same seed should produce same workout minutes")
    }

    // MARK: - Day Type Consistency Tests

    func testAllDayTypes_ProduceDifferentValues() {
        // Given
        let seed = 12345
        let dayTypes: [DayType] = [.pem, .flare, .menstrual, .rest, .better, .normal]

        // When
        let hrvValues = dayTypes.map { SeededDataGenerator.getFallbackHRV(for: $0, seed: seed) }
        let hrValues = dayTypes.map { SeededDataGenerator.getFallbackRestingHR(for: $0, seed: seed) }

        // Then
        XCTAssertEqual(Set(hrvValues).count, hrvValues.count, "Different day types should produce different HRV values")
        XCTAssertEqual(Set(hrValues).count, hrValues.count, "Different day types should produce different HR values")
    }

    func testMenstrualDay_ProducesReasonableValues() {
        // When
        let hrv = SeededDataGenerator.getFallbackHRV(for: .menstrual, seed: 12345)
        let hr = SeededDataGenerator.getFallbackRestingHR(for: .menstrual, seed: 12345)
        let sleep = SeededDataGenerator.getFallbackSleepHours(for: .menstrual, seed: 12345)
        let workout = SeededDataGenerator.getFallbackWorkoutMinutes(for: .menstrual, seed: 12345)

        // Then
        XCTAssertGreaterThan(hrv, 25.0)
        XCTAssertLessThan(hrv, 50.0)
        XCTAssertGreaterThan(hr, 59.0)
        XCTAssertLessThan(hr, 71.0)
        XCTAssertGreaterThan(sleep, 5.0)
        XCTAssertLessThan(sleep, 8.0)
        XCTAssertGreaterThan(workout, 0.0)
        XCTAssertLessThan(workout, 25.0)
    }

    func testRestDay_ProducesReasonableValues() {
        // When
        let hrv = SeededDataGenerator.getFallbackHRV(for: .rest, seed: 12345)
        let hr = SeededDataGenerator.getFallbackRestingHR(for: .rest, seed: 12345)
        let sleep = SeededDataGenerator.getFallbackSleepHours(for: .rest, seed: 12345)
        let workout = SeededDataGenerator.getFallbackWorkoutMinutes(for: .rest, seed: 12345)

        // Then
        XCTAssertGreaterThan(hrv, 25.0)
        XCTAssertLessThan(hrv, 50.0)
        XCTAssertGreaterThan(hr, 59.0)
        XCTAssertLessThan(hr, 71.0)
        XCTAssertGreaterThan(sleep, 5.0)
        XCTAssertLessThan(sleep, 8.0)
        XCTAssertGreaterThan(workout, 0.0)
        XCTAssertLessThan(workout, 25.0)
    }

    // MARK: - Seed Offset Tests

    func testDifferentMetrics_UseDifferentSeedOffsets() {
        // Given
        let seed = 12345

        // When - Get all metrics for same seed
        let hrv = SeededDataGenerator.getFallbackHRV(for: .normal, seed: seed)
        let hr = SeededDataGenerator.getFallbackRestingHR(for: .normal, seed: seed)
        let sleep = SeededDataGenerator.getFallbackSleepHours(for: .normal, seed: seed)
        let workout = SeededDataGenerator.getFallbackWorkoutMinutes(for: .normal, seed: seed)

        // Then - Values should be independent (different due to different seed offsets)
        let normalizedValues = [
            hrv / 50.0,  // Normalize to similar scales for comparison
            hr / 70.0,
            sleep / 8.0,
            workout / 30.0
        ]

        // Check that values are reasonably different
        let allSame = normalizedValues.allSatisfy { abs($0 - normalizedValues[0]) < 0.1 }
        XCTAssertFalse(allSame, "Different metrics should use different seed offsets")
    }
}
