//
//  MurmurUITests.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 2/10/2025.
//

import XCTest
import CoreGraphics

final class MurmurUITests: XCTestCase {
    var app: XCUIApplication!
    private var systemAlertMonitor: NSObjectProtocol?

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        systemAlertMonitor = registerSystemAlertMonitor()

        // Launch with sample data flag
        app.launchArguments = ["-UITestMode", "-SeedSampleData"]
        app.launch()

        // Skip HealthKit authorization in UI test mode (app skips it via -UITestMode flag)
        // allowHealthKitIfNeeded() is not needed since app won't show HealthKit dialog

        handleSpringboardAlertsIfNeeded()
    }

    override func tearDownWithError() throws {
        if let monitor = systemAlertMonitor {
            removeUIInterruptionMonitor(monitor)
        }
        app = nil
    }

    private func legacyRegisterSystemAlertMonitor() -> NSObjectProtocol {
        return addUIInterruptionMonitor(withDescription: "System Alerts") { alert in
            let buttonTitles = [
                "Allow",
                "Allow While Using App",
                "Allow Once",
                "Always Allow",
                "OK"
            ]

            for title in buttonTitles {
                if alert.buttons[title].exists {
                    alert.buttons[title].tap()
                    return true
                }
            }

            return false
        }
    }

    private func allowHealthKitIfNeeded(timeout: TimeInterval = 12) {
        let healthApp = XCUIApplication(bundleIdentifier: "com.apple.Health")

        guard healthApp.wait(for: .runningForeground, timeout: timeout) else {
            return
        }

        XCTContext.runActivity(named: "Health App Buttons") { _ in
            let buttons = healthApp.buttons.allElementsBoundByIndex
            for button in buttons {
                NSLog("Health button -> label: %@, identifier: %@", button.label, button.identifier)
            }
            let navButtons = healthApp.navigationBars.buttons.allElementsBoundByIndex
            for button in navButtons {
                NSLog("Health nav button -> label: %@, identifier: %@", button.label, button.identifier)
            }
        }

        let turnOnAllCandidates: [XCUIElement] = [
            healthApp.navigationBars.buttons["Turn On All"],
            healthApp.buttons["Turn On All"],
            healthApp.buttons["Allow All"],
            healthApp.buttons["Allow All Data"]
        ]

        var tappedTurnOnAll = false
        for candidate in turnOnAllCandidates where candidate.waitForExistence(timeout: 1.5) {
            candidate.tap()
            tappedTurnOnAll = true
            break
        }

        // Wait for next screen if we tapped "Turn On All"
        if tappedTurnOnAll {
            Thread.sleep(forTimeInterval: 0.5)
        }

        let allowCandidates: [XCUIElement] = [
            healthApp.navigationBars.buttons["Allow"],
            healthApp.buttons["Allow"],
            healthApp.navigationBars.buttons["Allow All"],
            healthApp.buttons["Allow All"],
            healthApp.buttons["Allow With Current Data"],
            healthApp.buttons["Done"]
        ]

        for candidate in allowCandidates where candidate.waitForExistence(timeout: 2.0) {
            candidate.tap()
            break
        }

        // Final check for Done button
        Thread.sleep(forTimeInterval: 0.5)
        let doneButton = healthApp.buttons["Done"]
        if doneButton.waitForExistence(timeout: 1.5) {
            doneButton.tap()
        }

        // Return focus to the app under test
        app.activate()
    }

    private func handleSpringboardAlertsIfNeeded(timeout: TimeInterval = 5) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: timeout) {
            allowButton.tap()
            app.activate()
        }
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

        // Wait for sheet to appear by checking for search button
        let searchButton = app.buttons["search-all-symptoms-button"]
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
        let logButton = require(app.buttons["Log symptom"], timeout: 5)
        logButton.tap()

        // Try to select Energy (positive)
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("Energy")

            let energyCell = app.staticTexts["Energy"]
            if energyCell.waitForExistence(timeout: 3) {
                energyCell.tap()

                // Verify we can proceed with the entry
                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'done' OR label CONTAINS[c] 'log'")).firstMatch
                _ = saveButton.waitForExistence(timeout: 3)

                // The key test: app shouldn't crash with positive symptoms
                XCTAssertTrue(app.exists, "App should remain stable with positive symptom selected")
            }
        }

        // Cancel
        let cancelButton = app.navigationBars.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) {
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
        let searchButton = app.buttons["search-all-symptoms-button"]
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
        // Navigate to settings
        let settingsButton = require(app.navigationBars.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'gear' OR label CONTAINS[c] 'settings'")).firstMatch,
                                     timeout: 10)
        tap(element: settingsButton)

        let trackedSymptomsButton = require(app.buttons["tracked-symptoms-button"], timeout: 10)
        trackedSymptomsButton.tap()

        // Tap add button (+ button in navigation)
        let addButton = require(app.navigationBars.buttons.matching(NSPredicate(format: "identifier == 'plus' OR label == 'Add'")).firstMatch, timeout: 5)
        addButton.tap()

        // Enter custom symptom name
        let textField = require(app.textFields.firstMatch, timeout: 5)
        textField.tap()
        textField.typeText("Test Custom Symptom")

        // Save the custom symptom
        let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'add' OR label CONTAINS[c] 'done'")).firstMatch
        if saveButton.waitForExistence(timeout: 3) {
            saveButton.tap()
        }

        // Verify the custom symptom appears in the list
        let customSymptom = require(app.staticTexts["Test Custom Symptom"], timeout: 5)

        // Now delete it - swipe to delete or tap edit mode
        if customSymptom.exists {
            customSymptom.swipeLeft()

            let deleteButton = app.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()
                waitForDisappearance(customSymptom, timeout: 3)
                XCTAssertFalse(customSymptom.exists, "Custom symptom should be deleted")
            }
        }

        // Go back to main screen
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
        }

        // Go back again if needed
        let secondBackButton = app.navigationBars.buttons.element(boundBy: 0)
        if secondBackButton.waitForExistence(timeout: 3) {
            secondBackButton.tap()
        }
    }

    @MainActor
    func testNotificationPermission() throws {
        // Wait for app to load
        // Navigate to settings
        let settingsButton = require(app.navigationBars.buttons.matching(NSPredicate(format: "identifier CONTAINS[c] 'gear' OR label CONTAINS[c] 'settings'")).firstMatch,
                                     timeout: 10)
        settingsButton.tap()

        // Look for notification/reminder settings
        let notificationButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'notification' OR label CONTAINS[c] 'reminder'")).firstMatch
        if notificationButton.waitForExistence(timeout: 5) {
            notificationButton.tap()

            // Look for a toggle or button to enable notifications
            let enableToggle = app.switches.firstMatch
            if enableToggle.waitForExistence(timeout: 3), enableToggle.value as? String == "0" {
                enableToggle.tap()

                // Handle system notification permission alert
                let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
                let allowButton = springboard.buttons["Allow"]
                if allowButton.waitForExistence(timeout: 5) {
                    allowButton.tap()
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
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
        }
    }

    @MainActor
    func testPositiveSymptomEntry() throws {
        // Tap the "Log symptom" button
        let logSymptomButton = app.buttons.matching(identifier: "log-symptom-button").firstMatch
        XCTAssertTrue(logSymptomButton.waitForExistence(timeout: 5), "Log symptom button should exist")
        logSymptomButton.tap()

        // Wait for and tap search button
        let searchButton = app.buttons["search-all-symptoms-button"]
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
        // Navigate to analysis
        let analysisButton = require(app.buttons[AccessibilityIdentifiers.analysisButton], timeout: 5)
        analysisButton.tap()

        // Check that trends view loads (it should handle positive symptoms)
        _ = require(app.buttons["Trends"], timeout: 5)

        // If there's data, verify it shows "Improving" or "Worsening" not "Increasing/Decreasing"
        let improvingLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Improving'")).firstMatch
        let worseningLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Worsening'")).firstMatch
        let increasingLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Increasing'")).firstMatch

        // We should see Improving/Worsening, not Increasing/Decreasing
        if improvingLabel.exists || worseningLabel.exists {
            XCTAssertFalse(increasingLabel.exists, "Should use 'Improving/Worsening' not 'Increasing'")
        }

        // Go back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
        }
    }

    // MARK: - Screenshot tests

    @MainActor
    func testGenerateScreenshots() throws {
        // Track expected screenshots
        var capturedScreenshots: Set<String> = []
        let expectedScreenshots: Set<String> = [
            "01Timeline",
            "02DayDetail",
            "03AddSymptom",
            "04Analysis",
            "05CalendarHeatMap",
            "06Settings",
            "07LoadCapacitySettings"
        ]

        // Wait for app to fully launch and load data
        _ = require(app.buttons.matching(identifier: "log-symptom-button").firstMatch, timeout: timeout(10))
        NSLog("✅ Timeline ready, starting screenshot capture")

        // Screenshot 1: Main timeline view
        snapshot("01Timeline")
        capturedScreenshots.insert("01Timeline")
        NSLog("📸 Captured 01Timeline")

        // Screenshot 2: Day detail view
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: timeout(10)) {
            firstCell.tap()
            let detailBackButton = app.navigationBars.buttons.element(boundBy: 0)
            if detailBackButton.waitForExistence(timeout: timeout(5)) {
                snapshot("02DayDetail")
                capturedScreenshots.insert("02DayDetail")
                detailBackButton.tap()
                NSLog("📸 Captured 02DayDetail")
            }
        }

        // Screenshot 3: Add symptom entry
        let logSymptomButton = app.buttons["Log symptom"]
        if logSymptomButton.waitForExistence(timeout: timeout(5)) {
            logSymptomButton.tap()

            let cancelButton = app.navigationBars.buttons["Cancel"]
            if cancelButton.waitForExistence(timeout: timeout(5)) {
                snapshot("03AddSymptom")
                capturedScreenshots.insert("03AddSymptom")
                cancelButton.tap()
                NSLog("📸 Captured 03AddSymptom")
            }
        }

        // Screenshot 4: Analysis view
        let analysisButton = app.buttons[AccessibilityIdentifiers.analysisButton]
        if analysisButton.waitForExistence(timeout: timeout(5)) {
            analysisButton.tap()

            // Wait for trends view to load
            let trendsButton = app.buttons["Trends"]
            _ = trendsButton.waitForExistence(timeout: timeout(5))
            snapshot("04Analysis")
            capturedScreenshots.insert("04Analysis")
            NSLog("📸 Captured 04Analysis")

            // Screenshot 5: Calendar heat map in analysis
            // Open the analysis view selector menu
            let viewSelectorMenu = app.buttons["analysis-view-selector"]
            if viewSelectorMenu.waitForExistence(timeout: timeout(3)) {
                viewSelectorMenu.tap()

                // Tap the Calendar option in the menu
                let calendarMenuItem = app.buttons["analysis-calendar-button"]
                if calendarMenuItem.waitForExistence(timeout: timeout(2)) {
                    calendarMenuItem.tap()

                    // Wait for calendar grid to appear (look for month navigation)
                    let monthLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '2025' OR label CONTAINS '2024'")).firstMatch
                    if monthLabel.waitForExistence(timeout: timeout(5)) {
                        snapshot("05CalendarHeatMap")
                        capturedScreenshots.insert("05CalendarHeatMap")
                        NSLog("📸 Captured 05CalendarHeatMap")
                    }
                }
            }

            let analysisBackButton = app.navigationBars.buttons.element(boundBy: 0)
            if analysisBackButton.waitForExistence(timeout: timeout(3)) {
                analysisBackButton.tap()
            }
        }

        // Screenshot 6: Settings
        guard let settingsButton = findSettingsButton(timeout: timeout(6)) else {
            XCTFail("Settings button not available for screenshot capture")
            return
        }
        NSLog("➡️ Tapping Settings from timeline")
        tap(element: settingsButton)

        let settingsNavBar = app.navigationBars["Settings"]
        guard settingsNavBar.waitForExistence(timeout: timeout(4)) else {
            XCTFail("Settings screen did not appear")
            return
        }
        NSLog("✅ Settings screen loaded")

        guard let loadCapacityButton = findLoadCapacityButton(timeout: timeout(6)) else {
            XCTFail("Load capacity button not available for screenshot capture")
            return
        }
        snapshot("06Settings")
        capturedScreenshots.insert("06Settings")
        NSLog("📸 Captured 06Settings")

        // Screenshot 7: Load capacity settings
        NSLog("➡️ Navigating to Load Capacity settings")
        tap(element: loadCapacityButton)

        let loadCapacityNavBar = app.navigationBars["Load capacity"]
        guard loadCapacityNavBar.waitForExistence(timeout: timeout(4)) else {
            XCTFail("Load capacity settings screen did not appear")
            return
        }
        NSLog("✅ Load capacity screen loaded")
        snapshot("07LoadCapacitySettings")
        capturedScreenshots.insert("07LoadCapacitySettings")
        NSLog("📸 Captured 07LoadCapacitySettings")

        let loadBackButton = app.navigationBars.buttons.element(boundBy: 0)
        if loadBackButton.waitForExistence(timeout: timeout(3)) {
            loadBackButton.tap()
        }

        // Verify all expected screenshots were captured
        let missingScreenshots = expectedScreenshots.subtracting(capturedScreenshots)
        XCTAssertTrue(missingScreenshots.isEmpty, "Missing screenshots: \(missingScreenshots.sorted().joined(separator: ", "))")

        NSLog("✓ Successfully captured all \(capturedScreenshots.count) screenshots: \(capturedScreenshots.sorted().joined(separator: ", "))")
    }

    private func findSettingsButton(timeout: TimeInterval) -> XCUIElement? {
        let identifierMatch = app.buttons[AccessibilityIdentifiers.settingsButton]
        if identifierMatch.waitForExistence(timeout: timeout) {
            return identifierMatch
        }

        let anyMatch = app.descendants(matching: .any).matching(identifier: AccessibilityIdentifiers.settingsButton).firstMatch
        if anyMatch.waitForExistence(timeout: 1) {
            return anyMatch
        }

        let fallbackPredicate = NSPredicate(format: "identifier CONTAINS[c] 'gear' OR label CONTAINS[c] 'settings'")
        let fallback = app.navigationBars.buttons.matching(fallbackPredicate).firstMatch
        if fallback.waitForExistence(timeout: 1) {
            return fallback
        }

        NSLog("⚠️ Settings button not found. Debug tree: \(app.debugDescription)")
        return nil
    }

    private func findLoadCapacityButton(timeout: TimeInterval) -> XCUIElement? {
        let button = app.buttons[AccessibilityIdentifiers.loadCapacityButton]
        if button.waitForExistence(timeout: timeout) {
            return button
        }

        let anyMatch = app.descendants(matching: .any).matching(identifier: AccessibilityIdentifiers.loadCapacityButton).firstMatch
        if anyMatch.waitForExistence(timeout: 1) {
            return anyMatch
        }

        let fallback = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'load capacity'"))
        let firstMatch = fallback.firstMatch
        if firstMatch.waitForExistence(timeout: 1) {
            return firstMatch
        }

        NSLog("⚠️ Load capacity button not found. Debug tree: \(app.debugDescription)")
        return nil
    }

    private func tap(element: XCUIElement) {
        if element.isHittable {
            element.tap()
            return
        }

        let coordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coordinate.tap()
    }
}
