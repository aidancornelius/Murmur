// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// LocationAssistant.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Service for location access and reverse geocoding.
//
import Combine
import CoreLocation

// MARK: - Protocol

/// Protocol for location services to enable dependency injection and testing
@MainActor
protocol LocationAssistantProtocol: AnyObject {
    var state: LocationAssistant.State { get }
    func requestLocation()
    func currentPlacemark() async -> CLPlacemark?
}

// MARK: - Implementation

@MainActor
final class LocationAssistant: NSObject, LocationAssistantProtocol, ObservableObject {
    enum State {
        case idle
        case requesting
        case denied
        case resolved(CLPlacemark)
    }

    @Published private(set) var state: State = .idle

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var latestPlacemark: CLPlacemark?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // Cleanup is performed via ResourceManageable protocol instead of deinit
    // to avoid accessing non-Sendable types from deinit in Swift 6

    func requestLocation() {
        // Skip location request if disabled for UI testing
        if UITestConfiguration.shouldDisableLocation {
            state = .idle
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            state = .denied
        default:
            state = .requesting
            manager.requestLocation()
        }
    }

    func currentPlacemark() async -> CLPlacemark? {
        if case let .resolved(placemark) = state {
            return placemark
        }
        guard let location = manager.location else { return latestPlacemark }
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                latestPlacemark = placemark
                state = .resolved(placemark)
                return placemark
            }
        } catch {
            return latestPlacemark
        }
        return latestPlacemark
    }

    static func formatted(placemark: CLPlacemark) -> String {
        [placemark.subLocality, placemark.locality, placemark.country]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

// MARK: - ResourceManageable Conformance

extension LocationAssistant: ResourceManageable {
    nonisolated func start() async throws {
        // No initialization required
    }

    nonisolated func cleanup() {
        // Delegate to MainActor-isolated cleanup
        Task { @MainActor in
            self._cleanup()
        }
    }

    private func _cleanup() {
        manager.stopUpdatingLocation()
        manager.delegate = nil
        geocoder.cancelGeocode()
    }
}

// MARK: - CLLocationManagerDelegate Conformance

extension LocationAssistant: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch self.manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                state = .requesting
                self.manager.requestLocation()
            case .denied, .restricted:
                state = .denied
            case .notDetermined:
                state = .idle
            @unknown default:
                state = .idle
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            state = .denied
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task {@MainActor in
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    latestPlacemark = placemark
                    state = .resolved(placemark)
                }
            } catch {
                state = .denied
            }
        }
    }
}
