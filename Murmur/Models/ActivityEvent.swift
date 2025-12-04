// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ActivityEvent.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Core Data entity representing a logged activity event.
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
        try validateRequiredFields()
        try validateExertionLevels()
        try validateDuration()
        try validateDates()
    }

    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateRequiredFields()
        try validateExertionLevels()
        try validateDuration()
        try validateDates()
    }

    private func validateRequiredFields() throws {
        guard let name = name, !name.isEmpty else {
            throw NSError(
                domain: "ActivityEvent",
                code: 3004,
                userInfo: [NSLocalizedDescriptionKey: "Activity name is required"]
            )
        }
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

    private func validateDuration() throws {
        guard let durationMinutes = durationMinutes else {
            return // Duration is optional
        }

        let minutes = durationMinutes.intValue

        // Validate reasonable duration (1 minute to 24 hours)
        guard minutes >= 1 else {
            throw NSError(
                domain: "ActivityEvent",
                code: 3005,
                userInfo: [NSLocalizedDescriptionKey: "Activity duration must be at least 1 minute"]
            )
        }

        guard minutes <= 1440 else { // 24 hours
            throw NSError(
                domain: "ActivityEvent",
                code: 3006,
                userInfo: [NSLocalizedDescriptionKey: "Activity duration cannot exceed 24 hours"]
            )
        }
    }

    private func validateDates() throws {
        let now = DateUtility.now()

        // Validate createdAt is not in future
        if let created = createdAt, created > now.addingTimeInterval(60) {
            throw NSError(
                domain: "ActivityEvent",
                code: 3007,
                userInfo: [NSLocalizedDescriptionKey: "Created date cannot be in the future"]
            )
        }

        // Validate backdatedAt is within reasonable range (1 year)
        if let backdated = backdatedAt {
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
            let oneYearFuture = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now

            guard backdated >= oneYearAgo && backdated <= oneYearFuture else {
                throw NSError(
                    domain: "ActivityEvent",
                    code: 3008,
                    userInfo: [NSLocalizedDescriptionKey: "Activity date must be within the past year"]
                )
            }
        }
    }
}
