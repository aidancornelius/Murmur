import CoreLocation

@MainActor
final class LocationAssistant: NSObject, ObservableObject {
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

    func requestLocation() {
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

extension LocationAssistant: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                state = .requesting
                manager.requestLocation()
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
