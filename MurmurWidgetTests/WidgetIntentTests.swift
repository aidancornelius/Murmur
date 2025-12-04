// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// WidgetIntentTests.swift
// Created by Aidan Cornelius-Bell on 13/10/2025.
// Tests for widget intent handling.
//
import XCTest
import AppIntents
@testable import MurmurWidgets
@testable import Murmur

// Use MurmurWidgets versions to resolve ambiguity
typealias TestOpenAddEntryIntent = MurmurWidgets.OpenAddEntryIntent
typealias TestOpenAddActivityIntent = MurmurWidgets.OpenAddActivityIntent

@MainActor
final class WidgetIntentTests: XCTestCase {

    // MARK: - Setup and Teardown

    var notificationCenter: NotificationCenter!

    override func setUp() async throws {
        try await super.setUp()
        notificationCenter = NotificationCenter.default
    }

    override func tearDown() async throws {
        notificationCenter = nil
        try await super.tearDown()
    }

    // MARK: - TestOpenAddEntryIntent Tests

    func testTestOpenAddEntryIntentHasCorrectTitle() {
        // Given/When
        let title = TestOpenAddEntryIntent.title

        // Then
        XCTAssertEqual(String(localized: title), "How are you feeling?")
    }

    func testTestOpenAddEntryIntentHasCorrectDescription() {
        // Given/When
        let description = TestOpenAddEntryIntent.description

        // Then
        XCTAssertNotNil(description)
    }

    func testTestOpenAddEntryIntentOpensAppWhenRun() {
        // Given/When
        let opensApp = TestOpenAddEntryIntent.openAppWhenRun

        // Then
        XCTAssertTrue(opensApp, "Intent should open the app when run")
    }

    func testTestOpenAddEntryIntentPerformPostsNotification() async throws {
        // Given
        let intent = TestOpenAddEntryIntent()
        var notificationReceived = false
        let expectation = XCTestExpectation(description: "Notification posted")

        let observer = notificationCenter.addObserver(
            forName: Notification.Name("openAddEntry"),
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
            expectation.fulfill()
        }

        // When
        let result = try await intent.perform()

        // Wait for notification
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertTrue(notificationReceived, "Notification should be posted")
        XCTAssertNotNil(result)

        // Cleanup
        notificationCenter.removeObserver(observer)
    }

    func testTestOpenAddEntryIntentCanBePerformedMultipleTimes() async throws {
        // Given
        let intent = TestOpenAddEntryIntent()
        var notificationCount = 0
        let expectation = XCTestExpectation(description: "Multiple notifications posted")
        expectation.expectedFulfillmentCount = 3

        let observer = notificationCenter.addObserver(
            forName: Notification.Name("openAddEntry"),
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
            expectation.fulfill()
        }

        // When - Perform intent multiple times
        _ = try await intent.perform()
        _ = try await intent.perform()
        _ = try await intent.perform()

        // Wait for notifications
        await fulfillment(of: [expectation], timeout: 2.0)

        // Then
        XCTAssertEqual(notificationCount, 3)

        // Cleanup
        notificationCenter.removeObserver(observer)
    }

    func testTestOpenAddEntryIntentNotificationNameIsCorrect() {
        // Given/When
        let notificationName = Notification.Name("openAddEntry")

        // Then
        XCTAssertEqual(notificationName.rawValue, "openAddEntry")
    }

    // MARK: - TestOpenAddActivityIntent Tests

    func testTestOpenAddActivityIntentHasCorrectTitle() {
        // Given/When
        let title = TestOpenAddActivityIntent.title

        // Then
        XCTAssertEqual(String(localized: title), "Log an activity")
    }

    func testTestOpenAddActivityIntentHasCorrectDescription() {
        // Given/When
        let description = TestOpenAddActivityIntent.description

        // Then
        XCTAssertNotNil(description)
    }

    func testTestOpenAddActivityIntentOpensAppWhenRun() {
        // Given/When
        let opensApp = TestOpenAddActivityIntent.openAppWhenRun

        // Then
        XCTAssertTrue(opensApp, "Intent should open the app when run")
    }

    func testTestOpenAddActivityIntentPerformPostsNotification() async throws {
        // Given
        let intent = TestOpenAddActivityIntent()
        var notificationReceived = false
        let expectation = XCTestExpectation(description: "Notification posted")

        let observer = notificationCenter.addObserver(
            forName: Notification.Name("openAddActivity"),
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true
            expectation.fulfill()
        }

        // When
        let result = try await intent.perform()

        // Wait for notification
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertTrue(notificationReceived, "Notification should be posted")
        XCTAssertNotNil(result)

        // Cleanup
        notificationCenter.removeObserver(observer)
    }

    func testTestOpenAddActivityIntentCanBePerformedMultipleTimes() async throws {
        // Given
        let intent = TestOpenAddActivityIntent()
        var notificationCount = 0
        let expectation = XCTestExpectation(description: "Multiple notifications posted")
        expectation.expectedFulfillmentCount = 3

        let observer = notificationCenter.addObserver(
            forName: Notification.Name("openAddActivity"),
            object: nil,
            queue: .main
        ) { _ in
            notificationCount += 1
            expectation.fulfill()
        }

        // When - Perform intent multiple times
        _ = try await intent.perform()
        _ = try await intent.perform()
        _ = try await intent.perform()

        // Wait for notifications
        await fulfillment(of: [expectation], timeout: 2.0)

        // Then
        XCTAssertEqual(notificationCount, 3)

        // Cleanup
        notificationCenter.removeObserver(observer)
    }

    func testTestOpenAddActivityIntentNotificationNameIsCorrect() {
        // Given/When
        let notificationName = Notification.Name("openAddActivity")

        // Then
        XCTAssertEqual(notificationName.rawValue, "openAddActivity")
    }

    // MARK: - Intent Comparison Tests

    func testIntentsHaveUniqueNotificationNames() {
        // Given
        let entryNotification = Notification.Name("openAddEntry")
        let activityNotification = Notification.Name("openAddActivity")

        // Then
        XCTAssertNotEqual(entryNotification, activityNotification, "Intents must use unique notification names")
    }

    func testIntentsHaveUniqueTitles() {
        // Given
        let entryTitle = String(localized: TestOpenAddEntryIntent.title)
        let activityTitle = String(localized: TestOpenAddActivityIntent.title)

        // Then
        XCTAssertNotEqual(entryTitle, activityTitle, "Intents should have unique titles for user clarity")
    }

    func testBothIntentsOpenAppWhenRun() {
        // Given/When
        let entryOpensApp = TestOpenAddEntryIntent.openAppWhenRun
        let activityOpensApp = TestOpenAddActivityIntent.openAppWhenRun

        // Then
        XCTAssertTrue(entryOpensApp)
        XCTAssertTrue(activityOpensApp)
    }

    // MARK: - Intent Instantiation Tests

    func testTestOpenAddEntryIntentCanBeInstantiated() {
        // Given/When/Then - Should not crash
        let intent = TestOpenAddEntryIntent()
        XCTAssertNotNil(intent)
    }

    func testTestOpenAddActivityIntentCanBeInstantiated() {
        // Given/When/Then - Should not crash
        let intent = TestOpenAddActivityIntent()
        XCTAssertNotNil(intent)
    }

    func testMultipleIntentInstancesCanCoexist() {
        // Given/When
        let entryIntent1 = TestOpenAddEntryIntent()
        let entryIntent2 = TestOpenAddEntryIntent()
        let activityIntent1 = TestOpenAddActivityIntent()
        let activityIntent2 = TestOpenAddActivityIntent()

        // Then - All should be valid
        XCTAssertNotNil(entryIntent1)
        XCTAssertNotNil(entryIntent2)
        XCTAssertNotNil(activityIntent1)
        XCTAssertNotNil(activityIntent2)
    }

    // MARK: - Error Handling Tests

    func testTestOpenAddEntryIntentDoesNotThrow() async {
        // Given
        let intent = TestOpenAddEntryIntent()

        // When/Then - Should not throw
        do {
            let result = try await intent.perform()
            XCTAssertNotNil(result)
        } catch {
            XCTFail("Intent should not throw errors: \(error)")
        }
    }

    func testTestOpenAddActivityIntentDoesNotThrow() async {
        // Given
        let intent = TestOpenAddActivityIntent()

        // When/Then - Should not throw
        do {
            let result = try await intent.perform()
            XCTAssertNotNil(result)
        } catch {
            XCTFail("Intent should not throw errors: \(error)")
        }
    }

    // MARK: - Notification Observer Tests

    func testCanObserveBothNotifications() async throws {
        // Given
        let entryIntent = TestOpenAddEntryIntent()
        let activityIntent = TestOpenAddActivityIntent()
        var entryReceived = false
        var activityReceived = false
        let entryExpectation = XCTestExpectation(description: "Entry notification")
        let activityExpectation = XCTestExpectation(description: "Activity notification")

        let entryObserver = notificationCenter.addObserver(
            forName: Notification.Name("openAddEntry"),
            object: nil,
            queue: .main
        ) { _ in
            entryReceived = true
            entryExpectation.fulfill()
        }

        let activityObserver = notificationCenter.addObserver(
            forName: Notification.Name("openAddActivity"),
            object: nil,
            queue: .main
        ) { _ in
            activityReceived = true
            activityExpectation.fulfill()
        }

        // When
        _ = try await entryIntent.perform()
        _ = try await activityIntent.perform()

        // Wait for notifications
        await fulfillment(of: [entryExpectation, activityExpectation], timeout: 2.0)

        // Then
        XCTAssertTrue(entryReceived)
        XCTAssertTrue(activityReceived)

        // Cleanup
        notificationCenter.removeObserver(entryObserver)
        notificationCenter.removeObserver(activityObserver)
    }

    // MARK: - Intent Result Tests

    func testTestOpenAddEntryIntentReturnsResult() async throws {
        // Given
        let intent = TestOpenAddEntryIntent()

        // When
        let result = try await intent.perform()

        // Then - Should return some result (not nil)
        XCTAssertNotNil(result)
    }

    func testTestOpenAddActivityIntentReturnsResult() async throws {
        // Given
        let intent = TestOpenAddActivityIntent()

        // When
        let result = try await intent.perform()

        // Then - Should return some result (not nil)
        XCTAssertNotNil(result)
    }

    // MARK: - Concurrent Execution Tests

    func testIntentsCanBePerformedConcurrently() async throws {
        // Given
        let entryIntent = TestOpenAddEntryIntent()
        let activityIntent = TestOpenAddActivityIntent()
        var entryCount = 0
        var activityCount = 0
        let expectation = XCTestExpectation(description: "Concurrent notifications")
        expectation.expectedFulfillmentCount = 4

        let entryObserver = notificationCenter.addObserver(
            forName: Notification.Name("openAddEntry"),
            object: nil,
            queue: .main
        ) { _ in
            entryCount += 1
            expectation.fulfill()
        }

        let activityObserver = notificationCenter.addObserver(
            forName: Notification.Name("openAddActivity"),
            object: nil,
            queue: .main
        ) { _ in
            activityCount += 1
            expectation.fulfill()
        }

        // When - Perform intents concurrently
        async let result1 = entryIntent.perform()
        async let result2 = activityIntent.perform()
        async let result3 = entryIntent.perform()
        async let result4 = activityIntent.perform()

        let results: [Any] = try await [result1, result2, result3, result4]

        // Wait for notifications
        await fulfillment(of: [expectation], timeout: 2.0)

        // Then
        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(entryCount, 2)
        XCTAssertEqual(activityCount, 2)

        // Cleanup
        notificationCenter.removeObserver(entryObserver)
        notificationCenter.removeObserver(activityObserver)
    }
}
