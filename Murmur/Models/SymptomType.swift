// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// SymptomType.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Core Data entity for user-defined symptom types.
//
import CoreData
import SwiftUI

@objc(SymptomType)
public class SymptomType: NSManagedObject {

}

extension SymptomType {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SymptomType> {
        return NSFetchRequest<SymptomType>(entityName: "SymptomType")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var color: String?
    @NSManaged public var iconName: String?
    @NSManaged public var category: String?
    @NSManaged public var isDefault: Bool
    @NSManaged public var isStarred: Bool
    @NSManaged public var starOrder: Int16
    @NSManaged public var entries: NSSet?
    @NSManaged public var sleepEvents: NSSet?
}

// MARK: Generated accessors for entries
extension SymptomType {
    @objc(addEntriesObject:)
    @NSManaged public func addToEntries(_ value: SymptomEntry)

    @objc(removeEntriesObject:)
    @NSManaged public func removeFromEntries(_ value: SymptomEntry)

    @objc(addEntries:)
    @NSManaged public func addToEntries(_ values: NSSet)

    @objc(removeEntries:)
    @NSManaged public func removeFromEntries(_ values: NSSet)
}

// MARK: Generated accessors for sleepEvents
extension SymptomType {
    @objc(addSleepEventsObject:)
    @NSManaged public func addToSleepEvents(_ value: SleepEvent)

    @objc(removeSleepEventsObject:)
    @NSManaged public func removeFromSleepEvents(_ value: SleepEvent)

    @objc(addSleepEvents:)
    @NSManaged public func addToSleepEvents(_ values: NSSet)

    @objc(removeSleepEvents:)
    @NSManaged public func removeFromSleepEvents(_ values: NSSet)
}

extension SymptomType: Identifiable {

}

// Custom computed properties
extension SymptomType {
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

    /// Safe access to name with validation
    var safeName: String {
        guard let name = self.name, !name.isEmpty else {
            return "Unnamed symptom"
        }
        return name
    }

    /// Safe access to color with default
    var safeColor: String {
        color ?? "#808080"
    }

    /// Safe access to icon name with default
    var safeIconName: String {
        iconName ?? "circle"
    }

    /// Safe access to category
    var safeCategory: String? {
        category
    }

    var uiColor: Color {
        Color(hex: safeColor)
    }

    /// Returns true if this symptom represents a positive state (higher is better)
    var isPositive: Bool {
        category == "Positive wellbeing"
    }
}