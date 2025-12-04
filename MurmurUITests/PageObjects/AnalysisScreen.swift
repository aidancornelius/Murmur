// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// AnalysisScreen.swift
// Created by Aidan Cornelius-Bell on 06/10/2025.
// Page object for analysis screen.
//
import XCTest

/// Page Object representing the analysis screen
struct AnalysisScreen {
    let app: XCUIApplication

    // MARK: - Elements

    var backButton: XCUIElement {
        app.navigationBars.buttons.element(boundBy: 0)
    }

    var viewSelectorMenu: XCUIElement {
        app.buttons[AccessibilityIdentifiers.analysisViewSelector]
    }

    // View type buttons in menu
    var trendsButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.analysisTrendsButton]
    }

    var calendarButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.analysisCalendarButton]
    }

    var historyButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.analysisHistoryButton]
    }

    var activitiesButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.analysisActivitiesButton]
    }

    var patternsButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.analysisPatternsButton]
    }

    var healthButton: XCUIElement {
        app.buttons[AccessibilityIdentifiers.analysisHealthButton]
    }

    // Tab buttons (if using tab-based navigation)
    var trendsTab: XCUIElement {
        app.buttons["Trends"]
    }

    // MARK: - Actions

    /// Wait for analysis screen to load
    @discardableResult
    func waitForLoad(timeout: TimeInterval = 5) -> Bool {
        trendsTab.waitForExistence(timeout: timeout) ||
        viewSelectorMenu.waitForExistence(timeout: timeout)
    }

    /// Go back to previous screen
    func goBack() {
        backButton.tap()
    }

    /// Switch to trends view
    func switchToTrends() {
        openViewSelector()
        trendsButton.tap()
    }

    /// Switch to calendar heat map view
    func switchToCalendar() {
        openViewSelector()
        calendarButton.tap()
    }

    /// Switch to history view
    func switchToHistory() {
        openViewSelector()
        historyButton.tap()
    }

    /// Switch to activities view
    func switchToActivities() {
        openViewSelector()
        activitiesButton.tap()
    }

    /// Switch to patterns view
    func switchToPatterns() {
        openViewSelector()
        patternsButton.tap()
    }

    /// Switch to health view
    func switchToHealth() {
        openViewSelector()
        healthButton.tap()
    }

    /// Open view selector menu
    private func openViewSelector() {
        if viewSelectorMenu.exists && !trendsButton.exists {
            viewSelectorMenu.tap()
        }
    }

    /// Change time period (7/30/90 days)
    func selectTimePeriod(_ days: Int) {
        let button = app.buttons["\(days) days"]
        if button.exists {
            button.tap()
        }
    }

    // MARK: - Queries

    /// Check if showing trends view
    func isShowingTrends() -> Bool {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'trend' OR label CONTAINS 'Trend'")).firstMatch.exists
    }

    /// Check if showing calendar view
    func isShowingCalendar() -> Bool {
        // Look for month labels or calendar grid
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS '2025' OR label CONTAINS '2024'")).firstMatch.exists
    }

    /// Check if showing empty state
    func hasEmptyState() -> Bool {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'No data' OR label CONTAINS 'insufficient'")).firstMatch.exists
    }

    /// Check if chart is visible
    func hasChart() -> Bool {
        // Charts typically have accessibility labels
        app.otherElements.containing(NSPredicate(format: "identifier CONTAINS 'chart'")).firstMatch.exists
    }

    /// Get visible trend labels (e.g., "Improving", "Worsening")
    func getTrendLabels() -> [String] {
        let improvingLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Improving'")).firstMatch
        let worseningLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Worsening'")).firstMatch

        var labels: [String] = []
        if improvingLabel.exists {
            labels.append(improvingLabel.label)
        }
        if worseningLabel.exists {
            labels.append(worseningLabel.label)
        }
        return labels
    }
}
