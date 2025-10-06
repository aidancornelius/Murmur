//
//  TimelineScreen.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest
@testable import Murmur

/// Page Object representing the main timeline screen
struct TimelineScreen {
    let app: XCUIApplication

    // MARK: - Elements

    var logSymptomButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.logSymptomButton]
    }

    var logEventButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.logEventButton]
    }

    var settingsButton: XCUIElement {
        app.navigationBars.buttons.matching(identifier: "gearshape").firstMatch
    }

    var analysisButton: XCUIElement {
        app.navigationBars.buttons["Analysis"]
    }

    var timeline: XCUIElement {
        app.scrollViews.firstMatch
    }

    var firstEntry: XCUIElement {
        app.cells.firstMatch
    }

    var allEntries: XCUIElementQuery {
        app.cells
    }

    // MARK: - Actions

    /// Wait for timeline to load
    @discardableResult
    func waitForLoad(timeout: TimeInterval = 5) -> Bool {
        logSymptomButton.waitForExistence(timeout: timeout)
    }

    /// Navigate to add entry screen
    func navigateToAddEntry() {
        logSymptomButton.tap()
    }

    /// Navigate to add event screen
    func navigateToAddEvent() {
        logEventButton.tap()
    }

    /// Navigate to settings
    func navigateToSettings() {
        settingsButton.tap()
    }

    /// Navigate to analysis
    func navigateToAnalysis() {
        analysisButton.tap()
    }

    /// Tap on a specific entry by index
    func tapEntry(at index: Int) {
        allEntries.element(boundBy: index).tap()
    }

    /// Tap on the first entry
    func tapFirstEntry() {
        firstEntry.tap()
    }

    /// Pull to refresh
    func pullToRefresh() {
        let start = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let end = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    /// Scroll timeline up
    func scrollUp(velocity: XCUIGestureVelocity = .default) {
        timeline.swipeUp(velocity: velocity)
    }

    /// Scroll timeline down
    func scrollDown(velocity: XCUIGestureVelocity = .default) {
        timeline.swipeDown(velocity: velocity)
    }

    // MARK: - Queries

    /// Check if timeline has entries
    func hasEntries() -> Bool {
        firstEntry.exists
    }

    /// Get count of visible entries
    func entryCount() -> Int {
        allEntries.count
    }

    /// Check if entry exists containing text
    func hasEntry(containing text: String) -> Bool {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch.exists
    }
}
