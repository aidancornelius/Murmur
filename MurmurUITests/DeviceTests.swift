//
//  DeviceTests.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest
@testable import Murmur

/// Cross-device and orientation testing
/// Note: Run these tests on different simulators to verify device-specific layouts
final class DeviceTests: XCTestCase {
    var app: XCUIApplication!
    var initialOrientation: UIDeviceOrientation!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        initialOrientation = XCUIDevice.shared.orientation
    }

    override func tearDownWithError() throws {
        // Restore original orientation
        if initialOrientation != .unknown {
            XCUIDevice.shared.orientation = initialOrientation
        }
        app = nil
    }

    // MARK: - Device Sizes (5 tests)

    /// Tests timeline on iPhone SE (smallest supported device)
    func testTimelineOnIPhoneSE() throws {
        // This test should be run on iPhone SE simulator
        let screenWidth = app.windows.firstMatch.frame.width

        // iPhone SE is 375pt wide
        guard screenWidth <= 375 else {
            throw XCTSkip("This test should run on iPhone SE")
        }

        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should load on iPhone SE")

        // Verify main elements are visible and accessible
        assertHittable(timeline.logSymptomButton,
                      message: "Log button should be accessible on small screen")

        // Check that entries are readable
        if let firstEntry = timeline.getFirstEntry() {
            XCTAssertTrue(firstEntry.isHittable,
                         "Entries should be tappable on small screen")
            XCTAssertTrue(firstEntry.frame.width > 0,
                         "Entries should have proper width on small screen")
        }

        // Navigate to other screens to verify layout
        app.tabBars.buttons["Analysis"].tap()
        Thread.sleep(forTimeInterval: 1.0)

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis should load on small screen")

        takeScreenshot(named: "DeviceTest_iPhoneSE_Timeline")
    }

    /// Tests timeline on iPhone Pro (standard size)
    func testTimelineOnIPhonePro() throws {
        let screenWidth = app.windows.firstMatch.frame.width

        // iPhone Pro is typically 393pt wide
        guard screenWidth >= 390 && screenWidth <= 400 else {
            throw XCTSkip("This test should run on iPhone Pro")
        }

        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should load on iPhone Pro")

        // Verify layout is optimal for this size
        assertHittable(timeline.logSymptomButton,
                      message: "UI should be accessible on iPhone Pro")

        takeScreenshot(named: "DeviceTest_iPhonePro_Timeline")
    }

    /// Tests timeline on iPhone Pro Max (largest iPhone)
    func testTimelineOnIPhoneProMax() throws {
        let screenWidth = app.windows.firstMatch.frame.width

        // iPhone Pro Max is typically 430pt wide
        guard screenWidth >= 414 else {
            throw XCTSkip("This test should run on iPhone Pro Max or similar large iPhone")
        }

        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should load on iPhone Pro Max")

        // Verify UI takes advantage of larger screen
        assertHittable(timeline.logSymptomButton,
                      message: "UI should be accessible on large iPhone")

        // Check if more content is visible
        let entries = timeline.getAllEntries()
        XCTAssertGreaterThan(entries.count, 0, "Should show entries on large screen")

        takeScreenshot(named: "DeviceTest_iPhoneProMax_Timeline")
    }

    /// Tests timeline on iPad (standard size)
    func testTimelineOnIPad() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test should run on iPad")
        }

        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should load on iPad")

        // Verify iPad-specific layout
        let screenWidth = app.windows.firstMatch.frame.width
        XCTAssertGreaterThan(screenWidth, 700, "iPad should have wide screen")

        // iPad might show sidebar or split view
        assertHittable(timeline.logSymptomButton,
                      message: "UI should be accessible on iPad")

        takeScreenshot(named: "DeviceTest_iPad_Timeline")
    }

    /// Tests timeline on iPad Pro (largest iPad)
    func testTimelineOnIPadPro() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test should run on iPad Pro")
        }

        let screenWidth = app.windows.firstMatch.frame.width

        // iPad Pro 13" is ~1024pt wide in portrait
        guard screenWidth >= 1000 else {
            throw XCTSkip("This test should run on iPad Pro 13-inch")
        }

        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should load on iPad Pro")

        // Verify large screen layout
        assertHittable(timeline.logSymptomButton,
                      message: "UI should be accessible on iPad Pro")

        takeScreenshot(named: "DeviceTest_iPadPro_Timeline")
    }

    // MARK: - Orientation (4 tests)

    /// Tests iPhone in landscape orientation
    func testIPhoneLandscape() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            throw XCTSkip("This test should run on iPhone")
        }

        app.launchWithData()

        // Rotate to landscape
        XCUIDevice.shared.orientation = .landscapeLeft

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should adapt to landscape")

        // Verify UI is still accessible in landscape
        assertHittable(timeline.logSymptomButton,
                      message: "Buttons should remain accessible in landscape")

        // Navigate to add entry in landscape
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        XCTAssertTrue(addEntry.waitForLoad(), "Add entry should work in landscape")

        // Verify form fields are accessible
        let cancelButton = app.buttons[AccessibilityIdentifiers.cancelButton]
        assertHittable(cancelButton, message: "Cancel button should be accessible in landscape")

        takeScreenshot(named: "DeviceTest_iPhone_Landscape")

        // Return to portrait
        XCUIDevice.shared.orientation = .portrait
    }

    /// Tests iPad in portrait orientation
    func testIPadPortrait() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test should run on iPad")
        }

        app.launchWithData()

        // Ensure portrait orientation
        XCUIDevice.shared.orientation = .portrait

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should display in portrait on iPad")

        // Verify layout uses portrait space effectively
        assertHittable(timeline.logSymptomButton,
                      message: "UI should be accessible in portrait")

        takeScreenshot(named: "DeviceTest_iPad_Portrait")
    }

    /// Tests iPad in landscape orientation
    func testIPadLandscape() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("This test should run on iPad")
        }

        app.launchWithData()

        // Rotate to landscape
        XCUIDevice.shared.orientation = .landscapeLeft

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should adapt to landscape on iPad")

        // iPad landscape might show split view or wider layout
        let screenWidth = app.windows.firstMatch.frame.width
        XCTAssertGreaterThan(screenWidth, 900, "iPad landscape should be wide")

        assertHittable(timeline.logSymptomButton,
                      message: "UI should be accessible in landscape")

        takeScreenshot(named: "DeviceTest_iPad_Landscape")

        // Return to portrait
        XCUIDevice.shared.orientation = .portrait
    }

    /// Tests orientation change while using the app
    func testOrientationChange() throws {
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should be visible")

        // Start in portrait
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 0.5)

        // Open add entry in portrait
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        XCTAssertTrue(addEntry.waitForLoad(), "Add entry should load")

        // Rotate to landscape while on add entry screen
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.0)

        // Verify screen is still functional
        let cancelButton = app.buttons[AccessibilityIdentifiers.cancelButton]
        assertExists(cancelButton, timeout: 5, message: "UI should adapt to orientation change")
        assertHittable(cancelButton, message: "Buttons should remain accessible after rotation")

        // Rotate back to portrait
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.0)

        // Should still be functional
        assertHittable(cancelButton, message: "UI should remain functional after rotating back")

        // Cancel and return to timeline
        cancelButton.tap()

        assertExists(timeline.logSymptomButton, timeout: 5,
                    message: "Should navigate back successfully after orientation changes")
    }

    // MARK: - Layout Verification (4 tests)

    /// Verifies layout adapts to different screen widths
    func testLayoutAdaptsToScreenWidth() throws {
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        assertExists(timeline.logSymptomButton, timeout: 10, message: "Timeline should be visible")

        let screenWidth = app.windows.firstMatch.frame.width
        let screenHeight = app.windows.firstMatch.frame.height

        // Log screen dimensions for debugging
        log("Screen dimensions: \(screenWidth) x \(screenHeight)")

        // Verify log button is properly sized for screen
        let buttonFrame = timeline.logSymptomButton.frame
        XCTAssertLessThan(buttonFrame.width, screenWidth,
                         "Button should fit within screen width")

        // Navigate through all screens to verify layout
        app.tabBars.buttons["Analysis"].tap()
        Thread.sleep(forTimeInterval: 1.0)

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis should load with adapted layout")

        app.tabBars.buttons["Settings"].tap()
        Thread.sleep(forTimeInterval: 1.0)

        let settings = SettingsScreen(app: app)
        XCTAssertTrue(settings.waitForLoad(), "Settings should load with adapted layout")
    }

    /// Verifies charts are readable on small screens
    func testChartsReadableOnSmallScreens() throws {
        let screenWidth = app.windows.firstMatch.frame.width

        // Focus on smaller screens
        guard screenWidth <= 400 else {
            throw XCTSkip("This test focuses on small screens")
        }

        app.launchWithData()

        app.tabBars.buttons["Analysis"].tap()

        let analysis = AnalysisScreen(app: app)
        XCTAssertTrue(analysis.waitForLoad(), "Analysis should load")

        // Ensure trends view
        if app.buttons["Trends"].exists {
            app.buttons["Trends"].tap()
        }

        Thread.sleep(forTimeInterval: 2.0)

        // Chart should be visible
        let charts = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'chart' OR identifier CONTAINS 'Chart'"))
        if charts.count > 0 {
            let chart = charts.element(boundBy: 0)
            XCTAssertTrue(chart.frame.width > 0,
                         "Chart should have width on small screen")
            XCTAssertLessThan(chart.frame.width, screenWidth,
                            "Chart should fit within screen")
        }

        takeScreenshot(named: "DeviceTest_SmallScreen_Chart")
    }

    /// Verifies forms are not cut off on any screen size
    func testFormsNotCutOff() throws {
        app.launchWithData()

        let timeline = TimelineScreen(app: app)
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        XCTAssertTrue(addEntry.waitForLoad(), "Add entry should load")

        let screenHeight = app.windows.firstMatch.frame.height

        // Verify cancel button is visible
        let cancelButton = app.buttons[AccessibilityIdentifiers.cancelButton]
        assertExists(cancelButton, message: "Cancel button should be visible")
        XCTAssertLessThan(cancelButton.frame.maxY, screenHeight,
                         "Cancel button should not be cut off")

        // Verify save button is visible (if it exists)
        let saveButton = app.buttons[AccessibilityIdentifiers.saveButton]
        if saveButton.exists {
            XCTAssertLessThan(saveButton.frame.maxY, screenHeight,
                            "Save button should not be cut off")
        }

        // If there's a scroll view, it should be accessible
        let scrollViews = app.scrollViews
        if scrollViews.count > 0 {
            XCTAssertTrue(scrollViews.firstMatch.isHittable,
                         "Scroll view should be accessible")
        }

        takeScreenshot(named: "DeviceTest_FormLayout")
    }

    /// Verifies all buttons remain accessible on all screen sizes
    func testButtonsAccessible() throws {
        app.launchWithData()

        let timeline = TimelineScreen(app: app)

        // Verify main button is accessible
        assertHittable(timeline.logSymptomButton,
                      message: "Log symptom button should be accessible")

        // Verify tab bar buttons are accessible
        let analysisTab = app.tabBars.buttons["Analysis"]
        assertHittable(analysisTab, message: "Analysis tab should be accessible")

        let settingsTab = app.tabBars.buttons["Settings"]
        assertHittable(settingsTab, message: "Settings tab should be accessible")

        // Navigate to add entry and verify buttons there
        timeline.navigateToAddEntry()

        let addEntry = AddEntryScreen(app: app)
        addEntry.waitForLoad()

        let cancelButton = app.buttons[AccessibilityIdentifiers.cancelButton]
        assertHittable(cancelButton, message: "Cancel button should be accessible")

        // Cancel and go to settings
        cancelButton.tap()

        app.tabBars.buttons["Settings"].tap()

        let settings = SettingsScreen(app: app)
        settings.waitForLoad()

        // Verify settings buttons are accessible
        if app.buttons[AccessibilityIdentifiers.trackedSymptomsButton].exists {
            assertHittable(app.buttons[AccessibilityIdentifiers.trackedSymptomsButton],
                          message: "Settings buttons should be accessible")
        }
    }
}
