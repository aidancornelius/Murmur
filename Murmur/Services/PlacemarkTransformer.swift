//
//  PlacemarkTransformer.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

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

            // Reconstruct location
            var location: CLLocation?
            if let lat = dict["latitude"] as? Double,
               let lon = dict["longitude"] as? Double {
                location = CLLocation(latitude: lat, longitude: lon)
            }

            // Build postal address dictionary for full reconstruction
            var addressDict: [String: Any] = [:]

            if let name = dict["name"] as? String {
                addressDict[CNPostalAddressStreetKey] = name
            }
            if let thoroughfare = dict["thoroughfare"] as? String {
                addressDict[CNPostalAddressStreetKey] = thoroughfare
            }
            if let subThoroughfare = dict["subThoroughfare"] as? String {
                // Combine with thoroughfare if present
                if let street = addressDict[CNPostalAddressStreetKey] as? String {
                    addressDict[CNPostalAddressStreetKey] = "\(subThoroughfare) \(street)"
                }
            }
            if let locality = dict["locality"] as? String {
                addressDict[CNPostalAddressCityKey] = locality
            }
            if let subLocality = dict["subLocality"] as? String {
                addressDict["SubLocality"] = subLocality
            }
            if let administrativeArea = dict["administrativeArea"] as? String {
                addressDict[CNPostalAddressStateKey] = administrativeArea
            }
            if let subAdministrativeArea = dict["subAdministrativeArea"] as? String {
                addressDict["SubAdministrativeArea"] = subAdministrativeArea
            }
            if let postalCode = dict["postalCode"] as? String {
                addressDict[CNPostalAddressPostalCodeKey] = postalCode
            }
            if let country = dict["country"] as? String {
                addressDict[CNPostalAddressCountryKey] = country
            }
            if let isoCountryCode = dict["isoCountryCode"] as? String {
                addressDict[CNPostalAddressISOCountryCodeKey] = isoCountryCode
            }

            // Create MKPlacemark with full address dictionary
            if let location = location {
                return MKPlacemark(coordinate: location.coordinate, addressDictionary: addressDict)
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
