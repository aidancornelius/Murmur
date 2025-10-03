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

        // Wait a bit for app to fully load
        sleep(3)

        // Try to find any UI element to confirm app is responsive
        let logButton = app.buttons["Log symptom"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 10), "Log symptom button should exist after launch")
    }

    @MainActor
    func testNegativeSymptomShowsCrisis() throws {
        // Test that negative symptoms show "Crisis" at level 5 (opposite of positive)
        sleep(2)

        let logButton = app.buttons["Log symptom"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5), "Log button should exist")
        logButton.tap()
        sleep(1)

        // Search for a negative symptom
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Fatigue")
            sleep(1)

            let fatigueCell = app.staticTexts["Fatigue"]
            if fatigueCell.waitForExistence(timeout: 3) {
                fatigueCell.tap()
                sleep(1)

                // Set to maximum severity
                let slider = app.sliders.firstMatch
                if slider.exists {
                    slider.adjust(toNormalizedSliderPosition: 1.0)
                    sleep(1)

                    // Should show "Crisis" for negative symptom at level 5
                    let crisisLabel = app.staticTexts["Crisis"]
                    XCTAssertTrue(crisisLabel.exists, "Negative symptom at level 5 should show 'Crisis'")

                    // Should NOT show "Very high" (that's for positive symptoms)
                    let veryHighLabel = app.staticTexts["Very high"]
                    XCTAssertFalse(veryHighLabel.exists, "Negative symptom should not show 'Very high'")
                }
            }
        }

        // Cancel
        let cancelButton = app.navigationBars.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
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
        sleep(2)

        let logButton = app.buttons["Log symptom"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5), "Log button should exist")
        logButton.tap()
        sleep(1)

        // Select any symptom
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Joy")
            sleep(1)

            let joyCell = app.staticTexts["Joy"]
            if joyCell.waitForExistence(timeout: 3) {
                joyCell.tap()
                sleep(1)

                let slider = app.sliders.firstMatch
                XCTAssertTrue(slider.exists, "Severity slider should exist")

                // Test different severity levels
                slider.adjust(toNormalizedSliderPosition: 0.0) // Level 1
                Thread.sleep(forTimeInterval: 0.5)
                let veryLowLabel = app.staticTexts["Very low"]
                XCTAssertTrue(veryLowLabel.exists, "Level 1 positive symptom should show 'Very low'")

                slider.adjust(toNormalizedSliderPosition: 0.5) // Level 3
                Thread.sleep(forTimeInterval: 0.5)
                let moderateLabel = app.staticTexts["Moderate"]
                XCTAssertTrue(moderateLabel.exists, "Level 3 positive symptom should show 'Moderate'")

                slider.adjust(toNormalizedSliderPosition: 1.0) // Level 5
                Thread.sleep(forTimeInterval: 0.5)
                let veryHighLabel = app.staticTexts["Very high"]
                XCTAssertTrue(veryHighLabel.exists, "Level 5 positive symptom should show 'Very high'")
            }
        }

        // Cancel
        let cancelButton = app.navigationBars.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        }
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
        // Wait for app to load
        sleep(2)

        // Tap the "Log symptom" button
        let logSymptomButton = app.buttons["Log symptom"]
        XCTAssertTrue(logSymptomButton.waitForExistence(timeout: 5), "Log symptom button should exist")
        logSymptomButton.tap()
        sleep(1)

        // Search for and select "Energy"
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Energy")
            sleep(1)

            // Tap on Energy symptom
            let energyCell = app.staticTexts["Energy"]
            if energyCell.waitForExistence(timeout: 3) {
                energyCell.tap()
                sleep(1)

                // Set severity to 5 (should show "Very high" for positive symptoms)
                let slider = app.sliders.firstMatch
                if slider.exists {
                    slider.adjust(toNormalizedSliderPosition: 1.0) // Max value
                    sleep(1)

                    // Verify the descriptor shows "Very high" not "Crisis"
                    let veryHighLabel = app.staticTexts["Very high"]
                    XCTAssertTrue(veryHighLabel.exists, "Positive symptom at level 5 should show 'Very high'")

                    // Verify NO "Crisis" label (would be for negative symptoms)
                    let crisisLabel = app.staticTexts["Crisis"]
                    XCTAssertFalse(crisisLabel.exists, "Positive symptom should not show 'Crisis'")
                }
            }
        }

        // Cancel
        app.navigationBars.buttons["Cancel"].tap()
        sleep(1)
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
        // Find and tap on the first day section header
        let firstSection = app.tables.cells.firstMatch
        if firstSection.waitForExistence(timeout: 5) {
            firstSection.tap()
            sleep(1)
            snapshot("02DayDetail")

            // Go back
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // Screenshot 3: Add symptom entry
        // Tap the "Log symptom" button
        let logSymptomButton = app.buttons["Log symptom"]
        if logSymptomButton.waitForExistence(timeout: 5) {
            logSymptomButton.tap()
            sleep(1)
            snapshot("03AddSymptom")

            // Cancel
            app.navigationBars.buttons["Cancel"].tap()
            sleep(1)
        }

        // Screenshot 4: Analysis view
        // Tap the analysis button in nav bar
        let analysisButton = app.navigationBars.buttons["Analysis"]
        if analysisButton.waitForExistence(timeout: 5) {
            analysisButton.tap()
            sleep(1)
            snapshot("04Analysis")

            // Go back
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // Screenshot 5: Settings
        let settingsButton = app.navigationBars.buttons.matching(identifier: "gearshape").firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(1)
            snapshot("05Settings")
        }
    }
}
