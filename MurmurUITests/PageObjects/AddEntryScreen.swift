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
        app.sliders.matching(identifier: AccessibilityIdentifiers.severitySlider).firstMatch
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
        app.textFields["Notes (optional)"]
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
        searchField.waitForExistence(timeout: timeout)
        searchField.tap()
        searchField.typeText(name)
    }

    /// Select a symptom from the search results
    func selectSymptom(named name: String, timeout: TimeInterval = 3) -> Bool {
        let symptomCell = app.staticTexts[name]
        guard symptomCell.waitForExistence(timeout: timeout) else {
            return false
        }
        symptomCell.tap()
        return true
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
        notesField.waitForExistence(timeout: timeout)
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
