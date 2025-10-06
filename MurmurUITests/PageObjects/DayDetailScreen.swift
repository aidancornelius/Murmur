//
//  DayDetailScreen.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest
@testable import Murmur

/// Page Object representing the day detail screen
struct DayDetailScreen {
    let app: XCUIApplication

    // MARK: - Elements

    var backButton: XCUIElement {
        app.navigationBars.buttons.element(boundBy: 0)
    }

    var addButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'plus' OR label CONTAINS 'Add'")).firstMatch
    }

    var allEntries: XCUIElementQuery {
        app.cells
    }

    var firstEntry: XCUIElement {
        app.cells.firstMatch
    }

    // MARK: - Actions

    /// Wait for day detail screen to load
    @discardableResult
    func waitForLoad(timeout: TimeInterval = 5) -> Bool {
        backButton.waitForExistence(timeout: timeout)
    }

    /// Go back to timeline
    func goBack() {
        backButton.tap()
    }

    /// Add new entry for this day
    func addEntry() {
        if addButton.exists {
            addButton.tap()
        }
    }

    /// Tap on an entry at specific index
    func tapEntry(at index: Int) {
        allEntries.element(boundBy: index).tap()
    }

    /// Tap on first entry
    func tapFirstEntry() {
        firstEntry.tap()
    }

    /// Swipe to delete entry at index
    func deleteEntry(at index: Int, timeout: TimeInterval = 2) -> Bool {
        let entry = allEntries.element(boundBy: index)
        guard entry.exists else { return false }

        entry.swipeLeft()

        let deleteButton = app.buttons["Delete"]
        guard deleteButton.waitForExistence(timeout: timeout) else {
            return false
        }
        deleteButton.tap()

        return true
    }

    // MARK: - Queries

    /// Check if day has entries
    func hasEntries() -> Bool {
        firstEntry.exists
    }

    /// Get count of entries
    func entryCount() -> Int {
        allEntries.count
    }

    /// Check if specific symptom entry exists
    func hasEntry(for symptom: String) -> Bool {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", symptom)).firstMatch.exists
    }

    /// Get day title (date)
    func getDayTitle() -> String? {
        let navBar = app.navigationBars.firstMatch
        guard navBar.exists else { return nil }
        return navBar.identifier
    }
}
