//
//  ExampleUserJourneyTest.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//
//  This is an example test demonstrating how to use the Page Object Model
//  infrastructure and test helpers.
//

import XCTest

final class ExampleUserJourneyTest: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Example: Basic symptom entry using Page Objects

    func testCompleteSymptomEntryFlow() throws {
        // Launch app with sample data
        app.launchWithData()

        // Create page objects
        let timeline = TimelineScreen(app: app)
        let addEntry = AddEntryScreen(app: app)

        // Wait for timeline to load
        assertExists(timeline.logSymptomButton, timeout: timeout(5))

        // Navigate to add entry
        timeline.navigateToAddEntry()

        // Wait for add entry screen
        addEntry.waitForLoad()

        // Complete symptom entry
        let success = addEntry.addSymptomEntry(
            symptom: "Headache",
            severity: 4,
            note: "Felt after long screen time"
        )

        XCTAssertTrue(success, "Should successfully add symptom entry")

        // Verify back on timeline
        assertExists(timeline.logSymptomButton, timeout: timeout(3))

        // Verify entry appears
        XCTAssertTrue(timeline.hasEntry(containing: "Headache"),
                     "Timeline should show new entry")
    }

    // MARK: - Example: Navigation flow with multiple screens

    func testNavigateToAnalysis() throws {
        // Launch with data
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        let analysis = AnalysisScreen(app: app)

        // Wait for load
        timeline.waitForLoad()

        // Navigate to analysis
        timeline.navigateToAnalysis()

        // Verify analysis screen loaded
        analysis.waitForLoad()

        // Switch between views
        analysis.switchToCalendar()
        XCTAssertTrue(analysis.isShowingCalendar(),
                     "Should show calendar view")

        analysis.switchToTrends()
        // Wait briefly for view to update
        Thread.sleep(forTimeInterval: 0.5)

        // Go back to timeline
        analysis.goBack()

        // Verify back on timeline
        assertExists(timeline.logSymptomButton)
    }

    // MARK: - Example: Settings workflow

    func testAddAndDeleteCustomSymptom() throws {
        // Launch with data
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        let settings = SettingsScreen(app: app)

        // Navigate to settings
        timeline.navigateToSettings()
        settings.waitForLoad()

        // Navigate to tracked symptoms
        settings.navigateToTrackedSymptoms()

        // Add custom symptom
        let success = settings.addSymptomType(name: "Test Custom Symptom")
        XCTAssertTrue(success, "Should add custom symptom")

        // Verify it exists
        XCTAssertTrue(settings.hasSymptomType(named: "Test Custom Symptom"),
                     "Custom symptom should appear in list")

        // Delete it
        let deleted = settings.deleteSymptomType(named: "Test Custom Symptom")
        XCTAssertTrue(deleted, "Should delete custom symptom")

        // Verify it's gone
        XCTAssertFalse(settings.hasSymptomType(named: "Test Custom Symptom"),
                      "Custom symptom should be removed")
    }

    // MARK: - Example: Using test helpers and assertions

    func testUsingHelpers() throws {
        app.launchWithData()

        let timeline = TimelineScreen(app: app)

        // Use assertExists helper
        assertExists(timeline.logSymptomButton,
                    timeout: timeout(5),
                    message: "Log button should exist on timeline")

        // Use assertHittable helper
        assertHittable(timeline.logSymptomButton,
                      message: "Log button should be tappable")

        // Tap when stable
        timeline.logSymptomButton.tapWhenStable()

        let addEntry = AddEntryScreen(app: app)

        // Use waitForLoad
        XCTAssertTrue(addEntry.waitForLoad(), "Add entry screen should load")

        // Cancel
        addEntry.cancel()

        // Wait for disappearance
        waitForDisappearance(addEntry.cancelButton, timeout: timeout(3))
    }

    // MARK: - Example: Different launch states

    func testEmptyState() throws {
        // Launch with empty state
        app.launchEmpty()

        let timeline = TimelineScreen(app: app)
        timeline.waitForLoad()

        // Verify no entries
        XCTAssertFalse(timeline.hasEntries(),
                      "Timeline should have no entries")

        // Verify log button still exists
        assertExists(timeline.logSymptomButton)
    }

    func testDarkMode() throws {
        // Launch in dark mode
        app.launchDarkMode()

        let timeline = TimelineScreen(app: app)
        timeline.waitForLoad()

        // App should work normally in dark mode
        assertExists(timeline.logSymptomButton)
    }

    func testAccessibilityLargeText() throws {
        // Launch with large accessibility text
        app.launchForAccessibility(contentSize: .accessibilityExtraLarge)

        let timeline = TimelineScreen(app: app)
        timeline.waitForLoad()

        // Verify UI adapts
        assertExists(timeline.logSymptomButton)

        // Take screenshot for visual verification
        takeScreenshot(named: "Timeline-AccessibilityLarge")
    }

    // MARK: - Example: Custom launch configuration

    func testCustomConfiguration() throws {
        // Launch with custom settings
        app.launch(
            scenario: .activeUser,
            appearance: .dark,
            contentSize: .large,
            featureFlags: [.disableHealthKit, .enableDebugLogging]
        )

        let timeline = TimelineScreen(app: app)
        timeline.waitForLoad()

        assertExists(timeline.logSymptomButton)
    }

    // MARK: - Example: Retry mechanism

    func testWithRetry() throws {
        app.launchWithData()

        let timeline = TimelineScreen(app: app)

        // Retry an action that might be flaky
        let success = retry(attempts: 3, delay: 0.5) {
            timeline.logSymptomButton.exists && timeline.logSymptomButton.isHittable
        }

        XCTAssertTrue(success, "Should find log button within retry attempts")
    }

    // MARK: - Example: Day detail navigation

    func testDayDetailNavigation() throws {
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        let dayDetail = DayDetailScreen(app: app)

        timeline.waitForLoad()

        // Tap first entry to go to day detail
        if timeline.hasEntries() {
            timeline.tapFirstEntry()

            // Verify day detail loaded
            dayDetail.waitForLoad()

            // Verify has entries
            XCTAssertTrue(dayDetail.hasEntries(),
                         "Day should have entries")

            // Go back
            dayDetail.goBack()

            // Verify back on timeline
            assertExists(timeline.logSymptomButton)
        }
    }

    // MARK: - Example: Pull to refresh

    func testPullToRefresh() throws {
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.waitForLoad()

        // Pull to refresh
        timeline.pullToRefresh()

        // Wait briefly for refresh animation
        Thread.sleep(forTimeInterval: 1.0)

        // Verify still on timeline
        assertExists(timeline.logSymptomButton)
    }

    // MARK: - Example: Using XCUIElement extensions

    func testElementExtensions() throws {
        app.launchWithData()

        let timeline = TimelineScreen(app: app)

        // Wait for element to be hittable
        let isHittable = timeline.logSymptomButton.waitForHittable(timeout: 5)
        XCTAssertTrue(isHittable, "Button should become hittable")

        // Tap when hittable
        let tapped = timeline.logSymptomButton.tapWhenHittable()
        XCTAssertTrue(tapped, "Should tap button when hittable")

        let addEntry = AddEntryScreen(app: app)

        // Wait for specific label
        if addEntry.severitySlider.exists {
            addEntry.severitySlider.adjustSliderToLevel(4, maxLevel: 5)
        }

        // Cancel
        addEntry.cancel()
    }
}
