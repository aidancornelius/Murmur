import CoreLocation
import Contacts
import Foundation
import MapKit

/// Custom value transformer to encode/decode CLPlacemark for Core Data storage.
/// CLPlacemark doesn't conform to NSSecureCoding, so we extract and store key properties as a dictionary.
@objc(PlacemarkTransformer)
final class PlacemarkTransformer: ValueTransformer {

    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let placemark = value as? CLPlacemark else { return nil }

        // Extract key properties from CLPlacemark
        let dict: [String: Any?] = [
            "name": placemark.name,
            "isoCountryCode": placemark.isoCountryCode,
            "country": placemark.country,
            "postalCode": placemark.postalCode,
            "administrativeArea": placemark.administrativeArea,
            "subAdministrativeArea": placemark.subAdministrativeArea,
            "locality": placemark.locality,
            "subLocality": placemark.subLocality,
            "thoroughfare": placemark.thoroughfare,
            "subThoroughfare": placemark.subThoroughfare,
            "latitude": placemark.location?.coordinate.latitude,
            "longitude": placemark.location?.coordinate.longitude,
            "timeZone": placemark.timeZone?.identifier
        ]

        // Remove nil values
        let cleanedDict = dict.compactMapValues { $0 }

        do {
            return try NSKeyedArchiver.archivedData(withRootObject: cleanedDict, requiringSecureCoding: true)
        } catch {
            return nil
        }
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }

        do {
            let allowedClasses: [AnyClass] = [NSDictionary.self, NSString.self, NSNumber.self]
            guard let dict = try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: allowedClasses,
                from: data
            ) as? [String: Any] else {
                return nil
            }

            // Reconstruct CLPlacemark from stored properties
            var location: CLLocation?
            if let lat = dict["latitude"] as? Double,
               let lon = dict["longitude"] as? Double {
                location = CLLocation(latitude: lat, longitude: lon)
            }

            // Create a CLPlacemark from the location
            if let location = location {
                return MKPlacemark(coordinate: location.coordinate)
            }

            return nil
        } catch {
            return nil
        }
    }

    /// Register this transformer with Core Data. Call once at app startup.
    static func register() {
        let transformer = PlacemarkTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: NSValueTransformerName("PlacemarkTransformer"))
    }
}
