//
//  SymptomEntry.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CoreData
import CoreLocation

@objc(SymptomEntry)
public class SymptomEntry: NSManagedObject {

}

extension SymptomEntry {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SymptomEntry> {
        return NSFetchRequest<SymptomEntry>(entityName: "SymptomEntry")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var backdatedAt: Date?
    @NSManaged public var severity: Int16
    @NSManaged public var note: String?
    @NSManaged public var locationPlacemark: CLPlacemark?
    @NSManaged public var weatherJSON: NSDictionary?
    @NSManaged public var hkHRV: NSNumber?
    @NSManaged public var hkRestingHR: NSNumber?
    @NSManaged public var hkSleepHours: NSNumber?
    @NSManaged public var hkWorkoutMinutes: NSNumber?
    @NSManaged public var hkCycleDay: NSNumber?
    @NSManaged public var hkFlowLevel: String?
    @NSManaged public var symptomType: SymptomType?
}

extension SymptomEntry: Identifiable {

}

// MARK: - Safe accessors
extension SymptomEntry {
    /// Safe access to ID with fallback generation
    var safeId: UUID {
        if let id = self.id {
            return id
        } else {
            let newId = UUID()
            self.id = newId
            return newId
        }
    }

    /// Safe access to creation date with validation
    var safeCreatedAt: Date {
        createdAt ?? Date()
    }

    /// Safe access to note
    var safeNote: String? {
        note
    }

    /// Effective date for display (backdated or created)
    var effectiveDate: Date {
        backdatedAt ?? safeCreatedAt
    }

    /// Normalised severity for analysis and calculations.
    /// For positive symptoms (where higher is better), inverts the 1-5 scale to 5-1.
    /// For negative symptoms (where higher is worse), returns the raw severity.
    /// This ensures all symptoms are on a consistent scale where higher = worse.
    var normalisedSeverity: Double {
        let rawSeverity = Double(severity)
        return symptomType?.isPositive == true ? (6.0 - rawSeverity) : rawSeverity
    }
}

// MARK: - Validation
extension SymptomEntry {
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateSeverity()
        try validateDates()
    }

    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateSeverity()
        try validateDates()
    }

    private func validateSeverity() throws {
        guard severity >= 1 && severity <= 5 else {
            throw NSError(
                domain: "SymptomEntry",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Severity must be between 1 and 5"]
            )
        }
    }

    private func validateDates() throws {
        let now = Date()

        // Validate createdAt is not in future
        if let created = createdAt, created > now.addingTimeInterval(60) {
            throw NSError(
                domain: "SymptomEntry",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Created date cannot be in the future"]
            )
        }

        // Validate backdatedAt is not in future
        if let backdated = backdatedAt, backdated > now.addingTimeInterval(60) {
            throw NSError(
                domain: "SymptomEntry",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Entry date cannot be in the future"]
            )
        }

        // Validate createdAt is before or equal to backdatedAt
        if let created = createdAt, let backdated = backdatedAt, created > backdated {
            throw NSError(
                domain: "SymptomEntry",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Entry cannot be backdated to before it was created"]
            )
        }
    }
}