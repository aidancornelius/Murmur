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

// MARK: - Validation
extension SleepEvent {
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateRequiredFields()
        try validateSleepQuality()
        try validateSleepDuration()
        try validateDates()
    }

    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateRequiredFields()
        try validateSleepQuality()
        try validateSleepDuration()
        try validateDates()
    }

    private func validateRequiredFields() throws {
        guard let bedTime = bedTime else {
            throw NSError(
                domain: "SleepEvent",
                code: 5001,
                userInfo: [NSLocalizedDescriptionKey: "Bed time is required"]
            )
        }

        guard let wakeTime = wakeTime else {
            throw NSError(
                domain: "SleepEvent",
                code: 5002,
                userInfo: [NSLocalizedDescriptionKey: "Wake time is required"]
            )
        }

        // Validate that wake time is after bed time
        guard wakeTime > bedTime else {
            throw NSError(
                domain: "SleepEvent",
                code: 5004,
                userInfo: [NSLocalizedDescriptionKey: "Wake time must be after bed time"]
            )
        }
    }

    private func validateSleepQuality() throws {
        guard quality >= 1 && quality <= 5 else {
            throw NSError(
                domain: "SleepEvent",
                code: 5003,
                userInfo: [NSLocalizedDescriptionKey: "Sleep quality must be between 1 and 5"]
            )
        }
    }

    private func validateSleepDuration() throws {
        guard let bedTime = bedTime, let wakeTime = wakeTime else {
            return // Already validated in validateRequiredFields
        }

        let duration = wakeTime.timeIntervalSince(bedTime)
        let hours = duration / 3600

        // Validate reasonable sleep duration (between 1 minute and 24 hours)
        guard hours >= 1.0 / 60.0 else {
            throw NSError(
                domain: "SleepEvent",
                code: 5005,
                userInfo: [NSLocalizedDescriptionKey: "Sleep duration must be at least 1 minute"]
            )
        }

        guard hours <= 24 else {
            throw NSError(
                domain: "SleepEvent",
                code: 5006,
                userInfo: [NSLocalizedDescriptionKey: "Sleep duration cannot exceed 24 hours. Please check your times."]
            )
        }
    }

    private func validateDates() throws {
        let now = Date()

        // Validate createdAt is not in future
        if let created = createdAt, created > now.addingTimeInterval(60) {
            throw NSError(
                domain: "SleepEvent",
                code: 5007,
                userInfo: [NSLocalizedDescriptionKey: "Created date cannot be in the future"]
            )
        }

        // Validate sleep times are within reasonable range (1 week)
        if let bedTime = bedTime {
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            let oneDayFuture = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now

            guard bedTime >= oneWeekAgo && bedTime <= oneDayFuture else {
                throw NSError(
                    domain: "SleepEvent",
                    code: 5008,
                    userInfo: [NSLocalizedDescriptionKey: "Bed time must be within the past week"]
                )
            }
        }
    }
}
