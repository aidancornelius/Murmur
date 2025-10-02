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

extension SymptomType: Identifiable {

}

// Custom computed properties
extension SymptomType {
    var uiColor: Color {
        Color(hex: color ?? "#808080")
    }
}