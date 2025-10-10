//
//  HealthKitDataSeeder.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

#if targetEnvironment(simulator)
import Foundation
import HealthKit
import HealthKitTestData
import os.log

/// Errors that can occur during HealthKit data seeding
enum HealthKitError: Error {
    case notAvailable
    case authorizationFailed
    case writeFailed(Error)
    case invalidDateRange
}

/// Seeds the simulator's HealthKit store with realistic synthetic data for testing
/// This service writes directly to HKHealthStore, allowing UI tests to interact with real HealthKit data
@MainActor
final class HealthKitDataSeeder {
    private static let logger = Logger(subsystem: "app.murmur", category: "HealthKitDataSeeder")

    // MARK: - Data Seeding

    /// Seed HealthKit with synthetic data for a specified preset and date range
    /// - Parameters:
    ///   - preset: The health data preset to generate (normal, lowerStress, higherStress, edgeCases)
    ///   - startDate: The start date for the synthetic data range
    ///   - endDate: The end date for the synthetic data range
    ///   - seed: Random seed for reproducible data generation
    /// - Throws: HealthKit authorization or write errors
    static func seedHealthKitData(
        preset: GenerationPreset,
        startDate: Date,
        endDate: Date,
        seed: Int = Int.random(in: 0...Int.max)
    ) async throws {
        logger.info("Starting HealthKit data seeding with preset: \(String(describing: preset))")

        // Check HealthKit availability
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit is not available on this device")
            throw HealthKitError.notAvailable
        }

        // Create HKHealthStore
        let healthStore = HKHealthStore()

        // Request authorization for the data types we'll be writing
        let writeTypes = getRequiredWriteTypes()
        let emptyReadTypes: Set<HKObjectType> = []
        try await healthStore.requestAuthorization(toShare: writeTypes, read: emptyReadTypes)

        logger.info("HealthKit authorization granted, generating synthetic data...")

        // Generate synthetic data bundle
        let bundle = SyntheticDataGenerator.generateHealthData(
            preset: preset,
            manipulation: .smoothReplace,
            startDate: startDate,
            endDate: endDate,
            seed: seed
        )

        logger.info("Successfully generated synthetic health data bundle for date range")

        // Create writer and import data
        let writer = HealthKitWriter(healthStore: healthStore)
        try await writer.importData(bundle)

        logger.info("Successfully seeded HealthKit with \(String(describing: preset)) data from \(startDate) to \(endDate)")
    }

    /// Convenience method to seed with default 7-day range
    /// - Parameters:
    ///   - preset: The health data preset to generate
    ///   - daysOfHistory: Number of days of historical data (default: 7)
    ///   - seed: Random seed for reproducible data generation
    static func seedDefaultData(
        preset: GenerationPreset = .normal,
        daysOfHistory: Int = 7,
        seed: Int = Int.random(in: 0...Int.max)
    ) async throws {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-TimeInterval(daysOfHistory * 24 * 3600))

        try await seedHealthKitData(
            preset: preset,
            startDate: startDate,
            endDate: endDate,
            seed: seed
        )
    }

    // MARK: - Live Data Streaming

    private static var liveDataLoop: LiveDataLoop?

    /// Start streaming live synthetic data to HealthKit
    /// This continuously generates new data points at regular intervals
    /// - Parameters:
    ///   - preset: The health data preset to use for live generation
    ///   - samplingInterval: Time between data point generation (default: 60 seconds)
    /// - Returns: The LiveDataLoop instance for management
    static func startLiveDataStream(
        preset: GenerationPreset = .normal,
        samplingInterval: TimeInterval = 60
    ) async throws -> LiveDataLoop {
        logger.info("Starting live data stream with preset: \(String(describing: preset))")

        // Check HealthKit availability
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit is not available on this device")
            throw HealthKitError.notAvailable
        }

        let healthStore = HKHealthStore()

        // Request authorization
        let writeTypes = getRequiredWriteTypes()
        let emptyReadTypes: Set<HKObjectType> = []
        try await healthStore.requestAuthorization(toShare: writeTypes, read: emptyReadTypes)

        // Create writer
        let writer = HealthKitWriter(healthStore: healthStore)

        // Create live generation config
        let config = LiveGenerationConfig(
            samplingInterval: samplingInterval,
            preset: preset
        )

        // Create and start live loop
        let loop = LiveDataLoop(config: config, writer: writer)

        try await loop.start()

        liveDataLoop = loop
        logger.info("Live data stream started with \(samplingInterval)s interval")

        return loop
    }

    /// Stop the currently running live data stream
    static func stopLiveDataStream() async {
        guard let loop = liveDataLoop else {
            logger.warning("No live data stream to stop")
            return
        }

        await loop.stop()
        liveDataLoop = nil
        logger.info("Live data stream stopped")
    }

    // MARK: - Helper Methods

    /// Get all HealthKit write types required for seeding
    private static func getRequiredWriteTypes() -> Set<HKSampleType> {
        var types: Set<HKSampleType> = []

        // Quantity types
        if let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrvType)
        }
        if let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHRType)
        }
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRateType)
        }
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepsType)
        }
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distanceType)
        }
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energyType)
        }

        // Category types
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }

        // Workout type
        types.insert(HKWorkoutType.workoutType())

        return types
    }
}
#endif
