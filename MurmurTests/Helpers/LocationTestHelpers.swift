// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// LocationTestHelpers.swift
// Created by Aidan Cornelius-Bell on 06/10/2025.
// Helper utilities for location-related tests.
//
import Contacts
import CoreLocation
import MapKit
import XCTest
@testable import Murmur

// MARK: - Mock CLLocationManager

/// Mock CLLocationManager for testing location services without actual GPS
@MainActor
final class MockCLLocationManager: CLLocationManager, @unchecked Sendable {
    var mockAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var mockLocation: CLLocation?
    var shouldFailLocationRequest = false
    var requestLocationCallCount = 0
    var requestAuthorizationCallCount = 0

    override var authorizationStatus: CLAuthorizationStatus {
        mockAuthorizationStatus
    }

    override func requestWhenInUseAuthorization() {
        requestAuthorizationCallCount += 1

        // Simulate authorization status change
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            delegate?.locationManagerDidChangeAuthorization?(self)
        }
    }

    override func requestLocation() {
        requestLocationCallCount += 1

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

            if shouldFailLocationRequest {
                let error = NSError(domain: kCLErrorDomain, code: CLError.locationUnknown.rawValue)
                delegate?.locationManager?(self, didFailWithError: error)
            } else if let location = mockLocation {
                delegate?.locationManager?(self, didUpdateLocations: [location])
            } else {
                let error = NSError(domain: kCLErrorDomain, code: CLError.locationUnknown.rawValue)
                delegate?.locationManager?(self, didFailWithError: error)
            }
        }
    }

    func reset() {
        mockAuthorizationStatus = .notDetermined
        mockLocation = nil
        shouldFailLocationRequest = false
        requestLocationCallCount = 0
        requestAuthorizationCallCount = 0
    }
}

// MARK: - Mock LocationAssistant

/// Mock implementation of LocationAssistantProtocol for testing
@MainActor
final class MockLocationAssistant: LocationAssistantProtocol {
    @Published private(set) var state: LocationAssistant.State = .idle

    var mockPlacemark: CLPlacemark?
    var shouldDenyPermission = false
    var shouldFailLocationFetch = false
    var requestLocationCallCount = 0

    func requestLocation() {
        requestLocationCallCount += 1

        if shouldDenyPermission {
            state = .denied
        } else if shouldFailLocationFetch {
            state = .idle
        } else if let placemark = mockPlacemark {
            state = .resolved(placemark)
        } else {
            state = .requesting
        }
    }

    func currentPlacemark() async -> CLPlacemark? {
        if case .resolved(let placemark) = state {
            return placemark
        }
        return mockPlacemark
    }

    func reset() {
        state = .idle
        mockPlacemark = nil
        shouldDenyPermission = false
        shouldFailLocationFetch = false
        requestLocationCallCount = 0
    }

    /// Helper to set a resolved state directly
    func setResolved(placemark: CLPlacemark) {
        mockPlacemark = placemark
        state = .resolved(placemark)
    }

    /// Helper to set denied state
    func setDenied() {
        state = .denied
    }

    /// Helper to set requesting state
    func setRequesting() {
        state = .requesting
    }
}

// MARK: - Mock CLPlacemark Creation

extension CLPlacemark {
    /// Create a mock placemark for testing
    /// Note: CLPlacemark is difficult to mock due to read-only properties
    /// This uses a workaround to create test placemarks
    static func mockPlacemark(
        locality: String? = nil,
        subLocality: String? = nil,
        country: String? = nil,
        postalCode: String? = nil,
        administrativeArea: String? = nil
    ) -> CLPlacemark {
        // Create a CLPlacemark using reverse geocoding
        // This is a workaround since CLPlacemark properties are read-only
        let location = CLLocation(latitude: -33.8688, longitude: 151.2093)

        // Create address dictionary using string keys
        var addressDict: [String: Any] = [:]
        if let locality = locality {
            addressDict["City"] = locality
        }
        if let subLocality = subLocality {
            addressDict["SubLocality"] = subLocality
        }
        if let country = country {
            addressDict["Country"] = country
        }
        if let postalCode = postalCode {
            addressDict["ZIP"] = postalCode
        }
        if let administrativeArea = administrativeArea {
            addressDict["State"] = administrativeArea
        }

        // Use MKPlacemark which allows initialization with address dictionary
        let mkPlacemark = MKPlacemark(
            coordinate: location.coordinate,
            addressDictionary: addressDict as [String: Any]
        )

        // Convert to CLPlacemark
        return mkPlacemark as CLPlacemark
    }

    /// Convenience method for Sydney location
    static func mockSydney() -> CLPlacemark {
        mockPlacemark(locality: "Sydney", country: "Australia")
    }

    /// Convenience method for Melbourne location
    static func mockMelbourne() -> CLPlacemark {
        mockPlacemark(locality: "Melbourne", country: "Australia")
    }

    /// Convenience method for location with no locality
    static func mockNoLocality() -> CLPlacemark {
        mockPlacemark(country: "Australia")
    }

    /// Convenience method for completely empty placemark
    static func mockEmpty() -> CLPlacemark {
        mockPlacemark()
    }
}

// MARK: - XCTest Async Error Assertion

extension XCTestCase {
    /// Assert that an async throwing function throws an error
    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail(message(), file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }

    /// Assert that an async throwing function does not throw
    func XCTAssertNoThrowAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTFail(message().isEmpty ? "Async expression threw error: \(error)" : message(), file: file, line: line)
        }
    }
}
