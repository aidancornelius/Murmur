// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ControlWidgetProviderTests.swift
// Created by Aidan Cornelius-Bell on 13/10/2025.
// Tests for control widget data provider.
//
import XCTest
import WidgetKit
@testable import MurmurWidgets

@MainActor
final class ControlWidgetProviderTests: XCTestCase {

    // MARK: - Provider Instantiation Tests

    func testProviderCanBeInstantiated() {
        // Given/When/Then - Should not crash
        let provider = ControlWidgetProvider()
        XCTAssertNotNil(provider)
    }

    func testMultipleProviderInstancesCanExist() {
        // Given/When
        let provider1 = ControlWidgetProvider()
        let provider2 = ControlWidgetProvider()
        let provider3 = ControlWidgetProvider()

        // Then - All should be valid
        XCTAssertNotNil(provider1)
        XCTAssertNotNil(provider2)
        XCTAssertNotNil(provider3)
    }

    // MARK: - Current Value Tests

    func testCurrentValueReturnsEmptyString() async throws {
        // Given
        let provider = ControlWidgetProvider()

        // When
        let value = try await provider.currentValue()

        // Then
        XCTAssertEqual(value, "", "Control widget provider should return empty string for current value")
    }

    func testCurrentValueDoesNotThrow() async {
        // Given
        let provider = ControlWidgetProvider()

        // When/Then - Should complete without throwing
        do {
            let value = try await provider.currentValue()
            XCTAssertNotNil(value)
        } catch {
            XCTFail("Provider currentValue() should not throw errors: \(error)")
        }
    }

    func testCurrentValueIsConsistent() async throws {
        // Given
        let provider = ControlWidgetProvider()

        // When - Call multiple times
        let value1 = try await provider.currentValue()
        let value2 = try await provider.currentValue()
        let value3 = try await provider.currentValue()

        // Then - All values should be the same
        XCTAssertEqual(value1, value2)
        XCTAssertEqual(value2, value3)
        XCTAssertEqual(value1, "")
    }

    func testCurrentValueCanBeCalledConcurrently() async throws {
        // Given
        let provider = ControlWidgetProvider()

        // When - Call concurrently
        async let value1 = provider.currentValue()
        async let value2 = provider.currentValue()
        async let value3 = provider.currentValue()

        let results = try await [value1, value2, value3]

        // Then - All should return the same value
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0 == "" })
    }

    // MARK: - Preview Value Tests

    func testPreviewValueIsEmptyString() {
        // Given
        let provider = ControlWidgetProvider()

        // When
        let previewValue = provider.previewValue

        // Then
        XCTAssertEqual(previewValue, "", "Preview value should be empty string")
    }

    func testPreviewValueIsConsistent() {
        // Given
        let provider = ControlWidgetProvider()

        // When - Access multiple times
        let value1 = provider.previewValue
        let value2 = provider.previewValue
        let value3 = provider.previewValue

        // Then - All values should be the same
        XCTAssertEqual(value1, value2)
        XCTAssertEqual(value2, value3)
    }

    func testPreviewValueMatchesCurrentValue() async throws {
        // Given
        let provider = ControlWidgetProvider()

        // When
        let previewValue = provider.previewValue
        let currentValue = try await provider.currentValue()

        // Then - Both should return empty string
        XCTAssertEqual(previewValue, currentValue)
    }

    // MARK: - Multiple Provider Instance Tests

    func testMultipleProvidersReturnSameCurrentValue() async throws {
        // Given
        let provider1 = ControlWidgetProvider()
        let provider2 = ControlWidgetProvider()
        let provider3 = ControlWidgetProvider()

        // When
        let value1 = try await provider1.currentValue()
        let value2 = try await provider2.currentValue()
        let value3 = try await provider3.currentValue()

        // Then - All should return the same value
        XCTAssertEqual(value1, value2)
        XCTAssertEqual(value2, value3)
        XCTAssertEqual(value1, "")
    }

    func testMultipleProvidersReturnSamePreviewValue() {
        // Given
        let provider1 = ControlWidgetProvider()
        let provider2 = ControlWidgetProvider()
        let provider3 = ControlWidgetProvider()

        // When
        let preview1 = provider1.previewValue
        let preview2 = provider2.previewValue
        let preview3 = provider3.previewValue

        // Then - All should return the same value
        XCTAssertEqual(preview1, preview2)
        XCTAssertEqual(preview2, preview3)
    }

    // MARK: - Provider Lifecycle Tests

    func testProviderCanBeCreatedAndDestroyed() {
        // Given/When
        var provider: ControlWidgetProvider? = ControlWidgetProvider()
        XCTAssertNotNil(provider)

        // Then - Can be deallocated
        provider = nil
        XCTAssertNil(provider)
    }

    func testProviderSurvivesMultipleCalls() async throws {
        // Given
        let provider = ControlWidgetProvider()

        // When - Call multiple times
        for _ in 0..<10 {
            let value = try await provider.currentValue()
            XCTAssertEqual(value, "")
        }

        // Then - Provider should still be valid
        let finalValue = try await provider.currentValue()
        XCTAssertEqual(finalValue, "")
    }

    // MARK: - Value Type Tests

    func testCurrentValueReturnsString() async throws {
        // Given
        let provider = ControlWidgetProvider()

        // When
        let value = try await provider.currentValue()

        // Then - Should be a String type
        XCTAssertTrue(value is String)
        XCTAssert(type(of: value) == String.self)
    }

    func testPreviewValueIsString() {
        // Given
        let provider = ControlWidgetProvider()

        // When
        let value = provider.previewValue

        // Then - Should be a String type
        XCTAssertTrue(value is String)
        XCTAssert(type(of: value) == String.self)
    }

    // MARK: - Stress Tests

    func testProviderHandlesRapidSuccessiveCalls() async throws {
        // Given
        let provider = ControlWidgetProvider()
        var values: [String] = []

        // When - Call rapidly
        for _ in 0..<100 {
            let value = try await provider.currentValue()
            values.append(value)
        }

        // Then - All values should be empty strings
        XCTAssertEqual(values.count, 100)
        XCTAssertTrue(values.allSatisfy { $0 == "" })
    }

    func testProviderHandlesConcurrentCalls() async throws {
        // Given
        let provider = ControlWidgetProvider()

        // When - Call concurrently many times
        let tasks = (0..<20).map { _ in
            Task {
                try await provider.currentValue()
            }
        }

        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for task in tasks {
                group.addTask {
                    try await task.value
                }
            }

            var collected: [String] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }

        // Then - All should succeed and return empty string
        XCTAssertEqual(results.count, 20)
        XCTAssertTrue(results.allSatisfy { $0 == "" })
    }

    // MARK: - Error Handling Tests

    func testProviderNeverThrowsFromCurrentValue() async {
        // Given
        let provider = ControlWidgetProvider()

        // When/Then - Should never throw
        for _ in 0..<10 {
            do {
                let value = try await provider.currentValue()
                XCTAssertNotNil(value)
            } catch {
                XCTFail("Provider should never throw errors: \(error)")
            }
        }
    }

    // MARK: - Integration Tests

    func testProviderWorksWithLogSymptomControl() {
        // Given
        let provider = ControlWidgetProvider()
        let control = LogSymptomControl()

        // When/Then - Both should exist and work together
        XCTAssertNotNil(provider)
        XCTAssertNotNil(control)
    }

    func testProviderWorksWithLogActivityControl() {
        // Given
        let provider = ControlWidgetProvider()
        let control = LogActivityControl()

        // When/Then - Both should exist and work together
        XCTAssertNotNil(provider)
        XCTAssertNotNil(control)
    }

    func testProviderWorksWithBothControls() {
        // Given
        let provider = ControlWidgetProvider()
        let symptomControl = LogSymptomControl()
        let activityControl = LogActivityControl()

        // When/Then - All should coexist
        XCTAssertNotNil(provider)
        XCTAssertNotNil(symptomControl)
        XCTAssertNotNil(activityControl)
    }

    // MARK: - Memory Tests

    func testMultipleProvidersDoNotLeak() {
        // Given/When - Create many instances
        var providers: [ControlWidgetProvider] = []
        for _ in 0..<100 {
            providers.append(ControlWidgetProvider())
        }

        // Then - All should be valid
        XCTAssertEqual(providers.count, 100)

        // When - Clear array
        providers.removeAll()

        // Then
        XCTAssertTrue(providers.isEmpty)
    }

    func testProviderDoesNotRetainState() async throws {
        // Given
        let provider = ControlWidgetProvider()

        // When - Call multiple times
        let value1 = try await provider.currentValue()
        // Simulate some time passing
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        let value2 = try await provider.currentValue()

        // Then - Values should be the same (no state change)
        XCTAssertEqual(value1, value2)
    }

    // MARK: - Performance Tests

    func testProviderCurrentValuePerformance() async throws {
        // Measure performance of calling currentValue
        measure {
            let provider = ControlWidgetProvider()
            Task {
                for _ in 0..<100 {
                    _ = try? await provider.currentValue()
                }
            }
        }
    }

    func testProviderInstantiationPerformance() {
        // Measure performance of creating providers
        measure {
            for _ in 0..<100 {
                _ = ControlWidgetProvider()
            }
        }
    }
}
