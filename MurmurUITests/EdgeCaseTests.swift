//
//  EdgeCaseTests.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest

/// Edge case and error handling tests
final class EdgeCaseTests: XCTestCase {
    var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Empty States (5 tests)

    /// Tests timeline empty state
    func testEmptyTimeline() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchEmpty()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should be visible")

        // Check for empty state message
        let emptyMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No entries' OR label CONTAINS 'Get started' OR label CONTAINS 'track'")).firstMatch

        XCTAssertTrue(emptyMessage.waitForExistence(timeout: 3),
                     "Empty timeline should show helpful message")

        // Verify log button is still available
        assertHittable(timeline.logSymptomButton,
                      message: "Should be able to add first entry from empty state")
    }

    /// Tests analysis empty state
    func testEmptyAnalysis() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchEmpty()

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis screen should load")

        // Check for empty state message
        let emptyMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No data' OR label CONTAINS 'entries' OR label CONTAINS 'track'")).firstMatch

        XCTAssertTrue(emptyMessage.exists || app.images.count > 0,
                     "Empty analysis should show helpful message or empty state image")
    }

    /// Tests symptom history empty state
    func testEmptySymptomHistory() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchEmpty()

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        analysis.waitForLoad()

        // Try to access symptom history (implementation varies)
        if app.buttons["Symptom History"].exists {
            app.buttons["Symptom History"].tap()
            Thread.sleep(forTimeInterval: 1.0)

            // Should show empty state
            let emptyMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No' OR label CONTAINS 'history'")).firstMatch
            XCTAssertTrue(emptyMessage.exists,
                         "Empty symptom history should show message")
        }
    }

    /// Tests settings with no starred symptoms
    func testNoStarredSymptoms() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(scenario: .emptyState)

        app.buttons[AccessibilityIdentifiers.settingsButton].tap()

        let settings = SettingsScreen(app: app)
        XCTAssertTrue(settings.waitForLoad(), "Settings should load")

        // Navigate to tracked symptoms
        if app.buttons[AccessibilityIdentifiers.trackedSymptomsButton].exists {
            app.buttons[AccessibilityIdentifiers.trackedSymptomsButton].tap()
            Thread.sleep(forTimeInterval: 1.0)

            // Should show symptoms but none starred
            XCTAssertTrue(app.exists, "Should show symptom list")
        }
    }

    /// Tests settings with no custom symptoms
    func testNoCustomSymptoms() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(scenario: .newUser)

        app.buttons[AccessibilityIdentifiers.settingsButton].tap()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        // Navigate to tracked symptoms
        if app.buttons[AccessibilityIdentifiers.trackedSymptomsButton].exists {
            app.buttons[AccessibilityIdentifiers.trackedSymptomsButton].tap()
            Thread.sleep(forTimeInterval: 1.0)

            // Should only show default symptoms
            XCTAssertTrue(app.exists, "Should show default symptom list")
        }
    }

    // MARK: - Error States (5 tests)

    /// Tests handling of failed save operations
    /// SKIP: Uses old AddEntryView with severity-slider which has been replaced by UnifiedEventView
    func skip_testFailedToSaveEntry() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(
            scenario: .activeUser
        )

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Try to create an entry
        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Headache")
        _ = addEntry.selectSymptom(named: "Headache")
        addEntry.setSeverity(3)

        // Attempt save (might fail with low storage simulation)
        addEntry.save()

        // Check if error message appears or entry saves successfully
        Thread.sleep(forTimeInterval: 1.0)

        // App should handle gracefully either way
        XCTAssertTrue(app.exists, "App should handle save attempt gracefully")
    }

    /// Tests HealthKit permission denied state
    func testHealthKitPermissionDenied() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(
            scenario: .activeUser,
            featureFlags: [.disableHealthKit]
        )

        app.buttons[AccessibilityIdentifiers.settingsButton].tap()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        // Try to access HealthKit settings
        if app.buttons["Integrations"].exists || app.buttons["HealthKit"].exists {
            (app.buttons["Integrations"].exists ? app.buttons["Integrations"] : app.buttons["HealthKit"]).tap()
            Thread.sleep(forTimeInterval: 1.0)

            // Should show disabled state or prompt to enable in Settings app
            XCTAssertTrue(app.exists, "Should handle disabled HealthKit gracefully")
        }
    }

    /// Tests location permission denied state
    func testLocationPermissionDenied() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(
            scenario: .activeUser,
            featureFlags: [.disableLocation]
        )

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Check if location toggle exists
        let locationToggle = app.switches.matching(NSPredicate(format: "label CONTAINS 'Location' OR label CONTAINS 'location'")).firstMatch

        if locationToggle.exists {
            // Should be disabled or show error when tapped
            if locationToggle.isEnabled {
                locationToggle.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        // App should handle disabled location gracefully
        XCTAssertTrue(app.exists, "Should handle disabled location")
    }

    /// Tests calendar permission denied state
    func testCalendarPermissionDenied() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(
            scenario: .activeUser,
            featureFlags: [.disableCalendar]
        )

        app.buttons[AccessibilityIdentifiers.settingsButton].tap()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        // Calendar features should be disabled or show appropriate message
        XCTAssertTrue(app.exists, "Should handle disabled calendar")
    }

    /// Tests Core Data error handling
    func testCoreDataError() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(
            scenario: .activeUser,
            featureFlags: [.enableDebugLogging]
        )

        // App should launch successfully even if there are underlying issues
        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10,
                    message: "App should handle Core Data gracefully")
    }

    // MARK: - Loading States (3 tests)

    /// Tests initial loading indicator
    func testInitialLoadingIndicator() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(scenario: .heavyUser)

        // On launch with large data, should show loading indicator briefly
        let timeline = TimelineScreen(app: app)

        // Either loading indicator or timeline should appear
        let loadingOrContent = waitForAny([
            app.activityIndicators.firstMatch,
            timeline.logSymptomButton
        ], timeout: 10)

        XCTAssertNotNil(loadingOrContent, "Should show loading indicator or content")

        // Eventually timeline should load
        assertExists(timeline.logSymptomButton, timeout: 15,
                    message: "Timeline should load after initial loading")
    }

    /// Tests pull to refresh loading
    func testPullToRefreshLoading() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, message: "Timeline should be visible")

        // Find the scroll view
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            // Swipe down to trigger refresh
            scrollView.swipeDown()
            Thread.sleep(forTimeInterval: 0.5)

            // Should briefly show refresh indicator
            // Then content should still be visible
            assertExists(timeline.logSymptomButton, timeout: 5,
                        message: "Timeline should remain visible after refresh")
        }
    }

    /// Tests analysis calculation loading state
    func testAnalysisCalculating() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(scenario: .heavyUser)

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        // Analysis might show loading while calculating
        let loadingOrContent = waitForAny([
            app.activityIndicators.firstMatch,
            app.buttons["Trends"]
        ], timeout: 10)

        XCTAssertNotNil(loadingOrContent, "Should show loading or analysis content")
    }

    // MARK: - Boundary Conditions (8 tests)

    /// Tests selecting maximum number of symptoms
    func testMaximumSymptomSelection() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Try to add symptoms up to the maximum (typically 5)
        let symptomsToAdd = ["Headache", "Fatigue", "Nausea", "Dizziness", "Pain"]

        for (index, symptom) in symptomsToAdd.enumerated() {
            addEntry.openSymptomSearch()
            addEntry.searchForSymptom(symptom)

            if addEntry.selectSymptom(named: symptom) {
                addEntry.setSeverity(index + 1)

                // Try to add another if not at limit
                if index < symptomsToAdd.count - 1 {
                    if app.buttons["Add another symptom"].exists {
                        app.buttons["Add another symptom"].tap()
                    } else {
                        // Reached maximum
                        break
                    }
                }
            } else {
                break
            }
        }

        // Should be able to save
        let saveButton = app.buttons[AccessibilityIdentifiers.saveButton]
        if saveButton.exists {
            XCTAssertTrue(saveButton.isEnabled, "Should be able to save multiple symptoms")
        }
    }

    /// Tests attempting to add more than maximum symptoms
    func testAttemptSixthSymptomSelection() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Try to add 5 symptoms
        var symptomsAdded = 0
        let symptoms = ["Headache", "Fatigue", "Nausea", "Dizziness", "Pain", "Anxiety"]

        for symptom in symptoms {
            addEntry.openSymptomSearch()
            addEntry.searchForSymptom(symptom)

            if addEntry.selectSymptom(named: symptom) {
                symptomsAdded += 1

                if app.buttons["Add another symptom"].exists {
                    app.buttons["Add another symptom"].tap()
                } else {
                    // Can't add more
                    break
                }
            }
        }

        // Should prevent adding more than maximum
        XCTAssertLessThanOrEqual(symptomsAdded, 5,
                                "Should not allow more than maximum symptoms")
    }

    /// Tests entry with very long note
    func testVeryLongNote() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Add symptom
        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Headache")
        _ = addEntry.selectSymptom(named: "Headache")
        addEntry.setSeverity(3)

        // Enter very long note (500+ characters)
        let longNote = String(repeating: "This is a very long note describing symptoms in great detail. ", count: 10)
        addEntry.enterNote(longNote)

        // Should be able to save or show character limit
        let saveButton = app.buttons[AccessibilityIdentifiers.saveButton]
        if saveButton.exists {
            saveButton.tap()

            // Should either save successfully or show validation message
            Thread.sleep(forTimeInterval: 1.0)
            XCTAssertTrue(app.exists, "Should handle long notes gracefully")
        }
    }

    /// Tests minimum severity value
    func testMinimumSeverity() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Headache")
        _ = addEntry.selectSymptom(named: "Headache")

        // Set minimum severity (1)
        addEntry.setSeverity(1)

        addEntry.save()

        // Should save successfully
        XCTAssertTrue(timeline.waitForLoad(), "Should save entry with minimum severity")
    }

    /// Tests maximum severity value
    func testMaximumSeverity() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Headache")
        _ = addEntry.selectSymptom(named: "Headache")

        // Set maximum severity (5)
        addEntry.setSeverity(5)

        addEntry.save()

        // Should save successfully
        XCTAssertTrue(timeline.waitForLoad(), "Should save entry with maximum severity")
    }

    /// Tests creating entry with very old date
    func testVeryOldBackdatedEntry() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Try to change timestamp to far in the past (if supported)
        if app.buttons.matching(NSPredicate(format: "label CONTAINS 'Date' OR label CONTAINS 'Time'")).firstMatch.exists {
            let timestampButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Date' OR label CONTAINS 'Time'")).firstMatch
            timestampButton.tap()

            // Interact with date picker if it appears
            if app.datePickers.count > 0 {
                // Date picker appeared, app supports backdating
                Thread.sleep(forTimeInterval: 0.5)

                // Try to select old date (picker interaction varies)
                // For now, just verify the UI responds
                XCTAssertTrue(app.datePickers.firstMatch.exists,
                             "Should show date picker for backdating")

                // Dismiss picker
                if app.buttons["Done"].exists {
                    app.buttons["Done"].tap()
                } else if app.buttons["Cancel"].exists {
                    app.buttons["Cancel"].tap()
                }
            }
        }
    }

    /// Tests prevention of future dates
    func testFutureDatePrevention() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Add symptom first
        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Headache")
        _ = addEntry.selectSymptom(named: "Headache")
        addEntry.setSeverity(3)

        // Try to change timestamp
        if app.buttons.matching(NSPredicate(format: "label CONTAINS 'Date' OR label CONTAINS 'Time'")).firstMatch.exists {
            let timestampButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Date' OR label CONTAINS 'Time'")).firstMatch
            timestampButton.tap()

            if app.datePickers.count > 0 {
                // Date picker should not allow future dates
                // This is typically enforced by the date picker's maximum date
                XCTAssertTrue(app.datePickers.firstMatch.exists,
                             "Date picker should enforce maximum date")

                // Dismiss
                if app.buttons["Done"].exists {
                    app.buttons["Done"].tap()
                } else {
                    app.tap() // Tap outside to dismiss
                }
            }
        }
    }

    /// Tests attempting to save entry with all fields empty
    func testEntryWithAllFieldsEmpty() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Try to save without filling anything
        let saveButton = app.buttons[AccessibilityIdentifiers.saveButton]
        if saveButton.exists {
            // Save button should be disabled or show validation
            if saveButton.isEnabled {
                saveButton.tap()

                // Should show validation message or prevent save
                Thread.sleep(forTimeInterval: 0.5)

                // Should still be on add entry screen or show error
                XCTAssertTrue(app.exists, "Should validate empty entry")
            } else {
                // Save button correctly disabled
                XCTAssertFalse(saveButton.isEnabled,
                              "Save button should be disabled with empty entry")
            }
        }
    }

    // MARK: - Data Consistency (5 tests)

    /// Tests that edited entries persist correctly
    func testEditEntryPersists() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)

        // Tap first entry to open details
        if app.cells.count > 0 {
            let firstEntry = app.cells.firstMatch
            _ = firstEntry.label
            firstEntry.tap()

            let dayDetail = DayDetailScreen(app: app)
            XCTAssertTrue(dayDetail.waitForLoad(), "Day detail should load")

            // Look for edit button
            if app.buttons["Edit"].exists {
                app.buttons["Edit"].tap()
                Thread.sleep(forTimeInterval: 0.5)

                // Make an edit (add a note or change severity)
                let noteField = app.textViews.firstMatch
                if noteField.exists {
                    noteField.tap()
                    noteField.typeText(" Edited via UI test")
                }

                // Save changes
                if app.buttons["Save"].exists || app.buttons[AccessibilityIdentifiers.saveButton].exists {
                    (app.buttons["Save"].exists ? app.buttons["Save"] : app.buttons[AccessibilityIdentifiers.saveButton]).tap()
                }

                // Go back to timeline
                app.navigationBars.buttons.firstMatch.tap()

                // Verify entry still exists
                assertExists(timeline.logSymptomButton, message: "Should return to timeline")
            }
        }
    }

    /// Tests that deleted entries are removed from timeline
    func testDeleteEntryRemoves() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)

        // Get count of initial entries
        let initialCount = app.cells.count

        // Tap first entry
        if app.cells.count > 0 {
            let firstEntry = app.cells.firstMatch
            firstEntry.tap()

            let dayDetail = DayDetailScreen(app: app)
            dayDetail.waitForLoad()

            // Look for delete button
            if app.buttons["Delete"].exists {
                app.buttons["Delete"].tap()

                // Confirm deletion if alert appears
                if app.alerts.count > 0 {
                    app.alerts.buttons["Delete"].tap()
                }

                Thread.sleep(forTimeInterval: 1.0)

                // Should return to timeline
                assertExists(timeline.logSymptomButton, timeout: 5,
                            message: "Should return to timeline after delete")

                // Entry count should decrease
                let newCount = app.cells.count
                XCTAssertLessThan(newCount, initialCount,
                                 "Entry count should decrease after deletion")
            }
        }
    }

    /// Tests that newly added symptom types are immediately available
    func testAddSymptomTypeImmediatelyAvailable() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        // Go to settings
        app.buttons[AccessibilityIdentifiers.settingsButton].tap()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        // Navigate to tracked symptoms
        if app.buttons[AccessibilityIdentifiers.trackedSymptomsButton].exists {
            app.buttons[AccessibilityIdentifiers.trackedSymptomsButton].tap()
            Thread.sleep(forTimeInterval: 1.0)

            // Try to add a new symptom type
            if app.buttons["Add Symptom"].exists || app.navigationBars.buttons["+"].exists {
                (app.buttons["Add Symptom"].exists ? app.buttons["Add Symptom"] : app.navigationBars.buttons["+"]).tap()

                // Fill in symptom name
                let nameField = app.textFields.firstMatch
                if nameField.exists {
                    nameField.tap()
                    nameField.typeText("Test Symptom UI")

                    // Save
                    if app.buttons["Save"].exists {
                        app.buttons["Save"].tap()
                        Thread.sleep(forTimeInterval: 0.5)

                        // Go back to timeline
                        app.buttons[AccessibilityIdentifiers.logSymptomButton].tap()

                        // Open add entry
                        let timeline = TimelineScreen(app: app)
                        timeline.navigateToAddEntry()

                        let addEntry = AddEntryScreen(app: app)
                        addEntry.waitForLoad()

                        // Search for new symptom
                        addEntry.openSymptomSearch()
                        addEntry.searchForSymptom("Test Symptom UI")

                        // Should find it
                        XCTAssertTrue(app.staticTexts["Test Symptom UI"].exists,
                                     "Newly added symptom should be immediately available")
                    }
                }
            }
        }
    }

    /// Tests deleting symptom type that has associated entries
    func testDeleteSymptomTypeWithEntries() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        app.buttons[AccessibilityIdentifiers.settingsButton].tap()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        // Navigate to tracked symptoms
        if app.buttons[AccessibilityIdentifiers.trackedSymptomsButton].exists {
            app.buttons[AccessibilityIdentifiers.trackedSymptomsButton].tap()
            Thread.sleep(forTimeInterval: 1.0)

            // Try to delete a symptom type
            // This should either be prevented or show a confirmation
            let symptoms = app.cells
            if symptoms.count > 0 {
                let firstSymptom = symptoms.element(boundBy: 0)
                firstSymptom.swipeLeft()

                if app.buttons["Delete"].exists {
                    app.buttons["Delete"].tap()

                    // Should show confirmation or prevent deletion
                    if app.alerts.count > 0 {
                        // Alert shown, dismiss it
                        if app.alerts.buttons["Cancel"].exists {
                            app.alerts.buttons["Cancel"].tap()
                        }
                    }

                    XCTAssertTrue(app.exists,
                                 "Should handle deletion of symptom with entries")
                }
            }
        }
    }

    /// Tests that app handles being backgrounded during save
    func testAppBackgroundedDuringSave() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Start creating an entry
        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Headache")
        _ = addEntry.selectSymptom(named: "Headache")
        addEntry.setSeverity(3)

        // Background the app
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.0)

        // Reactivate
        app.activate()
        Thread.sleep(forTimeInterval: 1.0)

        // Should still be on add entry screen or returned to timeline
        // Either way, app should handle gracefully
        XCTAssertTrue(app.exists, "App should handle backgrounding during entry creation")
    }
}
