//
//  AppLaunchState.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest
@testable import Murmur

/// Extension to XCUIApplication for launching with specific states
extension XCUIApplication {

    // MARK: - Launch with State

    /// Launch app with specific test state
    func launch(state: AppLaunchState) {
        launchArguments = state.launchArguments
        launch()
    }

    /// Launch app with custom configuration
    func launch(
        scenario: TestDataBuilder.TestScenario,
        appearance: TestDataBuilder.Appearance = .system,
        contentSize: TestDataBuilder.ContentSizeCategory? = nil,
        featureFlags: [TestDataBuilder.FeatureFlag] = []
    ) {
        launchArguments = TestDataBuilder.customLaunchArguments(
            scenario: scenario,
            appearance: appearance,
            contentSize: contentSize,
            featureFlags: featureFlags
        )
        launch()
    }

    /// Launch app for snapshot testing
    func launchForSnapshots(locale: Locale = TestDataBuilder.australianLocale) {
        setupSnapshot(self)
        launchArguments = TestDataBuilder.snapshotLaunchArguments(locale: locale)
        launch()
    }

    /// Launch app for accessibility testing
    func launchForAccessibility(
        contentSize: TestDataBuilder.ContentSizeCategory = .accessibilityExtraLarge,
        boldText: Bool = false,
        reduceMotion: Bool = false
    ) {
        launchArguments = TestDataBuilder.accessibilityLaunchArguments(
            contentSize: contentSize,
            boldText: boldText,
            reduceMotion: reduceMotion
        )
        launch()
    }

    /// Launch app for performance testing
    func launchForPerformance() {
        launchArguments = TestDataBuilder.performanceLaunchArguments()
        launch()
    }

    // MARK: - Quick Launch Methods

    /// Launch with fresh install state
    func launchFresh() {
        launch(state: .fresh)
    }

    /// Launch with sample data
    func launchWithData() {
        launch(state: .withData)
    }

    /// Launch with large data set
    func launchWithLargeData() {
        launch(state: .withLargeData)
    }

    /// Launch with empty state
    func launchEmpty() {
        launch(state: .emptyState)
    }

    /// Launch in dark mode
    func launchDarkMode() {
        launch(state: .darkMode)
    }

    /// Launch in light mode
    func launchLightMode() {
        launch(state: .lightMode)
    }
}

/// App launch state configurations
enum AppLaunchState {
    case fresh              // First install
    case returningUser      // Has used app before
    case withData           // Has existing data
    case withLargeData      // Heavy user
    case emptyState         // No entries
    case postUpdate         // After app update
    case lowStorage         // Simulated low storage
    case offline            // No network
    case onboarding         // Show onboarding
    case darkMode           // Dark appearance
    case lightMode          // Light appearance
    case accessibilityLarge // Large accessibility text
    case custom([String])   // Custom launch arguments

    /// Get launch arguments for this state
    var launchArguments: [String] {
        switch self {
        case .fresh:
            return TestDataBuilder.launchArguments(for: .newUser)

        case .returningUser:
            var args = ["-UITestMode"]
            args.append("-ReturningUser")
            return args

        case .withData:
            return TestDataBuilder.launchArguments(for: .activeUser)

        case .withLargeData:
            return TestDataBuilder.launchArguments(for: .heavyUser)

        case .emptyState:
            return TestDataBuilder.launchArguments(for: .emptyState)

        case .postUpdate:
            var args = ["-UITestMode"]
            args.append("-SimulateUpdate")
            return args

        case .lowStorage:
            var args = ["-UITestMode", "-SeedSampleData"]
            args.append("-LowStorage")
            return args

        case .offline:
            var args = ["-UITestMode", "-SeedSampleData"]
            args.append("-OfflineMode")
            return args

        case .onboarding:
            return TestDataBuilder.launchArguments(for: .onboarding)

        case .darkMode:
            return TestDataBuilder.launchArguments(appearance: .dark)

        case .lightMode:
            return TestDataBuilder.launchArguments(appearance: .light)

        case .accessibilityLarge:
            return TestDataBuilder.accessibilityLaunchArguments(
                contentSize: .accessibilityExtraLarge
            )

        case .custom(let args):
            return args
        }
    }

    /// Description of the launch state
    var description: String {
        switch self {
        case .fresh:
            return "Fresh install"
        case .returningUser:
            return "Returning user"
        case .withData:
            return "With sample data"
        case .withLargeData:
            return "With large data set"
        case .emptyState:
            return "Empty state"
        case .postUpdate:
            return "Post update"
        case .lowStorage:
            return "Low storage"
        case .offline:
            return "Offline mode"
        case .onboarding:
            return "Onboarding"
        case .darkMode:
            return "Dark mode"
        case .lightMode:
            return "Light mode"
        case .accessibilityLarge:
            return "Accessibility large text"
        case .custom:
            return "Custom configuration"
        }
    }
}

/// App state assertion helpers
extension XCTestCase {

    /// Assert app is in expected state
    func assertAppState(_ state: ExpectedAppState,
                       app: XCUIApplication,
                       timeout: TimeInterval = 5,
                       file: StaticString = #filePath,
                       line: UInt = #line) {
        switch state {
        case .timeline:
            let logButton = app.buttons[AccessibilityIdentifiers.logSymptomButton]
            XCTAssertTrue(logButton.waitForExistence(timeout: timeout),
                         "App should be showing timeline",
                         file: file, line: line)

        case .onboarding:
            let continueButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Continue' OR label CONTAINS 'Get Started'")).firstMatch
            XCTAssertTrue(continueButton.waitForExistence(timeout: timeout),
                         "App should be showing onboarding",
                         file: file, line: line)

        case .settings:
            let trackedSymptomsButton = app.buttons[AccessibilityIdentifiers.trackedSymptomsButton]
            XCTAssertTrue(trackedSymptomsButton.waitForExistence(timeout: timeout),
                         "App should be showing settings",
                         file: file, line: line)

        case .analysis:
            let trendsButton = app.buttons["Trends"]
            XCTAssertTrue(trendsButton.waitForExistence(timeout: timeout),
                         "App should be showing analysis",
                         file: file, line: line)

        case .addEntry:
            let cancelButton = app.buttons[AccessibilityIdentifiers.cancelButton]
            XCTAssertTrue(cancelButton.waitForExistence(timeout: timeout),
                         "App should be showing add entry",
                         file: file, line: line)

        case .emptyTimeline:
            let logButton = app.buttons[AccessibilityIdentifiers.logSymptomButton]
            XCTAssertTrue(logButton.waitForExistence(timeout: timeout),
                         "App should be showing timeline",
                         file: file, line: line)
            let emptyMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No entries' OR label CONTAINS 'Get started'")).firstMatch
            XCTAssertTrue(emptyMessage.exists,
                         "Timeline should show empty state message",
                         file: file, line: line)
        }
    }
}

/// Expected app states for assertions
enum ExpectedAppState {
    case timeline
    case onboarding
    case settings
    case analysis
    case addEntry
    case emptyTimeline
}
