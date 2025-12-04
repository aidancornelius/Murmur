// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// TimelineScreen.swift
// Created by Aidan Cornelius-Bell on 06/10/2025.
// Page object for timeline screen.
//
import XCTest

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
        app.buttons[AccessibilityIdentifiers.settingsButton]
    }

    var analysisButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.analysisButton]
    }

    var timeline: XCUIElement {
        // In SwiftUI, List can appear as either a table or scrollView depending on iOS version
        // Try table first, then fall back to scrollView, then collectionView (iOS 17+)
        let table = app.tables.matching(identifier: AccessibilityIdentifiers.timelineList).firstMatch
        if table.exists {
            return table
        }
        let scrollView = app.scrollViews.matching(identifier: AccessibilityIdentifiers.timelineList).firstMatch
        if scrollView.exists {
            return scrollView
        }
        // iOS 17+ Lists with insetGrouped style may appear as collectionViews
        let collectionView = app.collectionViews.matching(identifier: AccessibilityIdentifiers.timelineList).firstMatch
        if collectionView.exists {
            return collectionView
        }
        // Fallback to any element with the identifier
        return app.otherElements.matching(identifier: AccessibilityIdentifiers.timelineList).firstMatch
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
        // If the timeline element with the identifier doesn't exist, fall back to using the first cell
        // or any scrollable element
        var scrollElement: XCUIElement?

        if timeline.exists {
            scrollElement = timeline
        } else if firstEntry.exists {
            // Use the first cell as the scroll element
            scrollElement = firstEntry
        } else {
            // Fall back to any table or scroll view
            scrollElement = app.tables.firstMatch.exists ? app.tables.firstMatch : app.scrollViews.firstMatch
        }

        guard let element = scrollElement, element.exists else {
            return
        }

        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
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
        // Check for actual entry cells (not the empty state cell)
        // Empty state is identified by the heart.text.square icon or the message text
        let emptyStateIcon = app.images["heart.text.square"]
        if emptyStateIcon.exists {
            return false
        }

        // Check if there are any actual timeline entries (entries have the entryCell identifier pattern)
        let entryCells = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'entry-cell-'"))
        return entryCells.count > 0
    }

    /// Get count of visible entries
    func entryCount() -> Int {
        // Count only actual entry cells, not section headers or empty state
        // Entry cells have identifiers that start with "entry-cell-"
        let entryCells = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'entry-cell-'"))
        return entryCells.count
    }

    /// Check if entry exists containing text
    func hasEntry(containing text: String) -> Bool {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch.exists
    }
}
