//
//  DayReflection.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 04/12/2025.
//

import CoreData
import Foundation

@objc(DayReflection)
public class DayReflection: NSManagedObject {

}

extension DayReflection {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DayReflection> {
        return NSFetchRequest<DayReflection>(entityName: "DayReflection")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var bodyToMood: NSNumber?
    @NSManaged public var mindToBody: NSNumber?
    @NSManaged public var selfCareSpace: NSNumber?
    @NSManaged public var loadMultiplier: NSNumber?
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
}

extension DayReflection: Identifiable {

}

// MARK: - Convenience accessors
extension DayReflection {
    /// Returns the body-to-mood value as an Int, or nil if not set
    var bodyToMoodValue: Int? {
        get { bodyToMood?.intValue }
        set { bodyToMood = newValue.map { NSNumber(value: $0) } }
    }

    /// Returns the mind-to-body value as an Int, or nil if not set
    var mindToBodyValue: Int? {
        get { mindToBody?.intValue }
        set { mindToBody = newValue.map { NSNumber(value: $0) } }
    }

    /// Returns the self-care space value as an Int, or nil if not set
    var selfCareSpaceValue: Int? {
        get { selfCareSpace?.intValue }
        set { selfCareSpace = newValue.map { NSNumber(value: $0) } }
    }

    /// Returns the load multiplier as a Double, or nil if not set
    var loadMultiplierValue: Double? {
        get { loadMultiplier?.doubleValue }
        set { loadMultiplier = newValue.map { NSNumber(value: $0) } }
    }

    /// Calculates the felt load from a calculated load using the multiplier
    func feltLoad(from calculatedLoad: Double) -> Double {
        calculatedLoad * (loadMultiplierValue ?? 1.0)
    }

    /// Whether this reflection has any data entered
    var hasData: Bool {
        bodyToMood != nil || mindToBody != nil || selfCareSpace != nil ||
        loadMultiplier != nil || (notes != nil && !notes!.isEmpty)
    }
}

// MARK: - Fetching
extension DayReflection {
    /// Fetches the reflection for a specific day, if one exists
    static func fetch(for date: Date, in context: NSManagedObjectContext) throws -> DayReflection? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        let request = DayReflection.fetchRequest()
        request.predicate = NSPredicate(format: "date == %@", dayStart as NSDate)
        request.fetchLimit = 1

        return try context.fetch(request).first
    }

    /// Fetches or creates a reflection for a specific day
    static func fetchOrCreate(for date: Date, in context: NSManagedObjectContext) throws -> DayReflection {
        if let existing = try fetch(for: date, in: context) {
            return existing
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let now = DateUtility.now()

        let reflection = DayReflection(context: context)
        reflection.id = UUID()
        reflection.date = dayStart
        reflection.createdAt = now
        reflection.updatedAt = now

        return reflection
    }
}

// MARK: - Validation
extension DayReflection {
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateFields()
    }

    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateFields()
    }

    private func validateFields() throws {
        // Validate reflection values are in 1-5 range if set
        if let value = bodyToMood?.intValue, (value < 1 || value > 5) {
            throw NSError(
                domain: "DayReflection",
                code: 6001,
                userInfo: [NSLocalizedDescriptionKey: "Body-to-mood value must be between 1 and 5"]
            )
        }

        if let value = mindToBody?.intValue, (value < 1 || value > 5) {
            throw NSError(
                domain: "DayReflection",
                code: 6002,
                userInfo: [NSLocalizedDescriptionKey: "Mind-to-body value must be between 1 and 5"]
            )
        }

        if let value = selfCareSpace?.intValue, (value < 1 || value > 5) {
            throw NSError(
                domain: "DayReflection",
                code: 6003,
                userInfo: [NSLocalizedDescriptionKey: "Self-care space value must be between 1 and 5"]
            )
        }

        // Validate multiplier is in reasonable range (0.5 to 2.0)
        if let multiplier = loadMultiplier?.doubleValue, (multiplier < 0.5 || multiplier > 2.0) {
            throw NSError(
                domain: "DayReflection",
                code: 6004,
                userInfo: [NSLocalizedDescriptionKey: "Load multiplier must be between 0.5 and 2.0"]
            )
        }
    }
}
