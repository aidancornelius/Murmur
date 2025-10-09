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
        guard trackedSymptomsButton.waitForExistence(timeout: 3) else { return }
        trackedSymptomsButton.tap()

        // Wait for tracked symptoms screen to load
        let addButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier == 'plus' OR label == 'Add'")).firstMatch
        _ = addButton.waitForExistence(timeout: 5)
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
        // Wait for any navigation animations to complete
        Thread.sleep(forTimeInterval: 3.0)

        // Try to find the add button by accessibility label first (more reliable)
        let addButton = app.buttons["Add symptom"]
        if !addButton.exists {
            // Fallback to searching by identifier
            let fallbackButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier == 'plus' OR label == 'Add'")).firstMatch
            guard fallbackButton.waitForExistence(timeout: timeout) else {
                return false
            }
            // Ensure button is fully ready
            while !fallbackButton.isHittable && Date().timeIntervalSinceNow < timeout {
                Thread.sleep(forTimeInterval: 0.1)
            }
            fallbackButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            // Second tap if needed
            if !app.textFields.firstMatch.exists {
                fallbackButton.tap()
            }
        } else {
            // Ensure button is fully ready
            while !addButton.isHittable && Date().timeIntervalSinceNow < timeout {
                Thread.sleep(forTimeInterval: 0.1)
            }
            addButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
            // Second tap if needed
            if !app.textFields.firstMatch.exists {
                addButton.tap()
            }
        }

        // Verify the text field appears (form sheet opened)
        let textField = app.textFields.firstMatch
        guard textField.waitForExistence(timeout: 10.0) else {
            return false
        }
        textField.tap()
        textField.typeText(name)

        let saveButton = app.buttons["Save"]
        guard saveButton.waitForExistence(timeout: timeout) else {
            return false
        }

        // Wait for button to be ready and tap twice to ensure it registers
        Thread.sleep(forTimeInterval: 1.0)
        saveButton.tap()
        Thread.sleep(forTimeInterval: 0.3)
        saveButton.tap()

        // Wait for sheet to dismiss by checking the text field is gone
        let start = Date()
        while textField.exists && Date().timeIntervalSince(start) < timeout {
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Wait for the add button to reappear (confirms we're back on the list)
        let addButtonCheck = app.buttons["Add symptom"]
        if !addButtonCheck.exists {
            let fallbackCheck = app.navigationBars.buttons.matching(NSPredicate(format: "identifier == 'plus' OR label == 'Add'")).firstMatch
            _ = fallbackCheck.waitForExistence(timeout: timeout)
        } else {
            _ = addButtonCheck.waitForExistence(timeout: timeout)
        }

        // Additional wait for Core Data to save and FetchRequest to refresh
        Thread.sleep(forTimeInterval: 1.5)

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
        // Check in cells first (List items appear as cells in the accessibility tree)
        let symptomCell = app.cells.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        if symptomCell.waitForExistence(timeout: timeout) {
            // Try to scroll to make it visible if it exists but isn't on screen
            if symptomCell.exists && !symptomCell.isHittable {
                symptomCell.scrollToVisible()
            }
            return true
        }

        // Check for the symptom name in static texts
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
