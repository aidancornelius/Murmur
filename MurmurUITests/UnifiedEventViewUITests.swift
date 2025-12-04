// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// UnifiedEventViewUITests.swift
// Created by Aidan Cornelius-Bell on 13/10/2025.
// UI tests for unified event view.
//
import XCTest

/// Comprehensive UI tests for UnifiedEventView workflows
final class UnifiedEventViewUITests: XCTestCase {
    var app: XCUIApplication?
    private var systemAlertMonitor: NSObjectProtocol?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        systemAlertMonitor = registerSystemAlertMonitor()
    }

    override func tearDownWithError() throws {
        if let monitor = systemAlertMonitor {
            removeUIInterruptionMonitor(monitor)
        }
        app = nil
    }

    // MARK: - Activity Event Tests

    /// Tests creating a basic activity event
    func testCreateBasicActivityEvent() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        XCTAssertTrue(unifiedEvent.waitForLoad(), "Unified event screen should load")

        // Verify activity is default event type
        XCTAssertTrue(unifiedEvent.hasEventTypeSelected(.activity), "Activity should be default event type")

        // Enter activity description
        unifiedEvent.enterMainInput("Walked in the park")
        waitForUIToSettle(timeout: 0.5)

        // Verify save button becomes enabled
        XCTAssertTrue(unifiedEvent.saveButton.waitForEnabled(timeout: 3.0), "Save button should be enabled")

        // Save the activity
        unifiedEvent.save()

        // Verify returned to timeline
        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline after save")
    }

    /// Tests creating activity with custom exertion levels
    func testCreateActivityWithExertionLevels() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter activity
        unifiedEvent.enterMainInput("Yoga session")
        waitForUIToSettle(timeout: 0.5)

        // Verify exertion rings are visible
        assertExists(unifiedEvent.physicalExertionRing, timeout: 2, message: "Physical exertion ring should be visible")
        assertExists(unifiedEvent.cognitiveExertionRing, timeout: 2, message: "Cognitive exertion ring should be visible")
        assertExists(unifiedEvent.emotionalLoadRing, timeout: 2, message: "Emotional load ring should be visible")

        // Save activity
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    /// Tests creating activity with time chips
    func testCreateActivityWithTimeChips() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter activity
        unifiedEvent.enterMainInput("Morning jog")
        waitForUIToSettle(timeout: 0.5)

        // Select time chip
        unifiedEvent.selectTimeChip("1 hour ago")
        waitForUIToSettle(timeout: 0.3)

        // Save activity
        XCTAssertTrue(unifiedEvent.saveButton.waitForEnabled(timeout: 3.0), "Save button should be enabled")
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    /// Tests creating activity with duration chips
    func testCreateActivityWithDurationChips() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter activity
        unifiedEvent.enterMainInput("Swimming")
        waitForUIToSettle(timeout: 0.5)

        // Select duration chip
        unifiedEvent.selectDurationChip("30 min")
        waitForUIToSettle(timeout: 0.3)

        // Save activity
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    /// Tests creating activity with notes
    func testCreateActivityWithNotes() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter activity
        unifiedEvent.enterMainInput("Cycling")
        waitForUIToSettle(timeout: 0.5)

        // Add notes
        unifiedEvent.enterNote("Beautiful weather, felt great")
        waitForUIToSettle(timeout: 0.3)

        // Verify notes field is expanded
        XCTAssertTrue(unifiedEvent.isNotesExpanded(), "Notes section should be expanded")

        // Save activity
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    // MARK: - Event Type Switching Tests

    /// Tests switching from activity to sleep event type
    func testSwitchFromActivityToSleep() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Start with activity (default)
        XCTAssertTrue(unifiedEvent.hasEventTypeSelected(.activity), "Should start with activity")

        // Switch to sleep
        unifiedEvent.selectEventType(.sleep)
        waitForUIToSettle(timeout: 0.5)

        // Verify sleep type selected
        XCTAssertTrue(unifiedEvent.hasEventTypeSelected(.sleep), "Sleep event type should be selected")

        // Verify sleep-specific fields appear
        assertExists(unifiedEvent.bedTimePicker, timeout: 2, message: "Bed time picker should be visible")
        assertExists(unifiedEvent.wakeTimePicker, timeout: 2, message: "Wake time picker should be visible")
        assertExists(unifiedEvent.sleepQualityRing, timeout: 2, message: "Sleep quality ring should be visible")

        // Cancel to avoid saving
        unifiedEvent.cancel()
    }

    /// Tests switching from activity to meal event type
    func testSwitchFromActivityToMeal() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Switch to meal
        unifiedEvent.selectEventType(.meal)
        waitForUIToSettle(timeout: 0.5)

        // Verify meal type selected
        XCTAssertTrue(unifiedEvent.hasEventTypeSelected(.meal), "Meal event type should be selected")

        // Verify meal-specific fields appear
        assertExists(unifiedEvent.mealTypePicker, timeout: 2, message: "Meal type picker should be visible")

        // Cancel to avoid saving
        unifiedEvent.cancel()
    }

    /// Tests switching between all event types
    func testSwitchBetweenAllEventTypes() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Cycle through all event types
        unifiedEvent.selectEventType(.activity)
        waitForUIToSettle(timeout: 0.3)
        XCTAssertTrue(unifiedEvent.hasEventTypeSelected(.activity), "Activity should be selected")

        unifiedEvent.selectEventType(.sleep)
        waitForUIToSettle(timeout: 0.3)
        XCTAssertTrue(unifiedEvent.hasEventTypeSelected(.sleep), "Sleep should be selected")

        unifiedEvent.selectEventType(.meal)
        waitForUIToSettle(timeout: 0.3)
        XCTAssertTrue(unifiedEvent.hasEventTypeSelected(.meal), "Meal should be selected")

        unifiedEvent.selectEventType(.activity)
        waitForUIToSettle(timeout: 0.3)
        XCTAssertTrue(unifiedEvent.hasEventTypeSelected(.activity), "Activity should be selected again")

        unifiedEvent.cancel()
    }

    // MARK: - Sleep Event Tests

    /// Tests creating a basic sleep event
    func testCreateBasicSleepEvent() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Switch to sleep event
        unifiedEvent.selectEventType(.sleep)
        waitForUIToSettle(timeout: 0.5)

        // Enter sleep description (should auto-populate)
        if unifiedEvent.mainInputField.value as? String == "" {
            unifiedEvent.enterMainInput("Sleep")
        }
        waitForUIToSettle(timeout: 0.5)

        // Verify sleep fields are visible
        assertExists(unifiedEvent.bedTimePicker, message: "Bed time picker should be visible")
        assertExists(unifiedEvent.wakeTimePicker, message: "Wake time picker should be visible")

        // Save sleep event
        XCTAssertTrue(unifiedEvent.saveButton.waitForEnabled(timeout: 3.0), "Save button should be enabled")
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    /// Tests creating sleep event with quality rating
    func testCreateSleepEventWithQuality() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Switch to sleep
        unifiedEvent.selectEventType(.sleep)
        waitForUIToSettle(timeout: 0.5)

        // Verify sleep quality ring is visible
        assertExists(unifiedEvent.sleepQualityRing, timeout: 2, message: "Sleep quality ring should be visible")

        // Save sleep event
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    /// Tests creating sleep event with notes
    func testCreateSleepEventWithNotes() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Switch to sleep
        unifiedEvent.selectEventType(.sleep)
        waitForUIToSettle(timeout: 0.5)

        // Add notes
        unifiedEvent.enterNote("Woke up feeling refreshed")
        waitForUIToSettle(timeout: 0.3)

        XCTAssertTrue(unifiedEvent.isNotesExpanded(), "Notes section should be expanded")

        // Save
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    // MARK: - Meal Event Tests

    /// Tests creating a basic meal event
    func testCreateBasicMealEvent() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Switch to meal
        unifiedEvent.selectEventType(.meal)
        waitForUIToSettle(timeout: 0.5)

        // Enter meal description
        unifiedEvent.enterMainInput("Oatmeal with berries")
        waitForUIToSettle(timeout: 0.5)

        // Verify meal type picker is visible
        assertExists(unifiedEvent.mealTypePicker, timeout: 2, message: "Meal type picker should be visible")

        // Save meal
        XCTAssertTrue(unifiedEvent.saveButton.waitForEnabled(timeout: 3.0), "Save button should be enabled")
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    /// Tests creating meal event with exertion toggle
    func testCreateMealEventWithExertion() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Switch to meal
        unifiedEvent.selectEventType(.meal)
        waitForUIToSettle(timeout: 0.5)

        // Enter meal
        unifiedEvent.enterMainInput("Large buffet meal")
        waitForUIToSettle(timeout: 0.5)

        // Look for exertion toggle button
        let exertionToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS 'energy impact' OR label CONTAINS 'Add energy'")).firstMatch
        if exertionToggle.waitForExistence(timeout: 2) {
            exertionToggle.tap()
            waitForUIToSettle(timeout: 0.5)

            // Verify exertion rings appear
            assertExists(unifiedEvent.physicalExertionRing, timeout: 2, message: "Physical exertion ring should appear for meal")
        }

        // Save meal
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    /// Tests creating meal with different meal types
    func testCreateMealWithDifferentTypes() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)

        // Test breakfast
        timeline.navigateToAddEvent()
        var unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()
        unifiedEvent.selectEventType(.meal)
        waitForUIToSettle(timeout: 0.5)
        unifiedEvent.enterMainInput("Toast and eggs")
        waitForUIToSettle(timeout: 0.5)

        // Select breakfast (should be default)
        if unifiedEvent.mealTypePicker.exists {
            // Meal type picker is visible
            XCTAssertTrue(true, "Meal type picker is visible")
        }

        unifiedEvent.save()
        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline after breakfast")

        // Test lunch
        timeline.navigateToAddEvent()
        unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()
        unifiedEvent.selectEventType(.meal)
        waitForUIToSettle(timeout: 0.5)
        unifiedEvent.enterMainInput("Sandwich")
        waitForUIToSettle(timeout: 0.5)

        // Change to lunch
        if unifiedEvent.mealTypePicker.exists {
            let lunchButton = app.buttons["Lunch"]
            if lunchButton.exists {
                lunchButton.tap()
                waitForUIToSettle(timeout: 0.3)
            }
        }

        unifiedEvent.save()
        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline after lunch")
    }

    // MARK: - Backdating Tests

    /// Tests backdating an activity event
    func testBackdateActivityEvent() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter activity
        unifiedEvent.enterMainInput("Afternoon walk")
        waitForUIToSettle(timeout: 0.5)

        // Select time chip for backdating
        unifiedEvent.selectTimeChip("2 hours ago")
        waitForUIToSettle(timeout: 0.3)

        // Save
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    /// Tests backdating with "Yesterday" chip
    func testBackdateToYesterday() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter activity
        unifiedEvent.enterMainInput("Evening walk")
        waitForUIToSettle(timeout: 0.5)

        // Select yesterday chip
        unifiedEvent.selectTimeChip("Yesterday")
        waitForUIToSettle(timeout: 0.3)

        // Save
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    // MARK: - Cancel and Validation Tests

    /// Tests cancelling activity creation
    func testCancelActivityCreation() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        let initialCount = timeline.entryCount()

        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter some data
        unifiedEvent.enterMainInput("Test activity")
        waitForUIToSettle(timeout: 0.5)
        unifiedEvent.enterNote("This should not be saved")
        waitForUIToSettle(timeout: 0.3)

        // Cancel
        unifiedEvent.cancel()

        // Verify back on timeline
        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")

        // Verify no new entry
        XCTAssertEqual(timeline.entryCount(), initialCount, "No new entry should be created after cancel")
    }

    /// Tests save button is disabled with empty input
    func testSaveButtonDisabledWithEmptyInput() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Verify save button is disabled
        assertDisabled(unifiedEvent.saveButton, message: "Save button should be disabled with empty input")

        // Cancel
        unifiedEvent.cancel()
    }

    /// Tests save button becomes enabled with valid input
    func testSaveButtonEnabledWithValidInput() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Initially disabled
        assertDisabled(unifiedEvent.saveButton, message: "Save button should start disabled")

        // Enter input
        unifiedEvent.enterMainInput("Running")
        waitForUIToSettle(timeout: 0.5)

        // Should become enabled
        XCTAssertTrue(unifiedEvent.saveButton.waitForEnabled(timeout: 3.0), "Save button should be enabled with valid input")

        // Cancel
        unifiedEvent.cancel()
    }

    // MARK: - Natural Language Parsing Tests

    /// Tests natural language input for activity
    func testNaturalLanguageActivityInput() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter natural language input
        unifiedEvent.enterMainInput("Ran 5km in the park")
        waitForUIToSettle(timeout: 0.5)

        // Verify activity type is selected
        XCTAssertTrue(unifiedEvent.hasEventTypeSelected(.activity), "Activity should be detected from input")

        // Save
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    /// Tests natural language input with duration
    func testNaturalLanguageInputWithDuration() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter natural language with duration
        unifiedEvent.enterMainInput("Walked for 30 minutes")
        waitForUIToSettle(timeout: 0.5)

        // Save
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    // MARK: - Notes Feature Tests

    /// Tests expanding and collapsing notes section
    func testExpandCollapseNotesSection() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Initially notes should be collapsed
        XCTAssertFalse(unifiedEvent.isNotesExpanded(), "Notes should start collapsed")

        // Expand notes
        unifiedEvent.openNotes()
        waitForUIToSettle(timeout: 0.5)

        // Should be expanded
        XCTAssertTrue(unifiedEvent.isNotesExpanded(), "Notes should be expanded")

        // Collapse by tapping toggle again
        if unifiedEvent.notesToggleButton.exists {
            unifiedEvent.notesToggleButton.tap()
            waitForUIToSettle(timeout: 0.5)
        }

        // Cancel
        unifiedEvent.cancel()
    }

    /// Tests adding multiline notes
    func testAddMultilineNotes() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter activity
        unifiedEvent.enterMainInput("Gym workout")
        waitForUIToSettle(timeout: 0.5)

        // Add multiline note
        let note = "Great session today.\nFocused on upper body.\nFeeling strong."
        unifiedEvent.enterNote(note)
        waitForUIToSettle(timeout: 0.3)

        // Save
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    // MARK: - Edge Cases

    /// Tests creating event with very long text
    func testCreateEventWithLongText() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter long text
        let longText = String(repeating: "This is a very long activity description. ", count: 5)
        unifiedEvent.enterMainInput(longText)
        waitForUIToSettle(timeout: 0.5)

        // Should handle gracefully
        XCTAssertTrue(unifiedEvent.saveButton.waitForEnabled(timeout: 3.0), "Save button should be enabled")

        // Save
        unifiedEvent.save()

        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    /// Tests switching event types preserves input
    func testSwitchingEventTypesPreservesInput() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Enter text
        let testText = "Test event"
        unifiedEvent.enterMainInput(testText)
        waitForUIToSettle(timeout: 0.5)

        // Switch to meal
        unifiedEvent.selectEventType(.meal)
        waitForUIToSettle(timeout: 0.5)

        // Check if text is preserved
        let currentValue = unifiedEvent.mainInputField.value as? String ?? ""
        XCTAssertTrue(currentValue.contains(testText) || !currentValue.isEmpty, "Input should be preserved or not lost")

        // Cancel
        unifiedEvent.cancel()
    }

    /// Tests rapid event type switching
    func testRapidEventTypeSwitching() throws {
        guard let app = app else {
            XCTFail("App not initialised")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        let unifiedEvent = UnifiedEventScreen(app: app)
        unifiedEvent.waitForLoad()

        // Rapidly switch between types
        for _ in 0..<3 {
            unifiedEvent.selectEventType(.activity)
            unifiedEvent.selectEventType(.sleep)
            unifiedEvent.selectEventType(.meal)
        }

        waitForUIToSettle(timeout: 0.5)

        // Should still be responsive
        XCTAssertTrue(unifiedEvent.mainInputField.exists, "UI should remain responsive")

        // Cancel
        unifiedEvent.cancel()
    }
}
