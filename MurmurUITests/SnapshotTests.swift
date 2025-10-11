//
//  SnapshotTests.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest

/// Visual regression tests capturing screenshots of app screens
/// Run these tests with Fastlane snapshot for consistent locale and device configuration
final class SnapshotTests: XCTestCase {
    var app: XCUIApplication?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Main Screens - Light Mode (7 snapshots)

    /// Captures timeline with populated data
    @MainActor
    func testTimelineSnapshot_Populated() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchForSnapshots()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should be visible")

        // Wait for entries to load
        Thread.sleep(forTimeInterval: 1.0)

        snapshot("01Timeline")
    }

    /// Captures timeline in empty state
    @MainActor
    func testTimelineSnapshot_Empty() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchEmpty()
        setupSnapshot(app)

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should be visible")

        snapshot("02TimelineEmpty")
    }

    /// Captures add entry screen
    @MainActor
    func testAddEntrySnapshot() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchForSnapshots()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, message: "Timeline should be visible")

        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        XCTAssertTrue(addEntry.waitForLoad(), "Add entry screen should load")

        snapshot("03AddSymptom")
    }

    /// Captures day detail view
    @MainActor
    func testDayDetailSnapshot() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchForSnapshots()

        _ = TimelineScreen(app: app)

        // Find and tap first entry to open day detail
        if app.cells.count > 0 {
            let firstEntry = app.cells.firstMatch
            firstEntry.tap()

            let dayDetail = DayDetailScreen(app: app)
            XCTAssertTrue(dayDetail.waitForLoad(), "Day detail screen should load")

            snapshot("04DayDetail")
        } else {
            XCTFail("No entries found in timeline")
        }
    }

    /// Captures analysis view with trends chart
    @MainActor
    func testAnalysisTrendsSnapshot() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchForSnapshots()

        // Navigate to analysis
        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis screen should load")

        // Ensure trends view is selected
        if app.buttons["Trends"].exists {
            app.buttons["Trends"].tap()
        }

        // Wait for chart to render and data to load
        Thread.sleep(forTimeInterval: 3.5)

        snapshot("04Analysis")
    }

    /// Captures analysis view with calendar heat map
    @MainActor
    func testAnalysisCalendarSnapshot() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchForSnapshots()

        // Navigate to analysis
        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis screen should load")

        // Switch to calendar view
        if app.buttons["Calendar"].exists {
            app.buttons["Calendar"].tap()
        }

        // Wait for calendar to render and data to load
        Thread.sleep(forTimeInterval: 3.5)

        snapshot("05AnalysisCalendar")
    }

    /// Captures settings screen
    @MainActor
    func testSettingsSnapshot() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchForSnapshots()

        // Navigate to settings
        app.buttons[AccessibilityIdentifiers.settingsButton].tap()

        let settings = SettingsScreen(app: app)
        XCTAssertTrue(settings.waitForLoad(), "Settings screen should load")

        snapshot("06Settings")
    }

    // MARK: - Main Screens - Dark Mode (7 snapshots)

    /// Captures timeline in dark mode
    @MainActor
    func testTimelineSnapshot_DarkMode() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchDarkMode()
        setupSnapshot(app)

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should be visible")

        Thread.sleep(forTimeInterval: 1.0)

        snapshot("07TimelineDark")
    }

    /// Captures add entry in dark mode
    @MainActor
    func testAddEntrySnapshot_DarkMode() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchDarkMode()
        setupSnapshot(app)

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        XCTAssertTrue(addEntry.waitForLoad(), "Add entry screen should load")

        snapshot("08AddSymptomDark")
    }

    /// Captures day detail in dark mode
    @MainActor
    func testDayDetailSnapshot_DarkMode() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchDarkMode()
        setupSnapshot(app)

        _ = TimelineScreen(app: app)

        if app.cells.count > 0 {
            let firstEntry = app.cells.firstMatch
            firstEntry.tap()

            let dayDetail = DayDetailScreen(app: app)
            XCTAssertTrue(dayDetail.waitForLoad(), "Day detail screen should load")

            snapshot("09DayDetailDark")
        }
    }

    /// Captures analysis trends in dark mode
    @MainActor
    func testAnalysisTrendsSnapshot_DarkMode() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchDarkMode()
        setupSnapshot(app)

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis screen should load")

        if app.buttons["Trends"].exists {
            app.buttons["Trends"].tap()
        }

        Thread.sleep(forTimeInterval: 3.5)

        snapshot("10AnalysisDark")
    }

    /// Captures analysis calendar in dark mode
    @MainActor
    func testAnalysisCalendarSnapshot_DarkMode() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchDarkMode()
        setupSnapshot(app)

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis screen should load")

        if app.buttons["Calendar"].exists {
            app.buttons["Calendar"].tap()
        }

        Thread.sleep(forTimeInterval: 3.5)

        snapshot("11AnalysisCalendarDark")
    }

    /// Captures settings in dark mode
    @MainActor
    func testSettingsSnapshot_DarkMode() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchDarkMode()
        setupSnapshot(app)

        app.buttons[AccessibilityIdentifiers.settingsButton].tap()

        let settings = SettingsScreen(app: app)
        XCTAssertTrue(settings.waitForLoad(), "Settings screen should load")

        snapshot("12SettingsDark")
    }

    /// Captures empty state in dark mode
    @MainActor
    func testEmptyStateSnapshot_DarkMode() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(
            scenario: .emptyState,
            appearance: .dark
        )
        setupSnapshot(app)

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should be visible")

        snapshot("13EmptyStateDark")
    }

    // MARK: - iPad Layouts (4 snapshots)

    /// Captures timeline on iPad
    @MainActor
    func testTimelineSnapshot_iPad() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        // Only run on iPad
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("iPad-only test")
        }

        app.launchForSnapshots()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should be visible")

        Thread.sleep(forTimeInterval: 1.0)

        snapshot("14TimelineIPad")
    }

    /// Captures analysis on iPad
    @MainActor
    func testAnalysisSnapshot_iPad() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("iPad-only test")
        }

        app.launchForSnapshots()

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis screen should load")

        Thread.sleep(forTimeInterval: 3.5)

        snapshot("15AnalysisIPad")
    }

    /// Captures add entry on iPad
    @MainActor
    func testAddEntrySnapshot_iPad() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("iPad-only test")
        }

        app.launchForSnapshots()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        XCTAssertTrue(addEntry.waitForLoad(), "Add entry screen should load")

        snapshot("16AddSymptomIPad")
    }

    /// Captures settings on iPad
    @MainActor
    func testSettingsSnapshot_iPad() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("iPad-only test")
        }

        app.launchForSnapshots()

        app.buttons[AccessibilityIdentifiers.settingsButton].tap()

        let settings = SettingsScreen(app: app)
        XCTAssertTrue(settings.waitForLoad(), "Settings screen should load")

        snapshot("17SettingsIPad")
    }

    // MARK: - Different States (6 snapshots)

    /// Captures loading state (if applicable)
    @MainActor
    func testLoadingStateSnapshot() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(
            scenario: .activeUser
        )
        setupSnapshot(app)

        // Trigger a view that shows loading
        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        // Capture immediately to catch loading state
        snapshot("18LoadingState", timeWaitingForIdle: 0)
    }

    /// Captures error states
    @MainActor
    func testErrorStateSnapshot() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(
            scenario: .activeUser,
            featureFlags: [.disableHealthKit]
        )
        setupSnapshot(app)

        // Navigate to settings and try to enable HealthKit to trigger error
        app.buttons[AccessibilityIdentifiers.settingsButton].tap()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        // Look for integrations section
        if app.buttons["Integrations"].exists {
            app.buttons["Integrations"].tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        snapshot("19ErrorState")
    }

    /// Captures various empty states
    @MainActor
    func testEmptyStatesSnapshot() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchEmpty()
        setupSnapshot(app)

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should be visible")

        snapshot("20EmptyStates")
    }

    /// Captures symptom entry with selections made
    @MainActor
    func testSymptomEntryWithSelectionsSnapshot() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchForSnapshots()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Make some selections
        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Headache")
        _ = addEntry.selectSymptom(named: "Headache")
        addEntry.setSeverity(3)
        addEntry.enterNote("Example note for screenshot")

        // Wait for UI to stabilise
        Thread.sleep(forTimeInterval: 0.5)

        snapshot("21SymptomEntryFilled")
    }

    /// Captures calendar view with full year of data
    @MainActor
    func testCalendarWithYearSnapshot() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(
            scenario: .heavyUser
        )
        setupSnapshot(app)

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis screen should load")

        // Switch to calendar view
        if app.buttons["Calendar"].exists {
            app.buttons["Calendar"].tap()
        }

        // Wait for full calendar to render and data to load
        Thread.sleep(forTimeInterval: 3.5)

        snapshot("22CalendarFullYear")
    }

    /// Captures load capacity tracking view
    @MainActor
    func testLoadCapacityViewSnapshot() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchForSnapshots()

        app.buttons[AccessibilityIdentifiers.analysisButton].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis screen should load")

        // Navigate to load capacity if available
        if app.buttons["Load Capacity"].exists {
            app.buttons["Load Capacity"].tap()
            Thread.sleep(forTimeInterval: 2.5)
        } else if app.staticTexts["Load Capacity"].exists {
            // Try scrolling to find it
            app.staticTexts["Load Capacity"].tap()
            Thread.sleep(forTimeInterval: 2.5)
        }

        snapshot("23LoadCapacity")
    }
}
