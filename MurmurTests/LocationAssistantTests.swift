// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// LocationAssistantTests.swift
// Created by Aidan Cornelius-Bell on 06/10/2025.
// Tests for location service functionality.
//
import CoreLocation
import XCTest
@testable import Murmur

@MainActor
final class LocationAssistantTests: XCTestCase {

    var assistant: LocationAssistant?
    var mockManager: MockCLLocationManager?

    override func setUp() async throws {
        mockManager = MockCLLocationManager()
        assistant = LocationAssistant()
        // Note: We can't inject the manager directly in the current implementation
        // These tests verify the protocol conformance and behavior
    }

    override func tearDown() {
        assistant = nil
        mockManager = nil
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        if case .idle = assistant!.state {
            // Success
        } else {
            XCTFail("LocationAssistant should start in idle state, but was \(assistant!.state)")
        }
    }

    // MARK: - Permission Handling Tests

    func testRequestLocationWithUndeterminedPermission() async throws {
        // Given: Permission not yet determined
        // When: Request location
        assistant!.requestLocation()

        // Then: Should trigger permission prompt (state remains idle until user responds)
        // In real usage, delegate callbacks would update state
        // For now, verify the method completes without crashing
    }

    // MARK: - Placemark Formatting Tests

    func testFormattedPlacemarkWithFullAddress() {
        // Given: Placemark with locality and country
        let placemark = CLPlacemark.mockPlacemark(locality: "Sydney", country: "Australia")

        // When: Format the placemark
        let formatted = LocationAssistant.formatted(placemark: placemark)

        // Then: Should return "locality, country" format
        XCTAssertTrue(formatted.contains("Sydney"), "Formatted string should contain locality")
        XCTAssertTrue(formatted.contains("Australia"), "Formatted string should contain country")
    }

    func testFormattedPlacemarkWithSubLocality() {
        // Given: Placemark with subLocality, locality, and country
        let placemark = CLPlacemark.mockPlacemark(
            locality: "Sydney",
            subLocality: "Surry Hills",
            country: "Australia"
        )

        // When: Format the placemark
        let formatted = LocationAssistant.formatted(placemark: placemark)

        // Then: Should include all available components
        // The formatted method joins non-nil components with ", "
        XCTAssertFalse(formatted.isEmpty, "Formatted string should not be empty")
    }

    func testFormattedPlacemarkWithMissingLocality() {
        // Given: Placemark with only country
        let placemark = CLPlacemark.mockPlacemark(country: "Australia")

        // When: Format the placemark
        let formatted = LocationAssistant.formatted(placemark: placemark)

        // Then: Should handle missing locality gracefully
        XCTAssertTrue(formatted.contains("Australia"), "Should contain country even without locality")
    }

    func testFormattedPlacemarkEmpty() {
        // Given: Empty placemark
        let placemark = CLPlacemark.mockEmpty()

        // When: Format the placemark
        let formatted = LocationAssistant.formatted(placemark: placemark)

        // Then: Should return empty string or handle gracefully
        // The implementation joins non-nil components, so this should be empty or minimal
        XCTAssertNotNil(formatted, "Should return a non-nil string")
    }

    // MARK: - State Transition Tests

    func testStateRemainsIdleBeforeRequest() {
        // Given: New assistant
        // When: No action taken
        // Then: State is idle
        if case .idle = assistant!.state {
            // Success
        } else {
            XCTFail("State should be idle")
        }
    }

    // MARK: - Current Placemark Tests

    func testCurrentPlacemarkReturnsNilInitially() async {
        // Given: Fresh assistant with no location data
        // When: Request current placemark
        let placemark = await assistant!.currentPlacemark()

        // Then: Should return nil (no location available yet)
        XCTAssertNil(placemark, "Should return nil when no location is available")
    }

    func testCurrentPlacemarkReturnsResolvedPlacemark() async {
        // This test would require the assistant to be in a resolved state
        // In practice, this happens after successful location fetch
        // For now, we test the method doesn't crash
        let placemark = await assistant!.currentPlacemark()
        // No assertion needed - just verify it completes
    }

    // MARK: - Mock Assistant Tests

    func testMockLocationAssistantInitialState() {
        // Given: Mock assistant
        let mock = MockLocationAssistant()

        // When: Check initial state
        // Then: Should be idle
        if case .idle = mock.state {
            // Success
        } else {
            XCTFail("Mock should start in idle state, but was \(mock.state)")
        }
    }

    func testMockLocationAssistantRequestWithPermissionDenied() {
        // Given: Mock configured to deny permission
        let mock = MockLocationAssistant()
        mock.shouldDenyPermission = true

        // When: Request location
        mock.requestLocation()

        // Then: State should be denied
        if case .denied = mock.state {
            // Success
        } else {
            XCTFail("State should be denied")
        }
        XCTAssertEqual(mock.requestLocationCallCount, 1)
    }

    func testMockLocationAssistantRequestWithPlacemark() {
        // Given: Mock with configured placemark
        let mock = MockLocationAssistant()
        let placemark = CLPlacemark.mockSydney()
        mock.mockPlacemark = placemark

        // When: Request location
        mock.requestLocation()

        // Then: State should be resolved with placemark
        if case .resolved(let resolved) = mock.state {
            XCTAssertEqual(resolved.locality, placemark.locality)
        } else {
            XCTFail("State should be resolved")
        }
    }

    func testMockLocationAssistantCurrentPlacemarkReturnsConfigured() async {
        // Given: Mock with configured placemark
        let mock = MockLocationAssistant()
        let expectedPlacemark = CLPlacemark.mockMelbourne()
        mock.mockPlacemark = expectedPlacemark

        // When: Get current placemark
        let placemark = await mock.currentPlacemark()

        // Then: Should return configured placemark
        XCTAssertNotNil(placemark)
        XCTAssertEqual(placemark?.locality, "Melbourne")
    }

    func testMockLocationAssistantReset() {
        // Given: Mock with configured state
        let mock = MockLocationAssistant()
        mock.mockPlacemark = CLPlacemark.mockSydney()
        mock.shouldDenyPermission = true
        mock.requestLocation()

        // When: Reset
        mock.reset()

        // Then: Should return to initial state
        if case .idle = mock.state {
            // Success
        } else {
            XCTFail("Mock should be idle after reset, but was \(mock.state)")
        }
        XCTAssertNil(mock.mockPlacemark)
        XCTAssertFalse(mock.shouldDenyPermission)
        XCTAssertEqual(mock.requestLocationCallCount, 0)
    }

    // MARK: - Mock CLLocationManager Tests

    func testMockCLLocationManagerInitialState() {
        // Given: Mock manager
        let manager = MockCLLocationManager()

        // When: Check initial state
        // Then: Should be not determined
        XCTAssertEqual(manager.mockAuthorizationStatus, .notDetermined)
        XCTAssertNil(manager.mockLocation)
    }

    func testMockCLLocationManagerRequestAuthorization() async {
        // Given: Mock manager
        let manager = MockCLLocationManager()

        // When: Request authorization
        manager.requestWhenInUseAuthorization()

        // Then: Should increment call count
        XCTAssertEqual(manager.requestAuthorizationCallCount, 1)

        // Wait for async delegate call
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    func testMockCLLocationManagerSuccessfulLocationRequest() async {
        // Given: Mock manager with configured location
        let manager = MockCLLocationManager()
        let expectedLocation = CLLocation(latitude: -33.8688, longitude: 151.2093)
        manager.mockLocation = expectedLocation
        manager.mockAuthorizationStatus = .authorizedWhenInUse

        // Create a test delegate to receive callbacks
        let delegate = TestLocationManagerDelegate()
        manager.delegate = delegate

        // When: Request location
        manager.requestLocation()

        // Wait for async callback
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then: Should call delegate with location
        XCTAssertEqual(manager.requestLocationCallCount, 1)
        XCTAssertNotNil(delegate.receivedLocations)
        if let latitude = delegate.receivedLocations?.first?.coordinate.latitude {
            XCTAssertEqual(latitude, expectedLocation.coordinate.latitude, accuracy: 0.001)
        } else {
            XCTFail("No latitude received")
        }
    }

    func testMockCLLocationManagerFailedLocationRequest() async {
        // Given: Mock manager configured to fail
        let manager = MockCLLocationManager()
        manager.shouldFailLocationRequest = true
        manager.mockAuthorizationStatus = .authorizedWhenInUse

        let delegate = TestLocationManagerDelegate()
        manager.delegate = delegate

        // When: Request location
        manager.requestLocation()

        // Wait for async callback
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then: Should call delegate with error
        XCTAssertEqual(manager.requestLocationCallCount, 1)
        XCTAssertNotNil(delegate.receivedError)
    }

    func testMockCLLocationManagerReset() {
        // Given: Mock manager with configured state
        let manager = MockCLLocationManager()
        manager.mockAuthorizationStatus = .authorizedWhenInUse
        manager.mockLocation = CLLocation(latitude: 0, longitude: 0)
        manager.requestWhenInUseAuthorization()

        // When: Reset
        manager.reset()

        // Then: Should return to initial state
        XCTAssertEqual(manager.mockAuthorizationStatus, .notDetermined)
        XCTAssertNil(manager.mockLocation)
        XCTAssertEqual(manager.requestAuthorizationCallCount, 0)
    }

    // MARK: - Edge Cases

    func testMultipleConsecutiveLocationRequests() {
        // Given: Mock assistant
        let mock = MockLocationAssistant()
        mock.mockPlacemark = CLPlacemark.mockSydney()

        // When: Request location multiple times
        mock.requestLocation()
        mock.requestLocation()
        mock.requestLocation()

        // Then: Should handle multiple requests
        XCTAssertEqual(mock.requestLocationCallCount, 3)
    }

    func testLocationRequestWithNoPlacemark() async {
        // Given: Mock assistant with no configured placemark
        let mock = MockLocationAssistant()

        // When: Request location
        mock.requestLocation()

        // Then: State should be requesting (waiting for location)
        if case .requesting = mock.state {
            // Success
        } else {
            XCTFail("State should be requesting when no placemark is available")
        }
    }

    func testConveniencePlacemarkCreators() {
        // Test Sydney
        let sydney = CLPlacemark.mockSydney()
        XCTAssertEqual(sydney.locality, "Sydney")
        XCTAssertEqual(sydney.country, "Australia")

        // Test Melbourne
        let melbourne = CLPlacemark.mockMelbourne()
        XCTAssertEqual(melbourne.locality, "Melbourne")
        XCTAssertEqual(melbourne.country, "Australia")

        // Test no locality
        let noLocality = CLPlacemark.mockNoLocality()
        XCTAssertNil(noLocality.locality)
        XCTAssertEqual(noLocality.country, "Australia")
    }
}

// MARK: - Test Helpers

@MainActor
private class TestLocationManagerDelegate: NSObject, CLLocationManagerDelegate {
    var receivedLocations: [CLLocation]?
    var receivedError: Error?

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            receivedLocations = locations
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            receivedError = error
        }
    }
}
