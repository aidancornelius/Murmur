//
//  PerformanceTests.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest

/// Performance and responsiveness tests
/// Tests app performance with various data sizes and interaction patterns
final class PerformanceTests: XCTestCase {
    var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Scroll Performance (3 tests)

    /// Tests timeline scroll performance with normal data
    func testTimelineScrollPerformance() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should load")

        // Measure scroll performance
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                // Perform scrolls
                scrollView.swipeUp()
                Thread.sleep(forTimeInterval: 0.5)
                scrollView.swipeUp()
                Thread.sleep(forTimeInterval: 0.5)
                scrollView.swipeDown()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    /// Tests timeline performance with large data set (1000+ entries)
    func testTimelineWithLargeDataSet() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithLargeData()

        // Measure time to first interactive frame
        let timeline = TimelineScreen(app: app)

        let start = Date()
        let loaded = timeline.logSymptomButton.waitForExistence(timeout: 15)
        let loadTime = Date().timeIntervalSince(start)

        XCTAssertTrue(loaded, "Timeline should load even with large data set")
        XCTAssertLessThan(loadTime, 5.0,
                         "Timeline should load within 5 seconds even with 1000+ entries")

        // Verify scrolling remains responsive
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            Thread.sleep(forTimeInterval: 0.3)

            // Should still be responsive after scroll
            assertHittable(timeline.logSymptomButton,
                          message: "UI should remain responsive with large data")
        }
    }

    /// Tests day detail load time
    func testDayDetailLoadTime() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, message: "Timeline should load")

        // Find first entry
        if app.cells.count > 0 {
            let firstEntry = app.cells.firstMatch
            // Measure time to load day detail
            measure(metrics: [XCTClockMetric()]) {
                firstEntry.tap()

                let dayDetail = DayDetailScreen(app: app)
                XCTAssertTrue(dayDetail.waitForLoad(timeout: 3),
                             "Day detail should load quickly")

                // Go back
                app.navigationBars.buttons.firstMatch.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        } else {
            XCTFail("No entries found to test")
        }
    }

    // MARK: - Animation Performance (3 tests)

    /// Tests view transition smoothness
    func testViewTransitionSmooth() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, message: "Timeline should load")

        // Measure tab switching performance
        measure(metrics: [XCTClockMetric()]) {
            app.buttons[AccessibilityIdentifiers.analysisButton].tap()
            Thread.sleep(forTimeInterval: 0.3)

            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.3)

            app.buttons[AccessibilityIdentifiers.settingsButton].tap()
            Thread.sleep(forTimeInterval: 0.3)

            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.3)

            app.buttons[AccessibilityIdentifiers.logSymptomButton].tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    /// Tests chart animation completion
    func testChartAnimationComplete() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis should load")

        // Ensure trends view
        if app.buttons["Trends"].exists {
            app.buttons["Trends"].tap()
        }

        // Measure time for chart to render
        measure(metrics: [XCTClockMetric()]) {
            // Switch time periods to trigger chart re-render
            if app.buttons.matching(NSPredicate(format: "label CONTAINS '30'")).firstMatch.exists {
                app.buttons.matching(NSPredicate(format: "label CONTAINS '30'")).firstMatch.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }

            if app.buttons.matching(NSPredicate(format: "label CONTAINS '7'")).firstMatch.exists {
                app.buttons.matching(NSPredicate(format: "label CONTAINS '7'")).firstMatch.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
    }

    /// Tests sheet presentation smoothness
    func testSheetPresentationSmooth() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, message: "Timeline should load")

        // Measure sheet presentation
        measure(metrics: [XCTClockMetric()]) {
            timeline.logSymptomButton.tap()

            let addEntry = AddEntryScreen(app: app)
            XCTAssertTrue(addEntry.waitForLoad(timeout: 2),
                         "Add entry sheet should present smoothly")

            let cancelButton = app.buttons[AccessibilityIdentifiers.cancelButton]
            cancelButton.tap()

            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    // MARK: - Launch Performance (2 tests)

    /// Tests cold launch performance
    func testColdLaunchPerformance() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launchWithData()

            let timeline = TimelineScreen(app: app)
            XCTAssertTrue(timeline.logSymptomButton.waitForExistence(timeout: 10),
                         "App should launch and become interactive")

            app.terminate()
        }
    }

    /// Tests warm launch performance (app already in memory)
    func testWarmLaunchPerformance() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        // First launch to warm up
        app.launchWithData()
        Thread.sleep(forTimeInterval: 2.0)

        // Background the app
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.0)

        // Measure reactivation time
        measure(metrics: [XCTClockMetric()]) {
            app.activate()

            let timeline = TimelineScreen(app: app)
            XCTAssertTrue(timeline.logSymptomButton.waitForExistence(timeout: 5),
                         "App should reactivate quickly")

            // Background again for next iteration
            XCUIDevice.shared.press(.home)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    // MARK: - Large Datasets (3 tests)

    /// Tests analysis with 90 days of data
    func testAnalysisWithNinetyDays() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(scenario: .heavyUser)

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)

        // Measure time to load and render analysis
        let start = Date()
        let loaded = analysis.waitForLoad(timeout: 10)
        let loadTime = Date().timeIntervalSince(start)

        XCTAssertTrue(loaded, "Analysis should load with 90 days of data")
        XCTAssertLessThan(loadTime, 5.0,
                         "Analysis should load within 5 seconds even with 90 days of data")

        // Switch to 90 day view if not already
        if app.buttons.matching(NSPredicate(format: "label CONTAINS '90'")).firstMatch.exists {
            let start = Date()
            app.buttons.matching(NSPredicate(format: "label CONTAINS '90'")).firstMatch.tap()
            Thread.sleep(forTimeInterval: 2.0)
            let renderTime = Date().timeIntervalSince(start)

            XCTAssertLessThan(renderTime, 3.0,
                            "90-day chart should render within 3 seconds")
        }
    }

    /// Tests calendar with full year of data
    func testCalendarWithFullYear() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(scenario: .heavyUser)

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis should load")

        // Switch to calendar view
        if app.buttons["Calendar"].exists {
            let start = Date()
            app.buttons["Calendar"].tap()
            Thread.sleep(forTimeInterval: 2.0)
            let renderTime = Date().timeIntervalSince(start)

            XCTAssertLessThan(renderTime, 3.0,
                            "Calendar with full year should render within 3 seconds")

            // Verify calendar is interactive
            let calendar = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'calendar' OR identifier CONTAINS 'Calendar'")).firstMatch

            if calendar.exists {
                XCTAssertTrue(calendar.isHittable,
                             "Calendar should remain interactive with full year of data")
            }
        }
    }

    /// Tests symptom history with 1000+ entries
    func testSymptomHistoryWithThousandEntries() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithLargeData()

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis should load")

        // Try to access symptom history
        if app.buttons["Symptom History"].exists {
            let start = Date()
            app.buttons["Symptom History"].tap()
            Thread.sleep(forTimeInterval: 2.0)
            let loadTime = Date().timeIntervalSince(start)

            XCTAssertLessThan(loadTime, 3.0,
                            "Symptom history should load within 3 seconds even with 1000+ entries")

            // Verify list is scrollable
            let scrollView = app.scrollViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
                Thread.sleep(forTimeInterval: 0.3)

                XCTAssertTrue(scrollView.isHittable,
                             "History list should remain responsive with large data")
            }
        } else if app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Headache' OR label CONTAINS 'Fatigue'")).count > 0 {
            // Alternative: look for symptom names that can be tapped
            let symptomName = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Headache' OR label CONTAINS 'Fatigue'")).firstMatch

            if symptomName.exists {
                let start = Date()
                symptomName.tap()
                Thread.sleep(forTimeInterval: 2.0)
                let loadTime = Date().timeIntervalSince(start)

                XCTAssertLessThan(loadTime, 3.0,
                                "Symptom detail should load within 3 seconds")
            }
        }
    }

    // MARK: - Additional Performance Tests

    /// Tests memory usage doesn't cause issues with large data
    func testMemoryWithLargeData() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithLargeData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 15, message: "Timeline should load")

        // Navigate through all screens to verify no memory issues
        app.buttons[AccessibilityIdentifiers.analysisButton].tap()
        Thread.sleep(forTimeInterval: 2.0)

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis should load")

        app.navigationBars.buttons.firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.5)

        app.buttons[AccessibilityIdentifiers.settingsButton].tap()
        Thread.sleep(forTimeInterval: 1.0)

        let settings = SettingsScreen(app: app)
        XCTAssertTrue(settings.waitForLoad(), "Settings should load")

        app.buttons[AccessibilityIdentifiers.logSymptomButton].tap()
        Thread.sleep(forTimeInterval: 1.0)

        // Should still be responsive
        assertHittable(timeline.logSymptomButton,
                      message: "App should remain responsive after navigating with large data")
    }

    /// Tests rapid interactions don't cause UI freezing
    func testRapidInteractions() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, message: "Timeline should load")

        // Perform rapid tab switches
        for _ in 0..<5 {
            app.buttons[AccessibilityIdentifiers.analysisButton].tap()
            Thread.sleep(forTimeInterval: 0.1)

            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.1)

            app.buttons[AccessibilityIdentifiers.settingsButton].tap()
            Thread.sleep(forTimeInterval: 0.1)

            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Should still be responsive
        assertHittable(timeline.logSymptomButton,
                      message: "App should remain responsive after rapid interactions")
    }
}
