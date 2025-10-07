//
//  MealEvent.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 05/10/2025.
//

import CoreData
import Foundation

@objc(MealEvent)
public class MealEvent: NSManagedObject {

}

extension MealEvent {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MealEvent> {
        return NSFetchRequest<MealEvent>(entityName: "MealEvent")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var backdatedAt: Date?
    @NSManaged public var mealType: String?
    @NSManaged public var mealDescription: String?
    @NSManaged public var note: String?
}

extension MealEvent: Identifiable {

}

// MARK: - Validation
extension MealEvent {
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateRequiredFields()
        try validateDates()
    }

    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateRequiredFields()
        try validateDates()
    }

    private func validateRequiredFields() throws {
        guard let mealType = mealType, !mealType.isEmpty else {
            throw NSError(
                domain: "MealEvent",
                code: 4001,
                userInfo: [NSLocalizedDescriptionKey: "Meal type is required"]
            )
        }

        guard let mealDescription = mealDescription, !mealDescription.isEmpty else {
            throw NSError(
                domain: "MealEvent",
                code: 4002,
                userInfo: [NSLocalizedDescriptionKey: "Meal description is required"]
            )
        }
    }

    private func validateDates() throws {
        let now = Date()

        // Validate createdAt is not in future
        if let created = createdAt, created > now.addingTimeInterval(60) {
            throw NSError(
                domain: "MealEvent",
                code: 4003,
                userInfo: [NSLocalizedDescriptionKey: "Created date cannot be in the future"]
            )
        }

        // Validate backdatedAt is within reasonable range (1 year)
        if let backdated = backdatedAt {
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
            let oneYearFuture = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now

            guard backdated >= oneYearAgo && backdated <= oneYearFuture else {
                throw NSError(
                    domain: "MealEvent",
                    code: 4004,
                    userInfo: [NSLocalizedDescriptionKey: "Meal date must be within the past year"]
                )
            }
        }
    }
}
