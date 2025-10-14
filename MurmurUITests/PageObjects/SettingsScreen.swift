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
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        // Try to find the add button by accessibility label first (more reliable)
        let addButton = app.buttons["Add symptom"]
        if !addButton.exists {
            // Fallback to searching by identifier
            let fallbackButton = app.navigationBars.buttons.matching(NSPredicate(format: "identifier == 'plus' OR label == 'Add'")).firstMatch
            guard fallbackButton.waitForExistence(timeout: timeout) else {
                return false
            }
            // Ensure button is fully ready using predicate
            guard fallbackButton.waitForHittable(timeout: timeout) else {
                return false
            }
            fallbackButton.tap()

            // Wait for text field to appear
            let textField = app.textFields.firstMatch
            if !textField.waitForExistence(timeout: 1.0) {
                // Second tap if needed
                fallbackButton.tap()
            }
        } else {
            // Ensure button is fully ready using predicate
            guard addButton.waitForHittable(timeout: timeout) else {
                return false
            }
            addButton.tap()

            // Wait for text field to appear
            let textField = app.textFields.firstMatch
            if !textField.waitForExistence(timeout: 1.0) {
                // Second tap if needed
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

        // Wait for button to be ready using predicate
        guard saveButton.waitForHittable(timeout: 2.0) else {
            return false
        }
        saveButton.tap()

        // Try second tap if sheet doesn't dismiss
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        if textField.exists {
            saveButton.tap()
        }

        // Wait for sheet to dismiss using predicate
        _ = textField.waitForDisappearance(timeout: timeout)

        // Wait for the add button to reappear (confirms we're back on the list)
        let addButtonCheck = app.buttons["Add symptom"]
        if !addButtonCheck.exists {
            let fallbackCheck = app.navigationBars.buttons.matching(NSPredicate(format: "identifier == 'plus' OR label == 'Add'")).firstMatch
            _ = fallbackCheck.waitForExistence(timeout: timeout)
        } else {
            _ = addButtonCheck.waitForExistence(timeout: timeout)
        }

        // Additional wait for Core Data to save and FetchRequest to refresh
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))

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

        // Tap the swipe action delete button
        let swipeDeleteButton = app.buttons["Delete"]
        guard swipeDeleteButton.waitForExistence(timeout: 2) else {
            return false
        }
        swipeDeleteButton.tap()

        // Wait for confirmation alert to appear
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        // Tap the confirmation dialog delete button
        let confirmDeleteButton = app.buttons["Delete"]
        guard confirmDeleteButton.waitForExistence(timeout: 2) else {
            return false
        }
        confirmDeleteButton.tap()

        // Wait for deletion to complete and Core Data to update
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        return true
    }

    // MARK: - Queries

    /// Check if a specific setting option exists
    func hasSettingOption(_ name: String) -> Bool {
        app.buttons[name].exists || app.staticTexts[name].exists
    }

    /// Check if symptom type exists
    func hasSymptomType(named name: String, timeout: TimeInterval = 5) -> Bool {
        // Use a polling approach to wait for the UI to stabilize
        // This handles both checking for appearance (when adding) and disappearance (when deleting)
        let endTime = Date().addingTimeInterval(timeout)
        var lastCheckResult = false

        while Date() < endTime {
            // Check in cells first (List items appear as cells in the accessibility tree)
            let symptomCell = app.cells.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
            if symptomCell.exists {
                lastCheckResult = true
                // If found, give it a brief moment to confirm it's stable
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
                if symptomCell.exists {
                    return true
                }
            }

            // Check for the symptom name in static texts
            let symptomText = app.staticTexts[name]
            if symptomText.exists {
                return true
            }

            // Check in links (NavigationLinks appear as links in the accessibility tree)
            let symptomLink = app.links.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
            if symptomLink.exists {
                return true
            }

            let symptomButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
            if symptomButton.exists {
                return true
            }

            let symptomElement = app.otherElements.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
            if symptomElement.exists {
                return true
            }

            // Not found, wait a bit before checking again
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return false
    }
}
