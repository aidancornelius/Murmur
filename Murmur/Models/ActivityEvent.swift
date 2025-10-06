//
//  ActivityEvent.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CoreData
import Foundation

@objc(ActivityEvent)
public class ActivityEvent: NSManagedObject {

}

extension ActivityEvent {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ActivityEvent> {
        return NSFetchRequest<ActivityEvent>(entityName: "ActivityEvent")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var backdatedAt: Date?
    @NSManaged public var name: String?
    @NSManaged public var note: String?
    @NSManaged public var physicalExertion: Int16
    @NSManaged public var cognitiveExertion: Int16
    @NSManaged public var emotionalLoad: Int16
    @NSManaged public var durationMinutes: NSNumber?
    @NSManaged public var calendarEventID: String?
}

extension ActivityEvent: Identifiable {

}

// MARK: - Validation
extension ActivityEvent {
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateExertionLevels()
    }

    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateExertionLevels()
    }

    private func validateExertionLevels() throws {
        guard physicalExertion >= 1 && physicalExertion <= 5 else {
            throw NSError(
                domain: "ActivityEvent",
                code: 3001,
                userInfo: [NSLocalizedDescriptionKey: "Physical exertion must be between 1 and 5"]
            )
        }

        guard cognitiveExertion >= 1 && cognitiveExertion <= 5 else {
            throw NSError(
                domain: "ActivityEvent",
                code: 3002,
                userInfo: [NSLocalizedDescriptionKey: "Cognitive exertion must be between 1 and 5"]
            )
        }

        guard emotionalLoad >= 1 && emotionalLoad <= 5 else {
            throw NSError(
                domain: "ActivityEvent",
                code: 3003,
                userInfo: [NSLocalizedDescriptionKey: "Emotional load must be between 1 and 5"]
            )
        }
    }
}
