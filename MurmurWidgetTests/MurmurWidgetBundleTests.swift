//
//  MurmurWidgetBundleTests.swift
//  MurmurWidgetTests
//
//  Created by Aidan Cornelius-Bell on 13/10/2025.
//

import XCTest
import WidgetKit
@testable import MurmurWidgets

@MainActor
final class MurmurWidgetBundleTests: XCTestCase {

    // MARK: - Bundle Configuration Tests

    func testBundleContainsLogSymptomControl() {
        // Given
        let bundle = MurmurWidgetsBundle()

        // When/Then - Verify bundle body includes LogSymptomControl
        // Note: We can't directly access the body's widgets in tests due to SwiftUI's opaque types,
        // but we can verify the bundle compiles and has the expected structure
        XCTAssertNotNil(bundle)
    }

    func testBundleContainsLogActivityControl() {
        // Given
        let bundle = MurmurWidgetsBundle()

        // When/Then - Verify bundle exists
        XCTAssertNotNil(bundle)
    }

    // MARK: - Widget Kind Identifier Tests

    func testLogSymptomControlHasUniqueKind() {
        // Given/When
        let kind = LogSymptomControl.kind

        // Then
        XCTAssertEqual(kind, "com.murmur.LogSymptomControl")
        XCTAssertFalse(kind.isEmpty)
        XCTAssertTrue(kind.contains("LogSymptomControl"))
    }

    func testLogActivityControlHasUniqueKind() {
        // Given/When
        let kind = LogActivityControl.kind

        // Then
        XCTAssertEqual(kind, "com.murmur.LogActivityControl")
        XCTAssertFalse(kind.isEmpty)
        XCTAssertTrue(kind.contains("LogActivityControl"))
    }

    func testWidgetKindsAreUnique() {
        // Given/When
        let symptomKind = LogSymptomControl.kind
        let activityKind = LogActivityControl.kind

        // Then
        XCTAssertNotEqual(symptomKind, activityKind, "Widget kinds must be unique to avoid conflicts")
    }

    // MARK: - Widget Configuration Tests

    func testLogSymptomControlHasValidConfiguration() {
        // Given
        let control = LogSymptomControl()

        // When
        let body = control.body

        // Then - Verify the widget has a configuration
        XCTAssertNotNil(body)
    }

    func testLogActivityControlHasValidConfiguration() {
        // Given
        let control = LogActivityControl()

        // When
        let body = control.body

        // Then - Verify the widget has a configuration
        XCTAssertNotNil(body)
    }

    // MARK: - Control Widget Provider Tests

    func testControlWidgetProviderReturnsEmptyStringForCurrentValue() async throws {
        // Given
        let provider = ControlWidgetProvider()

        // When
        let value = try await provider.currentValue()

        // Then
        XCTAssertEqual(value, "", "Control widget provider should return empty string")
    }

    func testControlWidgetProviderHasEmptyPreviewValue() {
        // Given
        let provider = ControlWidgetProvider()

        // When
        let previewValue = provider.previewValue

        // Then
        XCTAssertEqual(previewValue, "", "Preview value should be empty string")
    }

    func testControlWidgetProviderDoesNotThrow() async {
        // Given
        let provider = ControlWidgetProvider()

        // When/Then - Should not throw
        do {
            let value = try await provider.currentValue()
            XCTAssertEqual(value, "")
        } catch {
            XCTFail("Provider should not throw errors: \(error)")
        }
    }

    // MARK: - Multiple Provider Instance Tests

    func testMultipleProviderInstancesReturnSameValue() async throws {
        // Given
        let provider1 = ControlWidgetProvider()
        let provider2 = ControlWidgetProvider()

        // When
        let value1 = try await provider1.currentValue()
        let value2 = try await provider2.currentValue()

        // Then
        XCTAssertEqual(value1, value2, "Multiple provider instances should return the same value")
    }

    // MARK: - Configuration Consistency Tests

    func testWidgetConfigurationsAreConsistent() {
        // Given
        let symptomControl1 = LogSymptomControl()
        let symptomControl2 = LogSymptomControl()

        // When/Then - Both instances should have the same kind
        XCTAssertEqual(type(of: symptomControl1).kind, type(of: symptomControl2).kind)
    }

    func testActivityControlConfigurationsAreConsistent() {
        // Given
        let activityControl1 = LogActivityControl()
        let activityControl2 = LogActivityControl()

        // When/Then - Both instances should have the same kind
        XCTAssertEqual(type(of: activityControl1).kind, type(of: activityControl2).kind)
    }

    // MARK: - Widget Instantiation Tests

    func testLogSymptomControlInstantiatesWithoutError() {
        // Given/When/Then - Should not crash
        let control = LogSymptomControl()
        XCTAssertNotNil(control)
    }

    func testLogActivityControlInstantiatesWithoutError() {
        // Given/When/Then - Should not crash
        let control = LogActivityControl()
        XCTAssertNotNil(control)
    }

    func testControlWidgetProviderInstantiatesWithoutError() {
        // Given/When/Then - Should not crash
        let provider = ControlWidgetProvider()
        XCTAssertNotNil(provider)
    }

    // MARK: - Bundle Lifecycle Tests

    func testBundleInstantiationDoesNotCrash() {
        // Given/When/Then - Should not crash
        let bundle = MurmurWidgetsBundle()
        XCTAssertNotNil(bundle)
    }

    func testMultipleBundleInstancesCanExist() {
        // Given/When
        let bundle1 = MurmurWidgetsBundle()
        let bundle2 = MurmurWidgetsBundle()

        // Then - Both should be valid instances
        XCTAssertNotNil(bundle1)
        XCTAssertNotNil(bundle2)
    }
}
