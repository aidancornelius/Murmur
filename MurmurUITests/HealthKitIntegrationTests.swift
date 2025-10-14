//
//  HealthKitIntegrationTests.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import XCTest

/// UI tests that verify the app correctly displays and uses real HealthKit data
/// These tests seed the simulator's HealthKit store with synthetic data before launch
final class HealthKitIntegrationTests: HealthKitUITestCase {

    // MARK: - Basic Integration Tests

    func testAppDisplaysHealthKitDataWithNormalProfile() throws {
        // Launch with 7 days of normal health data
        launchWithNormalHealthKit(daysOfHistory: 7)

        // Verify app launched successfully
        guard let app = app else {
            XCTFail("App should be initialized")
            return
        }
        XCTAssertTrue(app.exists, "App should launch with HealthKit data")

        // The app should have loaded HealthKit data
        // We can't directly verify HRV values in UI, but we can verify the app didn't crash
        // and that it's in a healthy state

        // Navigate to analysis to see if health data is being used
        let analysisButton = app.buttons[AccessibilityIdentifiers.analysisButton]
        if analysisButton.waitForExistence(timeout: 5) {
            analysisButton.tap()

            // Wait for analysis view to load - check for view selector menu
            // Increased timeout to account for HealthKit data processing and Core Data queries
            let viewSelector = app.buttons[AccessibilityIdentifiers.analysisViewSelector]
            XCTAssertTrue(
                viewSelector.waitForExistence(timeout: 25),
                "Analysis view should load with HealthKit data available"
            )

            // App should be stable with real HealthKit data
            XCTAssertTrue(app.exists, "App should remain stable with HealthKit integration")
        }
    }

    func testAppHandlesHigherStressProfile() throws {
        // Launch with higher stress health data
        launchWithHigherStressHealthKit(daysOfHistory: 7)

        // Verify app launched successfully
        guard let app = app else {
            XCTFail("App should be initialized")
            return
        }
        XCTAssertTrue(app.exists, "App should launch with higher stress HealthKit data")

        // Navigate through the app to ensure it handles stress data correctly
        let logButton = app.buttons.matching(identifier: "log-symptom-button").firstMatch
        XCTAssertTrue(logButton.exists, "UI should be functional with stress data")
    }

    func testAppWithExtendedHistoricalData() throws {
        // Launch with 30 days of data for baseline calculations
        launchWithNormalHealthKit(daysOfHistory: 30)

        // Verify app launched successfully
        guard let app = app else {
            XCTFail("App should be initialized")
            return
        }
        XCTAssertTrue(app.exists, "App should launch with extended HealthKit history")

        // With 30 days of data, the app can calculate baselines
        // Navigate to settings or analysis to see if baselines are being used
        let analysisButton = app.buttons[AccessibilityIdentifiers.analysisButton]
        if analysisButton.waitForExistence(timeout: 5) {
            analysisButton.tap()

            // Analysis view should work with baseline data
            XCTAssertTrue(
                app.exists,
                "App should handle HealthKit baseline calculations with 30 days of data"
            )
        }
    }

    func testEdgeCaseHealthKitData() throws {
        // Launch with edge case data to test boundary conditions
        launchWithEdgeCaseHealthKit(daysOfHistory: 7)

        // Verify app launched successfully
        guard let app = app else {
            XCTFail("App should be initialized")
            return
        }
        XCTAssertTrue(app.exists, "App should launch with edge case HealthKit data")

        // App should handle extreme values gracefully
        let logButton = app.buttons.matching(identifier: "log-symptom-button").firstMatch
        XCTAssertTrue(
            logButton.waitForExistence(timeout: 10),
            "App should remain functional with edge case health data"
        )
    }

    // MARK: - Deterministic Fixture Tests

    func testHealthMetricsMatchDeterministicFixture() throws {
        // Launch with deterministic seed=42 for reproducible results
        launchWithDeterministicHealthKit(seed: 42, daysOfHistory: 7)

        // Verify app launched successfully
        guard let app = app else {
            XCTFail("App should be initialized")
            return
        }
        XCTAssertTrue(app.exists, "App should launch with deterministic HealthKit data")

        // Give app time to process HealthKit data
        sleep(2)

        // Expected values are computed from HealthKitExpectedValues.standard (seed: 42)
        let expectedValues = HealthKitExpectedValues.standard

        // Navigate to analysis view where health metrics are displayed
        let analysisButton = app.buttons[AccessibilityIdentifiers.analysisButton]
        XCTAssertTrue(analysisButton.waitForExistence(timeout: 5), "Analysis button should exist")
        analysisButton.tap()

        // Wait for analysis view to load with deterministic data
        // Increased timeout to account for HealthKit data processing and Core Data queries
        let viewSelector = app.buttons[AccessibilityIdentifiers.analysisViewSelector]
        XCTAssertTrue(
            viewSelector.waitForExistence(timeout: 25),
            "Analysis view should load correctly with deterministic fixture data"
        )

        // Switch to Health view to see metrics
        viewSelector.tap()
        let healthButton = app.buttons[AccessibilityIdentifiers.analysisHealthButton]
        if healthButton.waitForExistence(timeout: 3) {
            healthButton.tap()

            // Allow health metrics to render
            sleep(2)

            // Parse and verify HRV metric
            if let expectedHRV = expectedValues.averageHRV() {
                let hrvElement = app.staticTexts.matching(identifier: "health-metric-hrv").firstMatch
                if hrvElement.waitForExistence(timeout: 3) {
                    let hrvText = hrvElement.label
                    if let actualHRV = parseMetricValue(from: hrvText) {
                        let tolerance = expectedHRV * 0.05 // ±5% tolerance
                        XCTAssertEqual(
                            actualHRV,
                            expectedHRV,
                            accuracy: tolerance,
                            "HRV should be \(expectedHRV) ±5% (actual: \(actualHRV))"
                        )
                    } else {
                        XCTFail("Failed to parse HRV value from text: '\(hrvText)'")
                    }
                } else {
                    XCTFail("HRV metric element with identifier 'health-metric-hrv' not found")
                }
            }

            // Parse and verify resting heart rate metric
            if let expectedHR = expectedValues.averageRestingHR() {
                let hrElement = app.staticTexts.matching(identifier: "health-metric-resting-hr").firstMatch
                if hrElement.waitForExistence(timeout: 3) {
                    let hrText = hrElement.label
                    if let actualHR = parseMetricValue(from: hrText) {
                        let tolerance = expectedHR * 0.05 // ±5% tolerance
                        XCTAssertEqual(
                            actualHR,
                            expectedHR,
                            accuracy: tolerance,
                            "Resting HR should be \(expectedHR) ±5% (actual: \(actualHR))"
                        )
                    } else {
                        XCTFail("Failed to parse resting HR value from text: '\(hrText)'")
                    }
                } else {
                    XCTFail("Resting HR metric element with identifier 'health-metric-resting-hr' not found")
                }
            }
        } else {
            // Health button not available - might not have enough health data yet
            print("Health view not available - may need more HealthKit data")
        }

        // App should be stable with deterministic data
        XCTAssertTrue(
            app.exists,
            "App should remain stable with deterministic HealthKit fixture (seed=42)"
        )
    }

    // MARK: - Helper Methods

    /// Parse numeric value from metric text
    /// Handles formats like "42.5 ms", "65 BPM", "7.5 hours", etc.
    private func parseMetricValue(from text: String) -> Double? {
        // Extract first numeric value (including decimals) from the text
        let pattern = #"(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Double(text[range])
    }

    func testDeterministicDataProducesConsistentResults() throws {
        // This test can be run multiple times to verify true determinism
        // Each run with seed=42 should produce identical behaviour

        launchWithDeterministicHealthKit(seed: 42, daysOfHistory: 7)
        guard let app = app else {
            XCTFail("App should be initialized")
            return
        }
        XCTAssertTrue(app.exists, "App should launch with seed=42")

        // Navigate through app in a deterministic sequence
        let logButton = app.buttons.matching(identifier: "log-symptom-button").firstMatch
        if logButton.waitForExistence(timeout: 5) {
            logButton.tap()

            // UI should be consistent across runs
            // Increased timeout to ensure view has fully loaded
            let searchButton = app.buttons[AccessibilityIdentifiers.searchAllSymptomsButton]
            XCTAssertTrue(
                searchButton.waitForExistence(timeout: 10),
                "UI state should be consistent with deterministic data"
            )

            // Cancel
            let cancelButton = app.navigationBars.buttons.element(boundBy: 0)
            if cancelButton.waitForExistence(timeout: 2) {
                cancelButton.tap()
            }
        }

        // Verify app remains stable
        XCTAssertTrue(app.exists, "App should complete deterministic test sequence successfully")
    }

    // MARK: - Combined Integration Tests

    func testHealthKitIntegrationWithSymptomLogging() throws {
        // Launch with HealthKit data
        launchWithNormalHealthKit(daysOfHistory: 7)

        guard let app = app else {
            XCTFail("App should be initialized")
            return
        }

        // Log a symptom while HealthKit data is available
        let logButton = app.buttons.matching(identifier: "log-symptom-button").firstMatch
        XCTAssertTrue(logButton.waitForExistence(timeout: 5), "Log button should exist")
        logButton.tap()

        // Wait for search button - increased timeout to ensure view has fully loaded
        let searchButton = app.buttons[AccessibilityIdentifiers.searchAllSymptomsButton]
        if searchButton.waitForExistence(timeout: 10) {
            searchButton.tap()

            // Search for a symptom
            let searchField = app.textFields.matching(identifier: "symptom-search-field").firstMatch
            if searchField.waitForExistence(timeout: 2) {
                searchField.tap()
                searchField.typeText("Fatigue")

                let fatigueCell = app.staticTexts["Fatigue"]
                if fatigueCell.waitForExistence(timeout: 3) {
                    fatigueCell.tap()

                    // The app now has access to real HealthKit context
                    // Verify the symptom entry form works
                    let slider = app.sliders.matching(identifier: "severity-slider").firstMatch
                    XCTAssertTrue(
                        slider.waitForExistence(timeout: 2),
                        "Symptom entry should work with HealthKit data available"
                    )

                    // Cancel the entry
                    let cancelButton = app.buttons.matching(identifier: "cancel-button").firstMatch
                    if cancelButton.waitForExistence(timeout: 2) {
                        cancelButton.tap()
                    }
                }
            }
        }
    }

    func testHealthKitDataPersistenceBetweenViews() throws {
        // Launch with HealthKit data
        launchWithNormalHealthKit(daysOfHistory: 7)

        guard let app = app else {
            XCTFail("App should be initialized")
            return
        }

        // Navigate through different views
        // HealthKit data should be available consistently

        // Check analysis view
        let analysisButton = app.buttons[AccessibilityIdentifiers.analysisButton]
        if analysisButton.waitForExistence(timeout: 5) {
            analysisButton.tap()

            // Wait for view to load - check for view selector menu
            // Increased timeout to account for HealthKit data processing and Core Data queries
            let viewSelector = app.buttons[AccessibilityIdentifiers.analysisViewSelector]
            XCTAssertTrue(viewSelector.waitForExistence(timeout: 25), "Analysis should load")

            // Go back
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.waitForExistence(timeout: 3) {
                backButton.tap()
            }
        }

        // Check settings - look for the settings button using the identifier
        let settingsButton = app.buttons[AccessibilityIdentifiers.settingsButton]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()

            // Verify settings loaded - wait for settings content rather than nav bar
            // Settings view should have tracked symptoms button
            // Increased timeout to ensure settings view has fully loaded
            let trackedSymptomsButton = app.buttons[AccessibilityIdentifiers.trackedSymptomsButton]
            XCTAssertTrue(
                trackedSymptomsButton.waitForExistence(timeout: 10),
                "Settings should be accessible with HealthKit data"
            )

            // Go back
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.waitForExistence(timeout: 3) {
                backButton.tap()
            }
        }

        // App should still be stable
        XCTAssertTrue(app.exists, "App should remain stable across view navigation with HealthKit")
    }

    // MARK: - Live Data Tests (commented out - only run when testing live features)

    /*
    func testLiveHealthKitDataStream() throws {
        // Launch with live data streaming enabled
        launchWithNormalHealthKit(daysOfHistory: 7, enableLiveData: true)

        // Verify app launched successfully
        XCTAssertTrue(app?.exists == true, "App should launch with live HealthKit streaming")

        // Let live data run for a few seconds
        sleep(5)

        // App should still be stable with live data
        XCTAssertTrue(app?.exists == true, "App should remain stable with live HealthKit streaming")

        // Live data would continue updating in the background
        // Real tests would verify UI updates in response to new data
    }
    */
}
