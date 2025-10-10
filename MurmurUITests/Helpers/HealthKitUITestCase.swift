//
//  HealthKitUITestCase.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import XCTest

/// Base class for UI tests that need real HealthKit data
/// Simplifies launching the app with HealthKit seeding flags
class HealthKitUITestCase: XCTestCase {
    var app: XCUIApplication!

    /// Launch app with HealthKit data seeded with normal health profile
    /// - Parameters:
    ///   - daysOfHistory: Number of days of historical data to seed (default: 7)
    ///   - enableLiveData: Whether to start live data streaming (default: false)
    ///   - additionalArguments: Any additional launch arguments
    func launchWithNormalHealthKit(
        daysOfHistory: Int = 7,
        enableLiveData: Bool = false,
        additionalArguments: [String] = []
    ) {
        app = XCUIApplication()

        var arguments = [
            "-UITestMode",
            "-SeedHealthKitNormal",
            "-HealthKitHistoryDays", String(daysOfHistory)
        ]

        if enableLiveData {
            arguments.append("-EnableLiveHealthData")
        }

        arguments.append(contentsOf: additionalArguments)

        app.launchArguments = arguments
        app.launch()

        // Wait for HealthKit seeding to complete
        // The app shows progress view during seeding
        waitForAppToLoad()
    }

    /// Launch app with HealthKit data seeded with higher stress profile
    /// - Parameters:
    ///   - daysOfHistory: Number of days of historical data to seed (default: 7)
    ///   - enableLiveData: Whether to start live data streaming (default: false)
    ///   - additionalArguments: Any additional launch arguments
    func launchWithHigherStressHealthKit(
        daysOfHistory: Int = 7,
        enableLiveData: Bool = false,
        additionalArguments: [String] = []
    ) {
        app = XCUIApplication()

        var arguments = [
            "-UITestMode",
            "-SeedHealthKitHigherStress",
            "-HealthKitHistoryDays", String(daysOfHistory)
        ]

        if enableLiveData {
            arguments.append("-EnableLiveHealthData")
        }

        arguments.append(contentsOf: additionalArguments)

        app.launchArguments = arguments
        app.launch()

        waitForAppToLoad()
    }

    /// Launch app with HealthKit data seeded with lower stress profile
    /// - Parameters:
    ///   - daysOfHistory: Number of days of historical data to seed (default: 7)
    ///   - enableLiveData: Whether to start live data streaming (default: false)
    ///   - additionalArguments: Any additional launch arguments
    func launchWithLowerStressHealthKit(
        daysOfHistory: Int = 7,
        enableLiveData: Bool = false,
        additionalArguments: [String] = []
    ) {
        app = XCUIApplication()

        var arguments = [
            "-UITestMode",
            "-SeedHealthKitLowerStress",
            "-HealthKitHistoryDays", String(daysOfHistory)
        ]

        if enableLiveData {
            arguments.append("-EnableLiveHealthData")
        }

        arguments.append(contentsOf: additionalArguments)

        app.launchArguments = arguments
        app.launch()

        waitForAppToLoad()
    }

    /// Launch app with HealthKit edge case data
    /// - Parameters:
    ///   - daysOfHistory: Number of days of historical data to seed (default: 7)
    ///   - additionalArguments: Any additional launch arguments
    func launchWithEdgeCaseHealthKit(
        daysOfHistory: Int = 7,
        additionalArguments: [String] = []
    ) {
        app = XCUIApplication()

        var arguments = [
            "-UITestMode",
            "-SeedHealthKitEdgeCases",
            "-HealthKitHistoryDays", String(daysOfHistory)
        ]

        arguments.append(contentsOf: additionalArguments)

        app.launchArguments = arguments
        app.launch()

        waitForAppToLoad()
    }

    /// Launch app with deterministic HealthKit data using an explicit seed
    /// This ensures reproducible test results - same seed always produces identical data
    /// - Parameters:
    ///   - seed: The random seed for deterministic data generation (default: 42)
    ///   - daysOfHistory: Number of days of historical data to seed (default: 7)
    ///   - preset: Health profile preset (default: .normal)
    ///   - additionalArguments: Any additional launch arguments
    func launchWithDeterministicHealthKit(
        seed: Int = 42,
        daysOfHistory: Int = 7,
        preset: String = "normal",
        additionalArguments: [String] = []
    ) {
        app = XCUIApplication()

        var arguments = [
            "-UITestMode",
            "-SeedHealthKitNormal",  // Use normal as default
            "-HealthKitHistoryDays", String(daysOfHistory),
            "-HealthKitSeed", String(seed)  // Explicit seed for determinism
        ]

        // Override preset if specified
        if preset == "higherStress" {
            arguments[1] = "-SeedHealthKitHigherStress"
        } else if preset == "lowerStress" {
            arguments[1] = "-SeedHealthKitLowerStress"
        }

        arguments.append(contentsOf: additionalArguments)

        app.launchArguments = arguments
        app.launch()

        waitForAppToLoad()
    }

    /// Wait for the app to finish loading after HealthKit seeding
    private func waitForAppToLoad() {
        // Wait for main UI element to appear (log symptom button)
        let logButton = app.buttons.matching(identifier: "log-symptom-button").firstMatch
        XCTAssertTrue(
            logButton.waitForExistence(timeout: 15),
            "App should load within 15 seconds after HealthKit seeding"
        )
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }
}
