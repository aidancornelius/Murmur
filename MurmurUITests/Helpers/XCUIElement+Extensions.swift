//
//  XCUIElement+Extensions.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import XCTest
@testable import Murmur

extension XCUIElement {

    // MARK: - Stable Interactions

    /// Tap when element is stable (animations complete)
    func tapWhenStable(delay: TimeInterval = 0.3) {
        // Wait for element to stop moving/animating
        Thread.sleep(forTimeInterval: delay)
        tap()
    }

    /// Tap after ensuring element is hittable
    func tapWhenHittable(timeout: TimeInterval = 5) -> Bool {
        guard waitForHittable(timeout: timeout) else {
            return false
        }
        tap()
        return true
    }

    /// Wait for element to be hittable
    func waitForHittable(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Wait for element to be enabled
    func waitForEnabled(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Force tap using coordinate
    func forceTap() {
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    // MARK: - Text Input Helpers

    /// Clear text and type new text
    func clearAndType(_ text: String) {
        tap()

        // Try to select all and delete
        if let currentValue = value as? String, !currentValue.isEmpty {
            // Double tap to select word, then select all
            doubleTap()

            // Use keyboard shortcuts if available
            let selectAllMenuItem = XCUIApplication().menuItems["Select All"]
            if selectAllMenuItem.exists {
                selectAllMenuItem.tap()
            }

            // Delete current content
            let deleteKey = XCUIApplication().keys["delete"]
            if deleteKey.exists {
                deleteKey.tap()
            }
        }

        typeText(text)
    }

    /// Type text slowly (character by character with delay)
    func typeTextSlowly(_ text: String, delay: TimeInterval = 0.1) {
        for char in text {
            typeText(String(char))
            Thread.sleep(forTimeInterval: delay)
        }
    }

    // MARK: - Swipe Helpers

    /// Swipe with custom duration
    func swipe(direction: SwipeDirection, velocity: XCUIGestureVelocity = .default, duration: TimeInterval = 0.5) {
        switch direction {
        case .up:
            swipeUp(velocity: velocity)
        case .down:
            swipeDown(velocity: velocity)
        case .left:
            swipeLeft(velocity: velocity)
        case .right:
            swipeRight(velocity: velocity)
        }
    }

    /// Slow swipe (more controlled)
    func slowSwipe(direction: SwipeDirection) {
        let offset: CGVector
        switch direction {
        case .up:
            offset = CGVector(dx: 0.5, dy: 0.1)
        case .down:
            offset = CGVector(dx: 0.5, dy: 0.9)
        case .left:
            offset = CGVector(dx: 0.1, dy: 0.5)
        case .right:
            offset = CGVector(dx: 0.9, dy: 0.5)
        }

        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = coordinate(withNormalizedOffset: offset)
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    // MARK: - Wait Helpers

    /// Wait for element to disappear
    func waitForDisappearance(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Wait for element to have specific label
    func waitForLabel(_ expectedLabel: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Wait for element to contain text in label
    func waitForLabelContaining(_ text: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    /// Wait for element value to change
    func waitForValueChange(from oldValue: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value != %@", oldValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }

    // MARK: - Query Helpers

    /// Check if element contains text in label
    func labelContains(_ text: String) -> Bool {
        label.lowercased().contains(text.lowercased())
    }

    /// Get element frame
    var frameInScreen: CGRect {
        return frame
    }

    /// Check if element is visible in viewport
    var isVisible: Bool {
        return exists && isHittable
    }

    /// Check if element is fully visible (not obscured)
    var isFullyVisible: Bool {
        guard exists else { return false }
        let frame = self.frame
        return frame.origin.x >= 0 &&
               frame.origin.y >= 0 &&
               isHittable
    }

    // MARK: - Scroll Helpers

    /// Scroll to make element visible
    func scrollToVisible(in scrollView: XCUIElement? = nil) {
        guard !isHittable else { return }

        if let scrollView = scrollView {
            // Scroll within specific scroll view
            while !isHittable && scrollView.exists {
                scrollView.swipeUp()
            }
        } else {
            // Try to scroll in any available scroll view
            let app = XCUIApplication()
            let scrollViews = app.scrollViews

            if scrollViews.count > 0 {
                let scrollView = scrollViews.firstMatch
                var attempts = 0
                while !isHittable && scrollView.exists && attempts < 10 {
                    scrollView.swipeUp()
                    attempts += 1
                    Thread.sleep(forTimeInterval: 0.2)
                }
            }
        }
    }

    // MARK: - Slider Helpers

    /// Adjust slider to specific percentage (0.0 to 1.0)
    func adjustSlider(to percentage: CGFloat) {
        guard percentage >= 0.0 && percentage <= 1.0 else { return }
        adjust(toNormalizedSliderPosition: percentage)
    }

    /// Adjust slider to discrete level (e.g., 1-5 scale)
    func adjustSliderToLevel(_ level: Int, maxLevel: Int) {
        guard level >= 1 && level <= maxLevel else { return }
        let percentage = CGFloat(level - 1) / CGFloat(maxLevel - 1)
        adjustSlider(to: percentage)
    }

    // MARK: - Debugging Helpers

    /// Print element details for debugging
    func debugPrint() {
        print("""
        XCUIElement Debug Info:
        - Type: \(elementType)
        - Label: \(label)
        - Identifier: \(identifier)
        - Value: \(value ?? "nil")
        - Exists: \(exists)
        - Hittable: \(isHittable)
        - Enabled: \(isEnabled)
        - Frame: \(frame)
        """)
    }

    /// Take screenshot of element
    func screenshot(named name: String) -> XCTAttachment {
        let screenshot = screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        return attachment
    }
}

// MARK: - Supporting Types

enum SwipeDirection {
    case up, down, left, right
}

// MARK: - XCUIElementQuery Extensions

extension XCUIElementQuery {
    /// Get all elements as array
    var allElements: [XCUIElement] {
        return allElementsBoundByIndex.map { $0 }
    }

    /// Find first element matching predicate
    func first(where predicate: (XCUIElement) -> Bool) -> XCUIElement? {
        return allElements.first(where: predicate)
    }

    /// Filter elements by predicate
    func filter(_ predicate: (XCUIElement) -> Bool) -> [XCUIElement] {
        return allElements.filter(predicate)
    }

    /// Check if any element matches predicate
    func contains(where predicate: (XCUIElement) -> Bool) -> Bool {
        return allElements.contains(where: predicate)
    }
}
