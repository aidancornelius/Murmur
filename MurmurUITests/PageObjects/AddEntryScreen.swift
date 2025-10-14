//
//  AddEntryScreen.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest

/// Page Object representing the add entry screen
struct AddEntryScreen {
    let app: XCUIApplication

    // MARK: - Elements

    var searchAllSymptomsButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.searchAllSymptomsButton]
    }

    var searchField: XCUIElement {
        app.textFields.matching(identifier: AccessibilityIdentifiers.symptomSearchField).firstMatch
    }

    var severitySlider: XCUIElement {
        // First try the shared severity slider
        let sharedSlider = app.sliders.matching(identifier: AccessibilityIdentifiers.severitySlider).firstMatch
        if sharedSlider.exists {
            return sharedSlider
        }
        // If no shared slider, return the first individual symptom slider
        // Individual sliders have identifiers like "severity-slider-<symptomName>"
        return app.sliders.matching(NSPredicate(format: "identifier BEGINSWITH 'severity-slider-'")).firstMatch
    }

    var severityLabel: XCUIElement {
        app.staticTexts.matching(identifier: AccessibilityIdentifiers.severityLabel).firstMatch
    }

    var saveButton: XCUIElement {
        app.buttons.matching(identifier: AccessibilityIdentifiers.saveButton).firstMatch
    }

    var cancelButton: XCUIElement {
        app.buttons.matching(identifier: AccessibilityIdentifiers.cancelButton).firstMatch
    }

    var notesField: XCUIElement {
        // TextField with axis: .vertical appears as textView in the accessibility tree
        app.textViews.matching(identifier: AccessibilityIdentifiers.noteTextField).firstMatch
    }

    // MARK: - Actions

    /// Wait for the add entry screen to load
    @discardableResult
    func waitForLoad(timeout: TimeInterval = 3) -> Bool {
        searchAllSymptomsButton.waitForExistence(timeout: timeout) ||
        severitySlider.waitForExistence(timeout: timeout)
    }

    /// Open the search all symptoms screen
    func openSymptomSearch() {
        searchAllSymptomsButton.tap()
    }

    /// Search for a symptom by name
    func searchForSymptom(_ name: String, timeout: TimeInterval = 3) {
        _ = searchField.waitForExistence(timeout: timeout)
        searchField.tap()
        searchField.typeText(name)
    }

    /// Select a symptom from the search results
    func selectSymptom(named name: String, timeout: TimeInterval = 3) -> Bool {
        // First try to find by accessibility identifier
        let symptomButton = app.buttons.matching(identifier: AccessibilityIdentifiers.quickSymptomButton(name)).firstMatch
        if symptomButton.waitForExistence(timeout: timeout) {
            symptomButton.tap()
            return true
        }

        // Fallback: search by label/text (case insensitive)
        let symptomByLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        if symptomByLabel.waitForExistence(timeout: 1) {
            symptomByLabel.tap()
            return true
        }

        // Fallback: try static texts that might be tappable
        let symptomText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        if symptomText.waitForExistence(timeout: 1) {
            symptomText.tap()
            return true
        }

        return false
    }

    /// Select a symptom button (for quick selection)
    func selectSymptomButton(named name: String) -> Bool {
        let button = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        guard button.exists else {
            return false
        }
        button.tap()
        return true
    }

    /// Set severity level (1-5)
    func setSeverity(_ level: Int) {
        guard level >= 1 && level <= 5 else { return }
        let normalizedPosition = CGFloat(level - 1) / 4.0
        severitySlider.adjust(toNormalizedSliderPosition: normalizedPosition)
    }

    /// Enter note text
    func enterNote(_ text: String, timeout: TimeInterval = 2) {
        guard notesField.waitForExistence(timeout: timeout) else {
            return
        }
        // Scroll to make the field visible if needed
        notesField.scrollToVisible()
        notesField.tap()
        notesField.typeText(text)
    }

    /// Save the entry
    func save() {
        saveButton.tap()
    }

    /// Cancel the entry
    func cancel() {
        cancelButton.tap()
    }

    /// Complete full symptom entry flow
    @discardableResult
    func addSymptomEntry(symptom: String, severity: Int, note: String? = nil) -> Bool {
        openSymptomSearch()
        searchForSymptom(symptom)

        guard selectSymptom(named: symptom) else {
            return false
        }

        setSeverity(severity)

        if let note = note {
            enterNote(note)
        }

        save()
        return true
    }

    // MARK: - Queries

    /// Get current severity label text
    func getCurrentSeverityLabel() -> String? {
        guard severityLabel.exists else { return nil }
        return severityLabel.label
    }

    /// Check if save button is enabled
    func isSaveButtonEnabled() -> Bool {
        saveButton.isEnabled
    }

    /// Check if a symptom is selected
    func hasSymptomSelected() -> Bool {
        severitySlider.exists
    }
}
