//
//  HealthKitUtilityHelpers.swift
//  MurmurTests
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import HealthKit
import HealthKitTestData
import XCTest
@testable import Murmur

// MARK: - HealthKitUtility Integration Helpers

/// Helper class for generating realistic HealthKit test data using HealthKitTestData
/// This allows tests to use data that closely resembles real-world patterns
@MainActor
final class HealthKitUtilityTestHelper {

    // MARK: - Bundle to HKSample Conversion

    /// Convert ExportedHealthBundle to HKSamples that can be used in MockHealthKitDataProvider
    /// This mirrors the conversion logic from HealthKitWriter
    static func convertToHKSamples(bundle: ExportedHealthBundle) -> (
        quantitySamples: [HKQuantitySample],
        categorySamples: [HKCategorySample],
        workouts: [HKWorkout]
    ) {
        var quantitySamples: [HKQuantitySample] = []
        var categorySamples: [HKCategorySample] = []
        var workouts: [HKWorkout] = []

        // Convert heart rate variability
        for item in bundle.hrv {
            guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { continue }
            let quantity = HKQuantity(unit: HKUnit.secondUnit(with: .milli), doubleValue: item.value)
            let sample = HKQuantitySample(
                type: type,
                quantity: quantity,
                start: item.date,
                end: item.date
            )
            quantitySamples.append(sample)
        }

        // Convert resting heart rate
        for item in bundle.restingHeartRate {
            guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { continue }
            let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let quantity = HKQuantity(unit: unit, doubleValue: item.value)
            let sample = HKQuantitySample(
                type: type,
                quantity: quantity,
                start: item.date,
                end: item.date
            )
            quantitySamples.append(sample)
        }

        // Convert sleep analysis
        for item in bundle.sleep {
            guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { continue }
            let value: HKCategoryValueSleepAnalysis
            switch item.stage {
            case .awake: value = .awake
            case .light: value = .asleepCore
            case .deep: value = .asleepDeep
            case .rem: value = .asleepREM
            case .unknown: value = .asleepUnspecified
            }
            let sample = HKCategorySample(
                type: type,
                value: value.rawValue,
                start: item.startDate,
                end: item.endDate
            )
            categorySamples.append(sample)
        }

        // Convert workouts
        for item in bundle.workouts {
            let activityType = workoutActivityType(from: item.type)
            let duration = item.endDate.timeIntervalSince(item.startDate)
            let workout = HKWorkout(
                activityType: activityType,
                start: item.startDate,
                end: item.endDate,
                duration: duration,
                totalEnergyBurned: item.calories.map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) },
                totalDistance: item.distance.map { HKQuantity(unit: .meter(), doubleValue: $0) },
                metadata: nil
            )
            workouts.append(workout)
        }

        return (quantitySamples, categorySamples, workouts)
    }

    // MARK: - Helper Methods

    private static func workoutActivityType(from name: String) -> HKWorkoutActivityType {
        switch name.lowercased() {
        case "running": return .running
        case "walking": return .walking
        case "cycling": return .cycling
        case "swimming": return .swimming
        case "yoga": return .yoga
        case "strength training", "weight training": return .functionalStrengthTraining
        case "hiit": return .highIntensityIntervalTraining
        case "hiking": return .hiking
        case "elliptical": return .elliptical
        case "rowing": return .rowing
        case "dance": return .socialDance
        case "pilates": return .pilates
        case "boxing": return .boxing
        default: return .other
        }
    }

    // MARK: - Data Generation Presets

    /// Generate a bundle of normal, healthy baseline data
    /// - Parameters:
    ///   - startDate: The start date for the data range
    ///   - endDate: The end date for the data range
    ///   - seed: Random seed for reproducibility (default: 42 for deterministic tests)
    /// - Returns: An ExportedHealthBundle with realistic normal health patterns
    static func generateNormalData(
        startDate: Date = Date().addingTimeInterval(-7 * 86400),
        endDate: Date = Date(),
        seed: Int = 42
    ) -> ExportedHealthBundle {
        return SyntheticDataGenerator.generateHealthData(
            preset: .normal,
            manipulation: .smoothReplace,
            startDate: startDate,
            endDate: endDate,
            seed: seed
        )
    }

    /// Generate a bundle of lower stress health data
    /// - Parameters:
    ///   - startDate: The start date for the data range
    ///   - endDate: The end date for the data range
    ///   - seed: Random seed for reproducibility (default: 42 for deterministic tests)
    /// - Returns: An ExportedHealthBundle with realistic lower stress patterns
    static func generateLowerStressData(
        startDate: Date = Date().addingTimeInterval(-7 * 86400),
        endDate: Date = Date(),
        seed: Int = 42
    ) -> ExportedHealthBundle {
        return SyntheticDataGenerator.generateHealthData(
            preset: .lowerStress,
            manipulation: .smoothReplace,
            startDate: startDate,
            endDate: endDate,
            seed: seed
        )
    }

    /// Generate a bundle of higher stress health data
    /// - Parameters:
    ///   - startDate: The start date for the data range
    ///   - endDate: The end date for the data range
    ///   - seed: Random seed for reproducibility (default: 42 for deterministic tests)
    /// - Returns: An ExportedHealthBundle with realistic higher stress patterns
    static func generateHigherStressData(
        startDate: Date = Date().addingTimeInterval(-7 * 86400),
        endDate: Date = Date(),
        seed: Int = 42
    ) -> ExportedHealthBundle {
        return SyntheticDataGenerator.generateHealthData(
            preset: .higherStress,
            manipulation: .smoothReplace,
            startDate: startDate,
            endDate: endDate,
            seed: seed
        )
    }

    /// Generate edge case data for testing boundary conditions
    /// - Parameters:
    ///   - startDate: The start date for the data range
    ///   - endDate: The end date for the data range
    ///   - seed: Random seed for reproducibility (default: 42 for deterministic tests)
    /// - Returns: An ExportedHealthBundle with edge case patterns
    static func generateEdgeCaseData(
        startDate: Date = Date().addingTimeInterval(-7 * 86400),
        endDate: Date = Date(),
        seed: Int = 42
    ) -> ExportedHealthBundle {
        return SyntheticDataGenerator.generateHealthData(
            preset: .edgeCases,
            manipulation: .smoothReplace,
            startDate: startDate,
            endDate: endDate,
            seed: seed
        )
    }

    // MARK: - Mock Data Provider Integration

    /// Populate a MockHealthKitDataProvider with realistic data from HealthKitTestData
    /// - Parameters:
    ///   - provider: The mock provider to populate
    ///   - preset: The data preset to use
    ///   - startDate: The start date for the data range
    ///   - endDate: The end date for the data range
    ///   - seed: Random seed for reproducibility (default: 42 for deterministic tests)
    static func populateMockProvider(
        _ provider: MockHealthKitDataProvider,
        preset: GenerationPreset = .normal,
        startDate: Date = Date().addingTimeInterval(-7 * 86400),
        endDate: Date = Date(),
        seed: Int = 42
    ) async {
        let bundle = SyntheticDataGenerator.generateHealthData(
            preset: preset,
            manipulation: .smoothReplace,
            startDate: startDate,
            endDate: endDate,
            seed: seed
        )

        // Convert to HKSamples
        let (quantitySamples, categorySamples, workouts) = convertToHKSamples(bundle: bundle)

        // Populate the mock provider
        await provider.setMockData(
            quantitySamples: quantitySamples,
            categorySamples: categorySamples,
            workouts: workouts
        )
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {

    /// Create a MockHealthKitDataProvider populated with realistic data
    /// - Parameters:
    ///   - preset: The data preset to use
    ///   - startDate: The start date for the data range
    ///   - endDate: The end date for the data range
    ///   - seed: Random seed for reproducibility (default: 42 for deterministic tests)
    /// - Returns: A configured MockHealthKitDataProvider
    @MainActor
    func createMockProviderWithRealisticData(
        preset: GenerationPreset = .normal,
        startDate: Date = Date().addingTimeInterval(-7 * 86400),
        endDate: Date = Date(),
        seed: Int = 42
    ) async -> MockHealthKitDataProvider {
        let provider = MockHealthKitDataProvider()
        await HealthKitUtilityTestHelper.populateMockProvider(
            provider,
            preset: preset,
            startDate: startDate,
            endDate: endDate,
            seed: seed
        )
        return provider
    }
}
