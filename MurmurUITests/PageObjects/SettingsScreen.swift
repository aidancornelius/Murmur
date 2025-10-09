//
//  SettingsScreen.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest

/// Page Object representing the settings screen
struct SettingsScreen {
    let app: XCUIApplication

    // MARK: - Elements

    var backButton: XCUIElement {
        app.navigationBars.buttons.element(boundBy: 0)
    }

    var trackedSymptomsButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.trackedSymptomsButton]
    }

    var remindersButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.remindersButton]
    }

    var loadCapacityButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.loadCapacityButton]
    }

    var notificationsButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.notificationsButton]
    }

    var appearanceButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.appearanceButton]
    }

    var privacyButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.privacyButton]
    }

    var dataManagementButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.dataManagementButton]
    }

    var aboutButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.aboutButton]
    }

    // MARK: - Actions

    /// Wait for settings screen to load
    @discardableResult
    func waitForLoad(timeout: TimeInterval = 5) -> Bool {
        trackedSymptomsButton.waitForExistence(timeout: timeout) ||
        loadCapacityButton.waitForExistence(timeout: timeout)
    }

    /// Go back to previous screen
    func goBack() {
        backButton.tap()
    }

    /// Navigate to tracked symptoms settings
    func navigateToTrackedSymptoms() {
        trackedSymptomsButton.tap()
    }

    /// Navigate to reminders settings
    func navigateToReminders() {
        remindersButton.tap()
    }

    /// Navigate to load capacity settings
    func navigateToLoadCapacity() {
        loadCapacityButton.tap()
    }

    /// Navigate to notifications settings
    func navigateToNotifications() {
        notificationsButton.tap()
    }

    /// Navigate to appearance settings
    func navigateToAppearance() {
        appearanceButton.tap()
    }

    /// Navigate to privacy settings
    func navigateToPrivacy() {
        privacyButton.tap()
    }

    /// Navigate to data management
    func navigateToDataManagement() {
        dataManagementButton.tap()
    }

    /// Navigate to about screen
    func navigateToAbout() {
        aboutButton.tap()
    }

    // MARK: - Tracked Symptoms Actions

    /// Add a new symptom type
    func addSymptomType(name: String, timeout: TimeInterval = 5) -> Bool {
        // Assumes we're already on tracked symptoms screen
        let addButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier == 'plus' OR label == 'Add'")).firstMatch
        guard addButton.waitForExistence(timeout: timeout) else {
            return false
        }
        addButton.tap()

        let textField = app.textFields.firstMatch
        guard textField.waitForExistence(timeout: timeout) else {
            return false
        }
        textField.tap()
        textField.typeText(name)

        let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'add' OR label CONTAINS[c] 'done'")).firstMatch
        guard saveButton.waitForExistence(timeout: timeout) else {
            return false
        }
        saveButton.tap()

        return true
    }

    /// Delete a symptom type by name
    func deleteSymptomType(named name: String, timeout: TimeInterval = 3) -> Bool {
        // Find the cell containing the symptom name
        let symptomCell = app.cells.containing(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        guard symptomCell.waitForExistence(timeout: timeout) else {
            return false
        }

        symptomCell.swipeLeft()

        let deleteButton = app.buttons["Delete"]
        guard deleteButton.waitForExistence(timeout: 2) else {
            return false
        }
        deleteButton.tap()

        return true
    }

    // MARK: - Queries

    /// Check if a specific setting option exists
    func hasSettingOption(_ name: String) -> Bool {
        app.buttons[name].exists || app.staticTexts[name].exists
    }

    /// Check if symptom type exists
    func hasSymptomType(named name: String, timeout: TimeInterval = 5) -> Bool {
        // Wait a moment for Core Data and UI to update after save
        Thread.sleep(forTimeInterval: 0.3)

        // Check for the symptom name in static texts or as accessibility labels on buttons/links
        let symptomText = app.staticTexts[name]
        if symptomText.waitForExistence(timeout: timeout) {
            return true
        }

        // Check in links (NavigationLinks appear as links in the accessibility tree)
        let symptomLink = app.links.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        if symptomLink.waitForExistence(timeout: timeout) {
            return true
        }

        let symptomButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        if symptomButton.waitForExistence(timeout: timeout) {
            return true
        }

        let symptomElement = app.otherElements.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        return symptomElement.waitForExistence(timeout: timeout)
    }
}
