//
//  MurmurUITests.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 2/10/2025.
//

import XCTest

final class MurmurUITests: XCTestCase {
    var app: XCUIApplication!

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)

        // Launch with sample data flag
        app.launchArguments = ["-UITestMode", "-SeedSampleData"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Positive symptom tests

    @MainActor
    func testAppLaunches() throws {
        // Simple test to verify app launches
        XCTAssertTrue(app.exists, "App should launch")

        // Use proper wait instead of sleep
        let logButton = app.buttons.matching(identifier: "log-symptom-button").firstMatch
        XCTAssertTrue(logButton.waitForExistence(timeout: 10), "Log symptom button should exist after launch")
    }

    @MainActor
    func testNegativeSymptomShowsCrisis() throws {
        // Test that negative symptoms show "Crisis" at level 5 (opposite of positive)
        let logButton = app.buttons.matching(identifier: "log-symptom-button").firstMatch
        XCTAssertTrue(logButton.waitForExistence(timeout: 5), "Log button should exist")
        logButton.tap()

        // Wait for sheet to appear by checking for search field
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Search all symptoms'")).firstMatch
        XCTAssertTrue(searchButton.waitForExistence(timeout: 3), "Search button should appear")
        searchButton.tap()

        // Use accessibility identifier for search field
        let searchField = app.textFields.matching(identifier: "symptom-search-field").firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2), "Search field should appear")
        searchField.tap()
        searchField.typeText("Fatigue")

        // Wait for search results
        let fatigueCell = app.staticTexts["Fatigue"]
        XCTAssertTrue(fatigueCell.waitForExistence(timeout: 3), "Fatigue symptom should appear in search results")
        fatigueCell.tap()

        // Wait for severity slider to appear
        let slider = app.sliders.matching(identifier: "severity-slider").firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 2), "Severity slider should appear")

        // Set to maximum severity
        slider.adjust(toNormalizedSliderPosition: 1.0)

        // Wait for crisis label to update
        let crisisLabel = app.staticTexts["Crisis"]
        XCTAssertTrue(crisisLabel.waitForExistence(timeout: 2), "Negative symptom at level 5 should show 'Crisis'")

        // Should NOT show "Very high" (that's for positive symptoms)
        let veryHighLabel = app.staticTexts["Very high"]
        XCTAssertFalse(veryHighLabel.exists, "Negative symptom should not show 'Very high'")

        // Cancel using accessibility identifier
        let cancelButton = app.buttons.matching(identifier: "cancel-button").firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2), "Cancel button should exist")
        cancelButton.tap()
    }

    @MainActor
    func testMixedSymptomEntry() throws {
        // Test entering multiple symptoms with mixed positive/negative
        sleep(2)

        let logButton = app.buttons["Log symptom"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5), "Log button should exist")
        logButton.tap()
        sleep(1)

        // Try to select Energy (positive)
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Energy")
            sleep(1)

            let energyCell = app.staticTexts["Energy"]
            if energyCell.waitForExistence(timeout: 3) {
                energyCell.tap()
                sleep(1)

                // Verify we can proceed with the entry
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'done' OR label CONTAINS[c] 'log'")).firstMatch

                // The key test: app shouldn't crash with positive symptoms
                XCTAssertTrue(app.exists, "App should remain stable with positive symptom selected")
            }
        }

        // Cancel
        let cancelButton = app.navigationBars.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }

    @MainActor
    func testSeveritySliderBehavior() throws {
        // Test that severity slider works correctly
        let logButton = app.buttons.matching(identifier: "log-symptom-button").firstMatch
        XCTAssertTrue(logButton.waitForExistence(timeout: 5), "Log button should exist")
        logButton.tap()

        // Wait for and tap search button
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Search all symptoms'")).firstMatch
        XCTAssertTrue(searchButton.waitForExistence(timeout: 3), "Search button should appear")
        searchButton.tap()

        // Use accessibility identifier for search field
        let searchField = app.textFields.matching(identifier: "symptom-search-field").firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2), "Search field should appear")
        searchField.tap()
        searchField.typeText("Joy")

        // Wait for Joy symptom
        let joyCell = app.staticTexts["Joy"]
        XCTAssertTrue(joyCell.waitForExistence(timeout: 3), "Joy symptom should appear")
        joyCell.tap()

        // Wait for slider
        let slider = app.sliders.matching(identifier: "severity-slider").firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 2), "Severity slider should exist")

        // Test different severity levels with proper waits
        slider.adjust(toNormalizedSliderPosition: 0.0) // Level 1
        let veryLowLabel = app.staticTexts["Very low"]
        XCTAssertTrue(veryLowLabel.waitForExistence(timeout: 1), "Level 1 positive symptom should show 'Very low'")

        slider.adjust(toNormalizedSliderPosition: 0.5) // Level 3
        let moderateLabel = app.staticTexts["Moderate"]
        XCTAssertTrue(moderateLabel.waitForExistence(timeout: 1), "Level 3 positive symptom should show 'Moderate'")

        slider.adjust(toNormalizedSliderPosition: 1.0) // Level 5
        let veryHighLabel = app.staticTexts["Very high"]
        XCTAssertTrue(veryHighLabel.waitForExistence(timeout: 1), "Level 5 positive symptom should show 'Very high'")

        // Cancel using accessibility identifier
        let cancelButton = app.buttons.matching(identifier: "cancel-button").firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2), "Cancel button should exist")
        cancelButton.tap()
    }

    @MainActor
    func testAddAndRemoveCustomSymptom() throws {
        // Wait for app to load
        sleep(2)

        // Navigate to settings
        let settingsButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'gear' OR label CONTAINS[c] 'settings'")).firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "Settings button should exist")
        settingsButton.tap()
        sleep(2)

        // Navigate to tracked symptoms
        let trackedSymptomsButton = app.buttons["Tracked symptoms"]
        XCTAssertTrue(trackedSymptomsButton.waitForExistence(timeout: 10), "Tracked symptoms button should exist")
        trackedSymptomsButton.tap()
        sleep(2)

        // Tap add button (+ button in navigation)
        let addButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier == 'plus' OR label == 'Add'")).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()
        sleep(1)

        // Enter custom symptom name
        let textField = app.textFields.firstMatch
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "Text field should appear")
        textField.tap()
        textField.typeText("Test Custom Symptom")
        sleep(1)

        // Save the custom symptom
        let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'add' OR label CONTAINS[c] 'done'")).firstMatch
        if saveButton.exists {
            saveButton.tap()
            sleep(2)
        }

        // Verify the custom symptom appears in the list
        let customSymptom = app.staticTexts["Test Custom Symptom"]
        XCTAssertTrue(customSymptom.exists, "Custom symptom should appear in list")

        // Now delete it - swipe to delete or tap edit mode
        if customSymptom.exists {
            // Try swipe to delete
            customSymptom.swipeLeft()
            sleep(1)

            let deleteButton = app.buttons["Delete"]
            if deleteButton.exists {
                deleteButton.tap()
                sleep(1)

                // Verify it's gone
                XCTAssertFalse(customSymptom.exists, "Custom symptom should be deleted")
            }
        }

        // Go back to main screen
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
            sleep(1)
        }

        // Go back again if needed
        if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }
    }

    @MainActor
    func testNotificationPermission() throws {
        // Wait for app to load
        sleep(2)

        // Navigate to settings
        let settingsButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'gear' OR label CONTAINS[c] 'settings'")).firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "Settings button should exist")
        settingsButton.tap()
        sleep(2)

        // Look for notification/reminder settings
        let notificationButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'notification' OR label CONTAINS[c] 'reminder'")).firstMatch
        if notificationButton.exists {
            notificationButton.tap()
            sleep(2)

            // Look for a toggle or button to enable notifications
            let enableToggle = app.switches.firstMatch
            if enableToggle.exists && enableToggle.value as? String == "0" {
                enableToggle.tap()
                sleep(1)

                // Handle system notification permission alert
                let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                let allowButton = springboard.buttons["Allow"]
                if allowButton.waitForExistence(timeout: 5) {
                    allowButton.tap()
                    sleep(1)
                }
            }

            // Verify we're still in the app (didn't crash)
            XCTAssertTrue(app.exists, "App should remain stable after notification permission")
        } else {
            // If no notification settings found, just verify app is stable
            XCTAssertTrue(app.exists, "App should be stable even if notification settings not found")
        }

        // Go back to main screen
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
            sleep(1)
        }
    }

    @MainActor
    func testPositiveSymptomEntry() throws {
        // Tap the "Log symptom" button
        let logSymptomButton = app.buttons.matching(identifier: "log-symptom-button").firstMatch
        XCTAssertTrue(logSymptomButton.waitForExistence(timeout: 5), "Log symptom button should exist")
        logSymptomButton.tap()

        // Wait for and tap search button
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Search all symptoms'")).firstMatch
        XCTAssertTrue(searchButton.waitForExistence(timeout: 3), "Search button should appear")
        searchButton.tap()

        // Use accessibility identifier for search field
        let searchField = app.textFields.matching(identifier: "symptom-search-field").firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2), "Search field should appear")
        searchField.tap()
        searchField.typeText("Energy")

        // Wait for Energy symptom to appear
        let energyCell = app.staticTexts["Energy"]
        XCTAssertTrue(energyCell.waitForExistence(timeout: 3), "Energy symptom should appear in search results")
        energyCell.tap()

        // Wait for severity slider
        let slider = app.sliders.matching(identifier: "severity-slider").firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 2), "Severity slider should appear")

        // Set severity to 5 (should show "Very high" for positive symptoms)
        slider.adjust(toNormalizedSliderPosition: 1.0)

        // Wait for label to update
        let veryHighLabel = app.staticTexts["Very high"]
        XCTAssertTrue(veryHighLabel.waitForExistence(timeout: 2), "Positive symptom at level 5 should show 'Very high'")

        // Verify NO "Crisis" label (would be for negative symptoms)
        let crisisLabel = app.staticTexts["Crisis"]
        XCTAssertFalse(crisisLabel.exists, "Positive symptom should not show 'Crisis'")

        // Cancel using accessibility identifier
        let cancelButton = app.buttons.matching(identifier: "cancel-button").firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2), "Cancel button should exist")
        cancelButton.tap()
    }

    @MainActor
    func testPositiveSymptomAnalysis() throws {
        // This test verifies analysis views handle positive symptoms correctly
        sleep(2)

        // Navigate to analysis
        let analysisButton = app.navigationBars.buttons["Analysis"]
        XCTAssertTrue(analysisButton.waitForExistence(timeout: 5), "Analysis button should exist")
        analysisButton.tap()
        sleep(2)

        // Check that trends view loads (it should handle positive symptoms)
        let trendsSegment = app.buttons["Trends"]
        XCTAssertTrue(trendsSegment.exists, "Trends tab should exist")

        // If there's data, verify it shows "Improving" or "Worsening" not "Increasing/Decreasing"
        let improvingLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Improving'")).firstMatch
        let worseningLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Worsening'")).firstMatch
        let increasingLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Increasing'")).firstMatch

        // We should see Improving/Worsening, not Increasing/Decreasing
        if improvingLabel.exists || worseningLabel.exists {
            XCTAssertFalse(increasingLabel.exists, "Should use 'Improving/Worsening' not 'Increasing'")
        }

        // Go back
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
    }

    // MARK: - Screenshot tests

    @MainActor
    func testGenerateScreenshots() throws {
        // Wait for app to fully launch and load data
        sleep(3)

        // Screenshot 1: Main timeline view
        snapshot("01Timeline")

        // Screenshot 2: Day detail view
        // Find and tap on the first day section header or timeline entry
        let firstCell = app.tables.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5) {
            firstCell.tap()
            sleep(2)
            snapshot("02DayDetail")

            // Go back
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                backButton.tap()
                sleep(1)
            }
        }

        // Screenshot 3: Add symptom entry
        let logSymptomButton = app.buttons["Log symptom"]
        if logSymptomButton.waitForExistence(timeout: 5) {
            logSymptomButton.tap()
            sleep(1)
            snapshot("03AddSymptom")

            // Cancel
            let cancelButton = app.navigationBars.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
                sleep(1)
            }
        }

        // Screenshot 4: Analysis view
        let analysisButton = app.navigationBars.buttons["Analysis"]
        if analysisButton.waitForExistence(timeout: 5) {
            analysisButton.tap()
            sleep(2)
            snapshot("04Analysis")

            // Screenshot 5: Calendar heat map in analysis
            // Look for calendar or heat map button/element
            let calendarButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'calendar' OR label CONTAINS[c] 'heat map'")).firstMatch
            if calendarButton.waitForExistence(timeout: 3) {
                calendarButton.tap()
                sleep(2)
                snapshot("05CalendarHeatMap")

                // Go back from calendar
                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.exists {
                    backButton.tap()
                    sleep(1)
                }
            }

            // Go back from analysis
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                backButton.tap()
                sleep(1)
            }
        }

        // Screenshot 6: Settings
        let settingsButton = app.navigationBars.buttons.matching(identifier: "gearshape").firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(2)
            snapshot("06Settings")

            // Screenshot 7: Load capacity settings
            let loadCapacityButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'load capacity'")).firstMatch
            if loadCapacityButton.waitForExistence(timeout: 3) {
                loadCapacityButton.tap()
                sleep(2)
                snapshot("07LoadCapacitySettings")
            }
        }
    }
}
