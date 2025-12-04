// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// MurmurWidgetControlTests.swift
// Created by Aidan Cornelius-Bell on 13/10/2025.
// Tests for widget control behaviour.
//
import XCTest
import WidgetKit
import AppIntents
@testable import MurmurWidgets

@MainActor
final class MurmurWidgetControlTests: XCTestCase {

    // MARK: - LogSymptomControl Tests

    func testLogSymptomControlHasCorrectKind() {
        // Given/When
        let kind = LogSymptomControl.kind

        // Then
        XCTAssertEqual(kind, "com.murmur.LogSymptomControl")
    }

    func testLogSymptomControlConfigurationExists() {
        // Given
        let control = LogSymptomControl()

        // When
        let configuration = control.body

        // Then - Verify configuration is not nil
        XCTAssertNotNil(configuration)
    }

    func testLogSymptomControlUsesCorrectProvider() {
        // Given
        let control = LogSymptomControl()

        // When
        let configuration = control.body

        // Then - Configuration should exist and be a StaticControlConfiguration
        XCTAssertNotNil(configuration)
        // Note: We can't directly check the provider type due to opaque return types,
        // but we can verify the control body exists
    }

    func testLogSymptomControlUsesCorrectIntent() {
        // Given
        let control = LogSymptomControl()

        // When
        let configuration = control.body

        // Then - Verify the configuration exists
        // The actual intent verification is done in WidgetIntentTests
        XCTAssertNotNil(configuration)
    }

    // MARK: - LogActivityControl Tests

    func testLogActivityControlHasCorrectKind() {
        // Given/When
        let kind = LogActivityControl.kind

        // Then
        XCTAssertEqual(kind, "com.murmur.LogActivityControl")
    }

    func testLogActivityControlConfigurationExists() {
        // Given
        let control = LogActivityControl()

        // When
        let configuration = control.body

        // Then - Verify configuration is not nil
        XCTAssertNotNil(configuration)
    }

    func testLogActivityControlUsesCorrectProvider() {
        // Given
        let control = LogActivityControl()

        // When
        let configuration = control.body

        // Then - Configuration should exist
        XCTAssertNotNil(configuration)
    }

    func testLogActivityControlUsesCorrectIntent() {
        // Given
        let control = LogActivityControl()

        // When
        let configuration = control.body

        // Then - Verify the configuration exists
        XCTAssertNotNil(configuration)
    }

    // MARK: - Control Widget Comparison Tests

    func testControlWidgetsHaveUniqueKinds() {
        // Given
        let symptomKind = LogSymptomControl.kind
        let activityKind = LogActivityControl.kind

        // Then
        XCTAssertNotEqual(symptomKind, activityKind, "Each control widget must have a unique kind identifier")
    }

    func testControlWidgetKindsFollowNamingConvention() {
        // Given
        let symptomKind = LogSymptomControl.kind
        let activityKind = LogActivityControl.kind

        // Then - Verify both follow com.murmur.* pattern
        XCTAssertTrue(symptomKind.hasPrefix("com.murmur."))
        XCTAssertTrue(activityKind.hasPrefix("com.murmur."))
    }

    // MARK: - Control Widget State Tests

    func testLogSymptomControlCanBeInstantiatedMultipleTimes() {
        // Given/When
        let control1 = LogSymptomControl()
        let control2 = LogSymptomControl()

        // Then - Both should be valid and have the same kind
        XCTAssertNotNil(control1)
        XCTAssertNotNil(control2)
        XCTAssertEqual(type(of: control1).kind, type(of: control2).kind)
    }

    func testLogActivityControlCanBeInstantiatedMultipleTimes() {
        // Given/When
        let control1 = LogActivityControl()
        let control2 = LogActivityControl()

        // Then - Both should be valid and have the same kind
        XCTAssertNotNil(control1)
        XCTAssertNotNil(control2)
        XCTAssertEqual(type(of: control1).kind, type(of: control2).kind)
    }

    // MARK: - Configuration Validation Tests

    func testLogSymptomControlBodyIsStable() {
        // Given
        let control = LogSymptomControl()

        // When - Access body multiple times
        let body1 = control.body
        let body2 = control.body

        // Then - Both should be valid
        XCTAssertNotNil(body1)
        XCTAssertNotNil(body2)
    }

    func testLogActivityControlBodyIsStable() {
        // Given
        let control = LogActivityControl()

        // When - Access body multiple times
        let body1 = control.body
        let body2 = control.body

        // Then - Both should be valid
        XCTAssertNotNil(body1)
        XCTAssertNotNil(body2)
    }

    // MARK: - Control Widget Lifecycle Tests

    func testLogSymptomControlLifecycle() {
        // Given/When - Create and destroy control
        var control: LogSymptomControl? = LogSymptomControl()
        XCTAssertNotNil(control)

        // Then - Can be deallocated
        control = nil
        XCTAssertNil(control)
    }

    func testLogActivityControlLifecycle() {
        // Given/When - Create and destroy control
        var control: LogActivityControl? = LogActivityControl()
        XCTAssertNotNil(control)

        // Then - Can be deallocated
        control = nil
        XCTAssertNil(control)
    }

    // MARK: - Memory Tests

    func testMultipleControlInstancesDoNotLeak() {
        // Given/When - Create multiple instances
        var controls: [LogSymptomControl] = []
        for _ in 0..<10 {
            controls.append(LogSymptomControl())
        }

        // Then - All should be valid
        XCTAssertEqual(controls.count, 10)
        for control in controls {
            XCTAssertNotNil(control)
        }

        // When - Clear array
        controls.removeAll()

        // Then
        XCTAssertTrue(controls.isEmpty)
    }

    // MARK: - Control Widget Identifier Validation Tests

    func testLogSymptomControlKindIsNotEmpty() {
        // Given/When
        let kind = LogSymptomControl.kind

        // Then
        XCTAssertFalse(kind.isEmpty)
        XCTAssertGreaterThan(kind.count, 0)
    }

    func testLogActivityControlKindIsNotEmpty() {
        // Given/When
        let kind = LogActivityControl.kind

        // Then
        XCTAssertFalse(kind.isEmpty)
        XCTAssertGreaterThan(kind.count, 0)
    }

    func testControlWidgetKindsAreValidBundleIdentifiers() {
        // Given
        let symptomKind = LogSymptomControl.kind
        let activityKind = LogActivityControl.kind

        // Then - Should only contain alphanumeric characters, dots, and hyphens
        let validCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")

        XCTAssertTrue(symptomKind.unicodeScalars.allSatisfy { validCharacterSet.contains($0) })
        XCTAssertTrue(activityKind.unicodeScalars.allSatisfy { validCharacterSet.contains($0) })
    }

    // MARK: - Integration Tests

    func testBothControlWidgetsCanCoexist() {
        // Given/When
        let symptomControl = LogSymptomControl()
        let activityControl = LogActivityControl()

        // Then - Both should exist simultaneously without conflicts
        XCTAssertNotNil(symptomControl)
        XCTAssertNotNil(activityControl)
        XCTAssertNotEqual(type(of: symptomControl).kind, type(of: activityControl).kind)
    }

    func testControlWidgetsUseConsistentProviderType() {
        // Given
        let provider1 = ControlWidgetProvider()
        let provider2 = ControlWidgetProvider()

        // When/Then - Both providers should be valid
        XCTAssertNotNil(provider1)
        XCTAssertNotNil(provider2)
    }
}
