// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// UnifiedEventScreen.swift
// Created by Aidan Cornelius-Bell on 13/10/2025.
// Page object for unified event screen.
//
import XCTest

/// Page Object representing the unified event entry screen
/// This screen handles activity, sleep, and meal event logging with natural language input
struct UnifiedEventScreen {
    let app: XCUIApplication

    // MARK: - Elements

    var mainInputField: XCUIElement {
        app.textFields.matching(identifier: AccessibilityIdentifiers.mainInputField).firstMatch
    }

    var eventTypeButton: XCUIElement {
        app.buttons.matching(identifier: AccessibilityIdentifiers.eventTypeButton).firstMatch
    }

    var saveButton: XCUIElement {
        app.buttons.matching(identifier: AccessibilityIdentifiers.saveButton).firstMatch
    }

    var cancelButton: XCUIElement {
        app.buttons.matching(identifier: AccessibilityIdentifiers.cancelButton).firstMatch
    }

    var notesField: XCUIElement {
        app.textFields.matching(identifier: AccessibilityIdentifiers.notesField).firstMatch
    }

    var notesToggleButton: XCUIElement {
        app.buttons.matching(identifier: AccessibilityIdentifiers.notesToggleButton).firstMatch
    }

    // Exertion ring selectors (for activities and meals)
    var physicalExertionRing: XCUIElement {
        app.staticTexts.matching(identifier: AccessibilityIdentifiers.physicalExertionRing).firstMatch
    }

    var cognitiveExertionRing: XCUIElement {
        app.staticTexts.matching(identifier: AccessibilityIdentifiers.cognitiveExertionRing).firstMatch
    }

    var emotionalLoadRing: XCUIElement {
        app.staticTexts.matching(identifier: AccessibilityIdentifiers.emotionalLoadRing).firstMatch
    }

    // Sleep quality - can be either staticTexts or otherElements depending on label visibility
    var sleepQualityRing: XCUIElement {
        let staticText = app.staticTexts.matching(identifier: AccessibilityIdentifiers.sleepQualityRing).firstMatch
        if staticText.exists {
            return staticText
        }
        return app.otherElements.matching(identifier: AccessibilityIdentifiers.sleepQualityRing).firstMatch
    }

    var bedTimePicker: XCUIElement {
        app.datePickers.matching(identifier: AccessibilityIdentifiers.bedTimePicker).firstMatch
    }

    var wakeTimePicker: XCUIElement {
        app.datePickers.matching(identifier: AccessibilityIdentifiers.wakeTimePicker).firstMatch
    }

    // Meal type picker
    var mealTypePicker: XCUIElement {
        app.segmentedControls.matching(identifier: AccessibilityIdentifiers.mealTypePicker).firstMatch
    }

    // Time chips
    func timeChipButton(_ chipText: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", chipText)).firstMatch
    }

    // Duration chips
    func durationChipButton(_ chipText: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", chipText)).firstMatch
    }

    // Calendar events
    var calendarEventRow: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'From your calendar' OR identifier CONTAINS 'calendar-event'")).firstMatch
    }

    // Error messages
    var errorMessage: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Please fix' OR label CONTAINS 'error' OR label CONTAINS 'Error'")).firstMatch
    }

    // MARK: - Actions

    /// Wait for the unified event screen to load
    @discardableResult
    func waitForLoad(timeout: TimeInterval = 3) -> Bool {
        mainInputField.waitForExistence(timeout: timeout) ||
        saveButton.waitForExistence(timeout: timeout)
    }

    /// Enter text in the main input field
    func enterMainInput(_ text: String, timeout: TimeInterval = 2) {
        guard mainInputField.waitForExistence(timeout: timeout) else {
            return
        }
        mainInputField.tap()
        mainInputField.typeText(text)
    }

    /// Clear and enter text in the main input field
    func setMainInput(_ text: String, timeout: TimeInterval = 2) {
        guard mainInputField.waitForExistence(timeout: timeout) else {
            return
        }
        mainInputField.tap()

        // Clear existing text if any
        if let currentValue = mainInputField.value as? String, !currentValue.isEmpty {
            // Select all and delete
            mainInputField.doubleTap()
            if app.menuItems["Select All"].exists {
                app.menuItems["Select All"].tap()
            }
            let deleteKey = app.keys["delete"]
            if deleteKey.exists {
                deleteKey.tap()
            }
        }

        mainInputField.typeText(text)
    }

    /// Select event type from the dropdown
    func selectEventType(_ type: EventType, timeout: TimeInterval = 2) {
        guard eventTypeButton.waitForExistence(timeout: timeout) else {
            return
        }
        eventTypeButton.tap()

        // Wait for menu to appear using run loop
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        let menuButton: XCUIElement
        switch type {
        case .activity:
            menuButton = app.buttons["Activity"].firstMatch
        case .sleep:
            menuButton = app.buttons["Sleep"].firstMatch
        case .meal:
            menuButton = app.buttons["Meal"].firstMatch
        }

        if menuButton.waitForExistence(timeout: 1.0) {
            menuButton.tap()
        }
    }

    /// Tap a time chip button
    func selectTimeChip(_ chipText: String) {
        let chip = timeChipButton(chipText)
        if chip.waitForExistence(timeout: 2.0) {
            chip.tap()
        }
    }

    /// Tap a duration chip button
    func selectDurationChip(_ chipText: String) {
        let chip = durationChipButton(chipText)
        if chip.waitForExistence(timeout: 2.0) {
            chip.tap()
        }
    }

    /// Open notes section if not already open
    func openNotes(timeout: TimeInterval = 2) {
        guard notesToggleButton.waitForExistence(timeout: timeout) else {
            return
        }

        // Check if notes field is already visible
        if !notesField.exists {
            notesToggleButton.tap()
            // Wait for notes field to appear using predicate
            _ = notesField.waitForExistence(timeout: 1.0)
        }
    }

    /// Enter note text
    func enterNote(_ text: String, timeout: TimeInterval = 2) {
        openNotes(timeout: timeout)

        guard notesField.waitForExistence(timeout: timeout) else {
            return
        }

        notesField.scrollToVisible()
        notesField.tap()
        notesField.typeText(text)
    }

    /// Save the event
    func save() {
        saveButton.tap()
    }

    /// Cancel the event creation
    func cancel() {
        cancelButton.tap()
    }

    /// Complete full event entry flow with main input
    @discardableResult
    func addEvent(input: String, note: String? = nil, eventType: EventType? = nil) -> Bool {
        // Select event type first if specified
        if let eventType = eventType {
            selectEventType(eventType)
            // Wait for UI to update
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }

        // Enter main input
        enterMainInput(input)
        // Wait for input to be processed
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        // Add note if provided
        if let note = note {
            enterNote(note)
        }

        // Wait for save button to be enabled
        guard saveButton.waitForEnabled(timeout: 3.0) else {
            return false
        }

        save()
        return true
    }

    /// Complete activity event with exertion levels
    @discardableResult
    func addActivityEvent(input: String,
                         physicalExertion: Int? = nil,
                         cognitiveExertion: Int? = nil,
                         emotionalLoad: Int? = nil,
                         note: String? = nil) -> Bool {
        selectEventType(.activity)
        // Wait for UI to update
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        enterMainInput(input)
        // Wait for input to be processed
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        // Set exertion levels if provided
        // Note: Exertion rings may require specific interactions based on implementation
        // For now, we'll just check they exist
        if physicalExertion != nil || cognitiveExertion != nil || emotionalLoad != nil {
            // Wait for exertion card to appear using predicate
            _ = physicalExertionRing.waitForExistence(timeout: 1.0)
        }

        if let note = note {
            enterNote(note)
        }

        guard saveButton.waitForEnabled(timeout: 3.0) else {
            return false
        }

        save()
        return true
    }

    // MARK: - Queries

    /// Check if save button is enabled
    func isSaveButtonEnabled() -> Bool {
        saveButton.isEnabled
    }

    /// Check if an event type is currently selected
    func hasEventTypeSelected(_ type: EventType) -> Bool {
        // Check if the event type button's accessibility label matches
        guard eventTypeButton.waitForExistence(timeout: 2.0) else { return false }

        let expectedLabel: String
        switch type {
        case .activity:
            expectedLabel = "Activity"
        case .sleep:
            expectedLabel = "Sleep"
        case .meal:
            expectedLabel = "Meal"
        }

        // The button has an accessibility label set to the event type name
        return eventTypeButton.label == expectedLabel
    }

    /// Check if error message is displayed
    func hasError() -> Bool {
        errorMessage.exists
    }

    /// Get current error message text
    func getErrorMessage() -> String? {
        guard errorMessage.exists else { return nil }
        return errorMessage.label
    }

    /// Check if notes section is expanded
    func isNotesExpanded() -> Bool {
        notesField.exists
    }

    // MARK: - Supporting Types

    enum EventType {
        case activity
        case sleep
        case meal
    }
}
