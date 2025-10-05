//
//  SleepEvent.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 05/10/2025.
//

import CoreData
import Foundation

@objc(SleepEvent)
public class SleepEvent: NSManagedObject {

}

extension SleepEvent {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SleepEvent> {
        return NSFetchRequest<SleepEvent>(entityName: "SleepEvent")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var backdatedAt: Date?
    @NSManaged public var bedTime: Date?
    @NSManaged public var wakeTime: Date?
    @NSManaged public var quality: Int16
    @NSManaged public var note: String?
    @NSManaged public var hkSleepHours: NSNumber?
    @NSManaged public var hkHRV: NSNumber?
    @NSManaged public var hkRestingHR: NSNumber?
    @NSManaged public var symptoms: NSSet?
}

// MARK: Generated accessors for symptoms
extension SleepEvent {
    @objc(addSymptomsObject:)
    @NSManaged public func addToSymptoms(_ value: SymptomType)

    @objc(removeSymptomsObject:)
    @NSManaged public func removeFromSymptoms(_ value: SymptomType)

    @objc(addSymptoms:)
    @NSManaged public func addToSymptoms(_ values: NSSet)

    @objc(removeSymptoms:)
    @NSManaged public func removeFromSymptoms(_ values: NSSet)
}

extension SleepEvent: Identifiable {

}
