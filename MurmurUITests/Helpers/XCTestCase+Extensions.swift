//
//  XCTestCase+Extensions.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest

extension XCTestCase {

    // MARK: - Environment Detection

    /// Checks if running in CI environment
    var isRunningInCI: Bool {
        return ProcessInfo.processInfo.environment["CI"] != nil ||
               ProcessInfo.processInfo.environment["FASTLANE_SNAPSHOT"] != nil
    }

    /// Returns timeout adjusted for CI environment (2x longer in CI)
    func timeout(_ base: TimeInterval) -> TimeInterval {
        return isRunningInCI ? base * 2 : base
    }

    // MARK: - Element Assertions

    /// Assert element exists with timeout
    @discardableResult
    func assertExists(_ element: XCUIElement,
                     timeout: TimeInterval = 5,
                     message: String? = nil,
                     file: StaticString = #filePath,
                     line: UInt = #line) -> XCUIElement {
        let exists = element.waitForExistence(timeout: timeout)
        let errorMessage = message ?? "Element \(element.description) should exist"
        XCTAssertTrue(exists, errorMessage, file: file, line: line)
        return element
    }

    /// Assert element does not exist
    func assertNotExists(_ element: XCUIElement,
                        timeout: TimeInterval = 2,
                        message: String? = nil,
                        file: StaticString = #filePath,
                        line: UInt = #line) {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        let errorMessage = message ?? "Element \(element.description) should not exist"
        XCTAssertEqual(result, .completed, errorMessage, file: file, line: line)
    }

    /// Assert element is hittable
    func assertHittable(_ element: XCUIElement,
                       timeout: TimeInterval = 5,
                       message: String? = nil,
                       file: StaticString = #filePath,
                       line: UInt = #line) {
        let isHittable = element.waitForHittable(timeout: timeout)
        let errorMessage = message ?? "Element \(element.description) should be hittable"
        XCTAssertTrue(isHittable, errorMessage, file: file, line: line)
    }

    /// Assert element is enabled
    func assertEnabled(_ element: XCUIElement,
                      message: String? = nil,
                      file: StaticString = #filePath,
                      line: UInt = #line) {
        let errorMessage = message ?? "Element \(element.description) should be enabled"
        XCTAssertTrue(element.isEnabled, errorMessage, file: file, line: line)
    }

    /// Assert element is disabled
    func assertDisabled(_ element: XCUIElement,
                       message: String? = nil,
                       file: StaticString = #filePath,
                       line: UInt = #line) {
        let errorMessage = message ?? "Element \(element.description) should be disabled"
        XCTAssertFalse(element.isEnabled, errorMessage, file: file, line: line)
    }

    /// Assert element has specific label
    func assertLabel(_ element: XCUIElement,
                    equals expectedLabel: String,
                    message: String? = nil,
                    file: StaticString = #filePath,
                    line: UInt = #line) {
        let errorMessage = message ?? "Element label should be '\(expectedLabel)' but was '\(element.label)'"
        XCTAssertEqual(element.label, expectedLabel, errorMessage, file: file, line: line)
    }

    /// Assert element label contains text
    func assertLabelContains(_ element: XCUIElement,
                            text: String,
                            message: String? = nil,
                            file: StaticString = #filePath,
                            line: UInt = #line) {
        let errorMessage = message ?? "Element label '\(element.label)' should contain '\(text)'"
        XCTAssertTrue(element.label.contains(text), errorMessage, file: file, line: line)
    }

    // MARK: - Wait Helpers

    /// Wait for element to exist and return it (useful for chaining)
    @discardableResult
    func require(_ element: XCUIElement,
                timeout: TimeInterval = 5,
                file: StaticString = #filePath,
                line: UInt = #line) -> XCUIElement {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Expected element to exist", file: file, line: line)
        return element
    }

    /// Wait for element to disappear
    func waitForDisappearance(_ element: XCUIElement,
                             timeout: TimeInterval = 5,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected element to disappear", file: file, line: line)
    }

    /// Wait for multiple elements to exist
    func waitForAll(_ elements: [XCUIElement], timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        for element in elements {
            let remainingTime = max(0, deadline.timeIntervalSinceNow)
            guard element.waitForExistence(timeout: remainingTime) else {
                return false
            }
        }
        return true
    }

    /// Wait for any one of the elements to exist
    func waitForAny(_ elements: [XCUIElement], timeout: TimeInterval = 5) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for element in elements {
                if element.exists {
                    return element
                }
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }

    // MARK: - Retry Mechanism

    /// Retry an action multiple times with delay between attempts
    @discardableResult
    func retry(_ attempts: Int = 3,
              delay: TimeInterval = 1.0,
              action: () -> Bool) -> Bool {
        for attempt in 1...attempts {
            if action() {
                return true
            }
            if attempt < attempts {
                Thread.sleep(forTimeInterval: delay)
            }
        }
        return false
    }

    /// Retry an action until it succeeds or timeout
    @discardableResult
    func retryUntil(timeout: TimeInterval = 5.0,
                   interval: TimeInterval = 0.5,
                   condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            Thread.sleep(forTimeInterval: interval)
        }
        return false
    }

    // MARK: - Screenshot Helpers

    /// Check if we should capture step-by-step screenshots
    var shouldCaptureScreenshots: Bool {
        return ProcessInfo.processInfo.arguments.contains("-CaptureTestScreenshots")
    }

    /// Conditionally capture a screenshot at a test step (only when flag is set)
    /// Use this to document test flow visually without slowing down regular test runs
    @MainActor
    func captureStep(_ name: String) {
        guard shouldCaptureScreenshots else { return }

        // Use XCTest's native screenshot capture
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Take a screenshot with a name
    func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Assert screenshot matches reference (placeholder for future integration)
    @MainActor
    func assertScreenshot(_ name: String,
                         matches reference: Bool = true,
                         file: StaticString = #filePath,
                         line: UInt = #line) {
        snapshot(name)
        // Future: integrate with snapshot comparison tool
    }

    // MARK: - System Alert Handling

    /// Register a system alert monitor with common alert button handlers
    func registerSystemAlertMonitor() -> NSObjectProtocol {
        return addUIInterruptionMonitor(withDescription: "System Alerts") { alert in
            let buttonTitles = [
                "Allow",
                "Allow While Using App",
                "Allow Once",
                "Always Allow",
                "OK",
                "Continue"
            ]

            for title in buttonTitles {
                if alert.buttons[title].exists {
                    alert.buttons[title].tap()
                    return true
                }
            }

            return false
        }
    }

    /// Handle springboard alerts (system permission dialogs)
    func handleSpringboardAlerts(timeout: TimeInterval = 5,
                                 app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: timeout) {
            allowButton.tap()
            app.activate()
        }
    }

    // MARK: - Logging Helpers

    /// Log a message with test context
    func log(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let fileName = (String(describing: file) as NSString).lastPathComponent
        NSLog("[\(fileName):\(line)] \(message)")
    }

    /// Log and assert
    func logAndAssert(_ condition: Bool,
                     _ message: String,
                     file: StaticString = #filePath,
                     line: UInt = #line) {
        log(message, file: file, line: line)
        XCTAssertTrue(condition, message, file: file, line: line)
    }
}
