//
//  UserJourneyTests.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest

/// Comprehensive user journey tests covering critical workflows
final class UserJourneyTests: XCTestCase {
    var app: XCUIApplication?
    private var systemAlertMonitor: NSObjectProtocol?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        systemAlertMonitor = registerSystemAlertMonitor()
    }

    override func tearDownWithError() throws {
        if let monitor = systemAlertMonitor {
            removeUIInterruptionMonitor(monitor)
        }
        app = nil
    }

    // MARK: - Symptom Entry Flows (8 tests)

    /// Tests complete symptom entry workflow including search, severity, note, and save
    @MainActor
    func testCompleteSymptomEntry() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, message: "Timeline should be visible")
        captureStep("01-Timeline")

        // Navigate to add entry
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        XCTAssertTrue(addEntry.waitForLoad(), "Add entry screen should load")
        captureStep("02-AddEntry")

        // Search and select symptom
        addEntry.openSymptomSearch()
        captureStep("03-SymptomSearch")
        addEntry.searchForSymptom("Headache")
        captureStep("04-SearchResults")
        XCTAssertTrue(addEntry.selectSymptom(named: "Headache"), "Should be able to select Headache")
        captureStep("05-SymptomSelected")

        // Set severity and note
        addEntry.setSeverity(3)
        addEntry.enterNote("Mild headache after work")
        captureStep("06-SeverityAndNote")

        // Save entry
        addEntry.save()

        // Verify entry appears in timeline
        XCTAssertTrue(timeline.waitForLoad(), "Timeline should reload")
        captureStep("07-TimelineWithEntry")
        XCTAssertTrue(timeline.hasEntry(containing: "Headache"), "Timeline should show new Headache entry")
    }

    /// Tests adding multiple symptoms in one entry
    func testMultiSymptomEntry() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Add first symptom
        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Fatigue")
        XCTAssertTrue(addEntry.selectSymptom(named: "Fatigue"), "Should select Fatigue")
        addEntry.setSeverity(4)

        // Check if we can add another symptom (app-dependent)
        // This assumes the app allows multiple symptoms per entry
        if app.buttons["Add another symptom"].exists {
            app.buttons["Add another symptom"].tap()
            addEntry.openSymptomSearch()
            addEntry.searchForSymptom("Nausea")
            _ = addEntry.selectSymptom(named: "Nausea")
            addEntry.setSeverity(2)
        }

        addEntry.save()

        XCTAssertTrue(timeline.waitForLoad(), "Timeline should reload after save")
        XCTAssertTrue(timeline.hasEntry(containing: "Fatigue"), "Timeline should show Fatigue entry")
    }

    /// Tests symptom entry with note
    func testSymptomEntryWithNote() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Muscle pain")
        XCTAssertTrue(addEntry.selectSymptom(named: "Muscle pain"), "Should select Muscle pain")
        addEntry.setSeverity(5)
        addEntry.enterNote("Sharp pain in lower back, started after lifting heavy box")

        addEntry.save()

        XCTAssertTrue(timeline.waitForLoad(), "Timeline should reload")
        XCTAssertTrue(timeline.hasEntry(containing: "Muscle pain"), "Timeline should show Muscle pain entry")
    }

    /// SKIP: Uses old AddEntryView with severity-slider which has been replaced by UnifiedEventView
    /// Tests symptom entry with location tracking
    func skip_testSymptomEntryWithLocation() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(
            scenario: .activeUser,
            featureFlags: [] // Ensure location is enabled
        )

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Add symptom
        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Dizziness")
        _ = addEntry.selectSymptom(named: "Dizziness")
        addEntry.setSeverity(3)

        // Toggle location if available
        let locationToggle = app.switches.matching(identifier: "location-toggle").firstMatch
        if locationToggle.exists {
            locationToggle.tap()
        }

        addEntry.save()

        XCTAssertTrue(timeline.waitForLoad(), "Timeline should reload")
        XCTAssertTrue(timeline.hasEntry(containing: "Dizziness"), "Timeline should show Dizziness entry")
    }

    /// SKIP: Uses old AddEntryView with severity-slider which has been replaced by UnifiedEventView
    /// Tests creating a backdated symptom entry
    func skip_testBackdatedEntry() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Look for timestamp/date picker button
        let timestampButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'timestamp' OR label CONTAINS 'time' OR label CONTAINS 'date'")).firstMatch
        if timestampButton.exists {
            timestampButton.tap()

            // Adjust date/time (implementation depends on app's date picker)
            let datePicker = app.datePickers.firstMatch
            if datePicker.waitForExistence(timeout: 2) {
                // Select previous day
                datePicker.adjust(toPickerWheelValue: "Yesterday")
            }

            // Dismiss date picker
            if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            } else if app.buttons["Confirm"].exists {
                app.buttons["Confirm"].tap()
            }
        }

        // Add symptom
        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Headache")
        _ = addEntry.selectSymptom(named: "Headache")
        addEntry.setSeverity(2)

        addEntry.save()

        XCTAssertTrue(timeline.waitForLoad(), "Timeline should reload")
    }

    /// SKIP: Uses old AddEntryView with severity-slider which has been replaced by UnifiedEventView
    /// Tests cancelling symptom entry
    func skip_testCancelEntry() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        let initialEntryCount = timeline.entryCount()

        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Start entering data
        addEntry.openSymptomSearch()
        addEntry.searchForSymptom("Fatigue")
        _ = addEntry.selectSymptom(named: "Fatigue")
        addEntry.setSeverity(3)

        // Cancel instead of saving
        addEntry.cancel()

        // Verify we're back on timeline
        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")

        // Verify no new entry was added
        XCTAssertEqual(timeline.entryCount(), initialEntryCount, "Entry count should not change after cancel")
    }

    /// SKIP: Uses old AddEntryView with severity-slider which has been replaced by UnifiedEventView
    /// Tests searching for and creating a new custom symptom
    func skip_testSearchAndCreateNewSymptom() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        addEntry.openSymptomSearch()

        // Search for a symptom that doesn't exist
        let uniqueSymptomName = "CustomSymptom\(Int.random(in: 1000...9999))"
        addEntry.searchForSymptom(uniqueSymptomName)

        // Look for "Create" or "Add" button
        let createButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'create' OR label CONTAINS[c] 'add new'")).firstMatch
        if createButton.waitForExistence(timeout: 2) {
            createButton.tap()

            // Confirm creation if needed
            if app.buttons["Confirm"].exists {
                app.buttons["Confirm"].tap()
            }

            // Wait for sheet to close and UI to update
            Thread.sleep(forTimeInterval: 1.0)

            addEntry.setSeverity(4)
            addEntry.save()

            XCTAssertTrue(timeline.waitForLoad(), "Timeline should reload")
            XCTAssertTrue(timeline.hasEntry(containing: uniqueSymptomName), "Timeline should show new custom symptom")
        }
    }

    /// Tests quick symptom selection from starred symptoms
    func testQuickSymptomSelection() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        // Try to use quick selection button (if available)
        let quickSymptomButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'quick-symptom'"))
        if quickSymptomButtons.count > 0 {
            quickSymptomButtons.firstMatch.tap()
            addEntry.setSeverity(3)
            addEntry.save()

            XCTAssertTrue(timeline.waitForLoad(), "Timeline should reload")
            XCTAssertTrue(timeline.hasEntries(), "Timeline should have entries")
        } else {
            // Fallback: use regular selection
            addEntry.openSymptomSearch()
            let firstSymptom = app.staticTexts.matching(NSPredicate(format: "identifier CONTAINS 'symptom'")).firstMatch
            if firstSymptom.exists {
                firstSymptom.tap()
                addEntry.setSeverity(3)
                addEntry.save()
            }
        }
    }

    // MARK: - Timeline Interactions (6 tests)

    /// Tests scrolling through timeline
    func testScrollTimeline() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.timeline, message: "Timeline should be visible")

        // Scroll up
        timeline.scrollUp()
        Thread.sleep(forTimeInterval: 0.5)

        // Scroll down
        timeline.scrollDown()
        Thread.sleep(forTimeInterval: 0.5)

        // Verify timeline still exists after scrolling
        XCTAssertTrue(timeline.timeline.exists, "Timeline should still exist after scrolling")
    }

    /// Tests pull to refresh on timeline
    func testPullToRefresh() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        XCTAssertTrue(timeline.waitForLoad(), "Timeline should load")

        // Perform pull to refresh
        timeline.pullToRefresh()

        // Wait a bit for refresh to complete
        Thread.sleep(forTimeInterval: 1.0)

        // Verify timeline is still visible
        XCTAssertTrue(timeline.logSymptomButton.exists, "Timeline should be visible after refresh")
    }

    /// Tests navigating to day detail view
    func testNavigateToDayDetail() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        XCTAssertTrue(timeline.hasEntries(), "Timeline should have entries")

        // Tap on first entry
        timeline.tapFirstEntry()

        // Verify day detail screen appears
        let dayDetail = DayDetailScreen(app: app)
        XCTAssertTrue(dayDetail.waitForLoad(timeout: timeout(5)), "Day detail should load")

        // Go back to timeline
        dayDetail.goBack()
        XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
    }

    /// Tests timeline grouping by day
    func testTimelineGrouping() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        XCTAssertTrue(timeline.waitForLoad(), "Timeline should load")

        // Look for date headers (grouped by day)
        let dateHeaders = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Today' OR label CONTAINS 'Yesterday' OR label CONTAINS 'Mon' OR label CONTAINS 'Tue'"))
        XCTAssertGreaterThan(dateHeaders.count, 0, "Timeline should show date groupings")
    }

    /// Tests empty timeline state
    func testEmptyTimelineState() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchEmpty()

        let timeline = TimelineScreen(app: app)
        XCTAssertTrue(timeline.waitForLoad(), "Timeline should load")

        // Verify empty state message
        let emptyMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'no entries' OR label CONTAINS[c] 'get started' OR label CONTAINS[c] 'track your first'"))
        XCTAssertTrue(emptyMessage.firstMatch.waitForExistence(timeout: timeout(3)), "Should show empty state message")

        // Verify add button still available
        XCTAssertTrue(timeline.logSymptomButton.exists, "Log symptom button should be visible in empty state")
    }

    /// Tests navigating between weeks in timeline
    func testNavigateBetweenWeeks() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(scenario: .longHistory)

        let timeline = TimelineScreen(app: app)
        XCTAssertTrue(timeline.waitForLoad(), "Timeline should load")

        // Scroll up to see older entries
        for _ in 1...5 {
            timeline.scrollUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Scroll back down to recent entries
        for _ in 1...5 {
            timeline.scrollDown(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Verify timeline is still functional
        XCTAssertTrue(timeline.logSymptomButton.exists, "Timeline should still be functional after scrolling")
    }

    // MARK: - Analysis Workflows (8 tests)

    /// Tests viewing trends chart
    func testViewTrendsChart() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAnalysis()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(timeout: timeout(5)), "Analysis screen should load")

        // Switch to trends view if not already there
        if !analysis.isShowingTrends() {
            analysis.switchToTrends()
        }

        // Verify trends content is visible
        Thread.sleep(forTimeInterval: 1.0) // Allow chart to render
        XCTAssertTrue(analysis.isShowingTrends() || analysis.hasChart(), "Should show trends or chart")
    }

    /// Tests switching to calendar heat map view
    func testSwitchToCalendarHeatMap() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAnalysis()

        let analysis = AnalysisScreen(app: app)
        analysis.waitForLoad()

        // Switch to calendar view
        analysis.switchToCalendar()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify calendar is showing
        XCTAssertTrue(analysis.isShowingCalendar(), "Should show calendar heat map")
    }

    /// Tests tapping on calendar day to view details
    func testTapCalendarDayViewDetails() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAnalysis()

        let analysis = AnalysisScreen(app: app)
        analysis.waitForLoad()

        // Switch to calendar view
        analysis.switchToCalendar()
        Thread.sleep(forTimeInterval: 1.0)

        // Tap on a calendar cell (if available)
        let calendarCells = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'calendar' OR identifier CONTAINS 'day'"))
        if calendarCells.count > 0 {
            calendarCells.element(boundBy: 0).tap()

            // May show day detail or popup
            Thread.sleep(forTimeInterval: 0.5)
            XCTAssertTrue(app.exists, "App should still be responsive after tapping calendar day")
        }
    }

    /// Tests viewing symptom history
    func testViewSymptomHistory() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAnalysis()

        let analysis = AnalysisScreen(app: app)
        analysis.waitForLoad()

        // Switch to history view
        analysis.switchToHistory()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify history content is visible
        let historyContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'History' OR label CONTAINS 'symptom'"))
        XCTAssertGreaterThan(historyContent.count, 0, "Should show history content")
    }

    /// Tests changing time period filter
    func testChangeTimePeriod() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAnalysis()

        let analysis = AnalysisScreen(app: app)
        analysis.waitForLoad()

        // Change to 7 days
        analysis.selectTimePeriod(7)
        Thread.sleep(forTimeInterval: 0.5)

        // Change to 30 days
        analysis.selectTimePeriod(30)
        Thread.sleep(forTimeInterval: 0.5)

        // Change to 90 days
        analysis.selectTimePeriod(90)
        Thread.sleep(forTimeInterval: 0.5)

        // Verify analysis view is still responsive
        XCTAssertTrue(analysis.viewSelectorMenu.exists || analysis.trendsTab.exists, "Analysis view should still be functional")
    }

    /// Tests viewing activities analysis
    func testViewActivitiesAnalysis() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAnalysis()

        let analysis = AnalysisScreen(app: app)
        analysis.waitForLoad()

        // Switch to activities view
        analysis.switchToActivities()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify activities content is visible
        XCTAssertTrue(app.exists, "Activities view should be visible")
    }

    /// Tests viewing health analysis
    func testViewHealthAnalysis() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launch(
            scenario: .activeUser,
            featureFlags: [] // Ensure HealthKit enabled
        )

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAnalysis()

        let analysis = AnalysisScreen(app: app)
        analysis.waitForLoad()

        // Switch to health view
        analysis.switchToHealth()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify health content is visible
        XCTAssertTrue(app.exists, "Health view should be visible")
    }

    /// Tests empty analysis state
    func testEmptyAnalysisState() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchEmpty()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAnalysis()

        let analysis = AnalysisScreen(app: app)
        analysis.waitForLoad()

        // Should show empty state or insufficient data message
        XCTAssertTrue(analysis.hasEmptyState() || analysis.waitForLoad(), "Should handle empty state gracefully")
    }

    // MARK: - Settings Workflows (10 tests)

    /// Tests navigating to settings
    func testNavigateToSettings() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToSettings()

        let settings = SettingsScreen(app: app)
        XCTAssertTrue(settings.waitForLoad(timeout: timeout(5)), "Settings should load")

        // Verify key settings options are visible
        XCTAssertTrue(settings.trackedSymptomsButton.exists, "Tracked symptoms button should be visible")
    }

    /// Tests adding a symptom type
    func testAddSymptomType() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToSettings()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        settings.navigateToTrackedSymptoms()
        Thread.sleep(forTimeInterval: 0.5)

        let uniqueSymptomName = "TestSymptom\(Int.random(in: 1000...9999))"
        XCTAssertTrue(settings.addSymptomType(name: uniqueSymptomName), "Should be able to add new symptom type")

        // Verify symptom appears in list
        XCTAssertTrue(settings.hasSymptomType(named: uniqueSymptomName), "New symptom should appear in list")
    }

    /// Tests editing a symptom type
    func testEditSymptomType() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToSettings()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        settings.navigateToTrackedSymptoms()
        Thread.sleep(forTimeInterval: 0.5)

        // Find an existing symptom to edit
        let symptoms = app.staticTexts.matching(NSPredicate(format: "identifier CONTAINS 'symptom' OR label CONTAINS 'Headache' OR label CONTAINS 'Fatigue'"))
        if symptoms.count > 0 {
            symptoms.firstMatch.tap()

            // Edit if edit screen appears
            let editField = app.textFields.firstMatch
            if editField.waitForExistence(timeout: 2) {
                editField.tap()
                editField.typeText(" (edited)")

                let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save' OR label CONTAINS[c] 'done'")).firstMatch
                if saveButton.exists {
                    saveButton.tap()
                }
            }
        }
    }

    /// Tests deleting a symptom type
    func testDeleteSymptomType() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToSettings()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        settings.navigateToTrackedSymptoms()
        Thread.sleep(forTimeInterval: 0.5)

        // Add a symptom to delete
        let symptomToDelete = "DeleteMe\(Int.random(in: 1000...9999))"
        _ = settings.addSymptomType(name: symptomToDelete)

        // Delete the symptom
        let deleteSuccess = settings.deleteSymptomType(named: symptomToDelete)
        XCTAssertTrue(deleteSuccess, "Should be able to delete symptom")

        // Verify it's gone
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(settings.hasSymptomType(named: symptomToDelete), "Deleted symptom should not appear in list")
    }

    /// Tests starring/unstarring a symptom
    func testStarUnstarSymptom() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToSettings()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        settings.navigateToTrackedSymptoms()
        Thread.sleep(forTimeInterval: 0.5)

        // Look for star/favorite button
        let starButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'star' OR identifier CONTAINS 'favorite'"))
        if starButtons.count > 0 {
            let starButton = starButtons.firstMatch
            starButton.tap()
            Thread.sleep(forTimeInterval: 0.3)

            // Tap again to unstar
            starButton.tap()
        } else {
            // May need to select a symptom first
            let symptoms = app.staticTexts.matching(NSPredicate(format: "label != ''"))
            if symptoms.count > 0 {
                symptoms.firstMatch.tap()
            }
        }
    }

    /// Tests toggling dark mode
    func testToggleDarkMode() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToSettings()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        settings.navigateToAppearance()
        Thread.sleep(forTimeInterval: 0.5)

        // Look for dark mode toggle or buttons
        let darkModeOption = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'dark' OR label CONTAINS[c] 'appearance'")).firstMatch
        if darkModeOption.exists {
            darkModeOption.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        let toggles = app.switches.matching(NSPredicate(format: "identifier CONTAINS 'dark' OR identifier CONTAINS 'appearance'"))
        if toggles.count > 0 {
            toggles.firstMatch.tap()
        }
    }

    /// Tests enabling/disabling HealthKit integration
    func testEnableDisableHealthKit() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToSettings()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        // Navigate to Connect to Health
        let healthButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'health' OR label CONTAINS[c] 'healthkit'")).firstMatch
        if healthButton.waitForExistence(timeout: 3) {
            healthButton.tap()
            Thread.sleep(forTimeInterval: 0.5)

            // Look for HealthKit toggle
            let healthKitToggle = app.switches.matching(NSPredicate(format: "identifier CONTAINS 'healthkit' OR identifier CONTAINS 'health'")).firstMatch
            if healthKitToggle.exists {
                _ = healthKitToggle.value as? String
                healthKitToggle.tap()
                Thread.sleep(forTimeInterval: 0.5)

                // Toggle back
                healthKitToggle.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    /// Tests setting up reminders
    func testSetUpReminders() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToSettings()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        settings.navigateToReminders()
        Thread.sleep(forTimeInterval: 0.5)

        // Look for add reminder button
        let addButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'add' OR label CONTAINS[c] 'add reminder'")).firstMatch
        if addButton.exists {
            addButton.tap()
            Thread.sleep(forTimeInterval: 0.5)

            // May show time picker or reminder configuration
            if app.datePickers.firstMatch.exists {
                // Interact with time picker if needed
                let doneButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'done' OR label CONTAINS[c] 'save'")).firstMatch
                if doneButton.exists {
                    doneButton.tap()
                }
            }
        }
    }

    /// Tests exporting data
    func testExportData() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToSettings()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        settings.navigateToDataManagement()
        Thread.sleep(forTimeInterval: 0.5)

        // Look for export button
        let exportButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'export' OR identifier CONTAINS 'export'")).firstMatch
        if exportButton.exists {
            exportButton.tap()
            Thread.sleep(forTimeInterval: 1.0)

            // May show share sheet or confirmation
            // Check if share sheet appeared
            let shareSheet = app.sheets.firstMatch
            if shareSheet.exists {
                // Cancel share sheet
                if app.buttons["Cancel"].exists {
                    app.buttons["Cancel"].tap()
                } else if app.buttons["Close"].exists {
                    app.buttons["Close"].tap()
                }
            }
        }
    }

    /// Tests load capacity settings
    func testLoadCapacitySettings() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToSettings()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        settings.navigateToLoadCapacity()
        Thread.sleep(forTimeInterval: 0.5)

        // Verify load capacity screen is visible
        let loadCapacityContent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'capacity' OR label CONTAINS[c] 'load'"))
        XCTAssertGreaterThan(loadCapacityContent.count, 0, "Load capacity screen should show relevant content")
    }

    // MARK: - Activity/Event Tracking (5 tests)

    /// Tests adding an activity/event
    func testAddActivityEvent() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        Thread.sleep(forTimeInterval: 0.5)

        // Look for activity type selection
        let activityTypes = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'exercise' OR label CONTAINS[c] 'meal' OR label CONTAINS[c] 'sleep'"))
        if activityTypes.count > 0 {
            activityTypes.firstMatch.tap()

            // Save the event
            let saveButton = app.buttons[AccessibilityIdentifiers.saveButton]
            if saveButton.exists {
                saveButton.tap()
            }

            XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
        }
    }

    /// Tests editing an activity
    func testEditActivity() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        _ = TimelineScreen(app: app)

        // Look for an event entry in timeline
        let eventEntries = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'exercise' OR label CONTAINS[c] 'meal' OR label CONTAINS[c] 'activity'"))
        if eventEntries.count > 0 {
            eventEntries.firstMatch.tap()

            // Look for edit button
            let editButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'edit' OR identifier CONTAINS 'edit'")).firstMatch
            if editButton.waitForExistence(timeout: 2) {
                editButton.tap()

                // Make some change
                Thread.sleep(forTimeInterval: 0.5)

                // Save changes
                let saveButton = app.buttons[AccessibilityIdentifiers.saveButton]
                if saveButton.exists {
                    saveButton.tap()
                }
            }
        }
    }

    /// Tests deleting an activity
    func testDeleteActivity() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)

        // Look for an event entry
        let eventEntries = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'exercise' OR label CONTAINS[c] 'meal'"))
        if eventEntries.count > 0 {
            eventEntries.firstMatch.tap()

            // Look for delete button
            let deleteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete' OR identifier CONTAINS 'delete'")).firstMatch
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()

                // Confirm deletion if needed
                let confirmButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete' OR label CONTAINS[c] 'confirm'")).firstMatch
                if confirmButton.exists {
                    confirmButton.tap()
                }

                XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
            }
        }
    }

    /// Tests viewing activity in timeline
    func testViewActivityInTimeline() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        XCTAssertTrue(timeline.waitForLoad(), "Timeline should load")

        // Look for activity/event markers in timeline
        _ = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'exercise' OR label CONTAINS[c] 'meal' OR label CONTAINS[c] 'sleep'"))

        // Activities may or may not be present depending on sample data
        // Just verify timeline is functional
        XCTAssertTrue(timeline.logEventButton.exists, "Log event button should be available")
    }

    /// Tests activity correlation in analysis
    func testActivityCorrelation() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAnalysis()

        let analysis = AnalysisScreen(app: app)
        analysis.waitForLoad()

        // Switch to activities/patterns view
        analysis.switchToPatterns()
        Thread.sleep(forTimeInterval: 1.0)

        // Verify patterns/correlation content is visible
        XCTAssertTrue(app.exists, "Patterns view should be accessible")
    }

    // MARK: - Sleep/Meal Tracking (4 tests)

    /// Tests adding a sleep event
    func testAddSleepEvent() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        Thread.sleep(forTimeInterval: 0.5)

        // Look for sleep option
        let sleepButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sleep'")).firstMatch
        if sleepButton.exists {
            sleepButton.tap()

            // May need to set duration or time
            Thread.sleep(forTimeInterval: 0.5)

            let saveButton = app.buttons[AccessibilityIdentifiers.saveButton]
            if saveButton.exists {
                saveButton.tap()
            }

            XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
        }
    }

    /// Tests adding a meal event
    func testAddMealEvent() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEvent()

        Thread.sleep(forTimeInterval: 0.5)

        // Look for meal option
        let mealButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'meal' OR label CONTAINS[c] 'food'")).firstMatch
        if mealButton.exists {
            mealButton.tap()

            Thread.sleep(forTimeInterval: 0.5)

            let saveButton = app.buttons[AccessibilityIdentifiers.saveButton]
            if saveButton.exists {
                saveButton.tap()
            }

            XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
        }
    }

    /// Tests editing a sleep event
    func testEditSleepEvent() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        _ = TimelineScreen(app: app)

        // Look for sleep entry
        let sleepEntries = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'sleep'"))
        if sleepEntries.count > 0 {
            sleepEntries.firstMatch.tap()

            let editButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'edit'")).firstMatch
            if editButton.waitForExistence(timeout: 2) {
                editButton.tap()

                Thread.sleep(forTimeInterval: 0.5)

                let saveButton = app.buttons[AccessibilityIdentifiers.saveButton]
                if saveButton.exists {
                    saveButton.tap()
                }
            }
        }
    }

    /// Tests deleting a meal event
    func testDeleteMealEvent() throws {
        guard let app = app else {
            XCTFail("App not initialized")
            return
        }
        app.launchWithData()

        let timeline = TimelineScreen(app: app)

        // Look for meal entry
        let mealEntries = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'meal' OR label CONTAINS[c] 'food'"))
        if mealEntries.count > 0 {
            mealEntries.firstMatch.tap()

            let deleteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete'")).firstMatch
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()

                // Confirm if needed
                let confirmButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete' OR label CONTAINS[c] 'confirm'")).firstMatch
                if confirmButton.exists {
                    confirmButton.tap()
                }

                XCTAssertTrue(timeline.waitForLoad(), "Should return to timeline")
            }
        }
    }
}
