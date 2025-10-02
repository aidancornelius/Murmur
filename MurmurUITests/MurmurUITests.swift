//
//  MurmurUITests.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 2/10/2025.
//

import XCTest

final class MurmurUITests: XCTestCase {
    var app: XCUIApplication!

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)

        // Launch with sample data flag
        app.launchArguments = ["-UITestMode", "-SeedSampleData"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot tests

    @MainActor
    func testGenerateScreenshots() throws {
        // Wait for app to fully launch and load data
        sleep(3)

        // Screenshot 1: Main timeline view
        snapshot("01Timeline")

        // Screenshot 2: Day detail view
        // Find and tap on the first day section header
        let firstSection = app.tables.cells.firstMatch
        if firstSection.waitForExistence(timeout: 5) {
            firstSection.tap()
            sleep(1)
            snapshot("02DayDetail")

            // Go back
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // Screenshot 3: Add symptom entry
        // Tap the "Log symptom" button
        let logSymptomButton = app.buttons["Log symptom"]
        if logSymptomButton.waitForExistence(timeout: 5) {
            logSymptomButton.tap()
            sleep(1)
            snapshot("03AddSymptom")

            // Cancel
            app.navigationBars.buttons["Cancel"].tap()
            sleep(1)
        }

        // Screenshot 4: Analysis view
        // Tap the analysis button in nav bar
        let analysisButton = app.navigationBars.buttons["Analysis"]
        if analysisButton.waitForExistence(timeout: 5) {
            analysisButton.tap()
            sleep(1)
            snapshot("04Analysis")

            // Go back
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // Screenshot 5: Settings
        let settingsButton = app.navigationBars.buttons.matching(identifier: "gearshape").firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(1)
            snapshot("05Settings")
        }
    }
}
