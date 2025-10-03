//
//  Reminder.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CoreData

@objc(Reminder)
public class Reminder: NSManagedObject {

}

extension Reminder {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Reminder> {
        return NSFetchRequest<Reminder>(entityName: "Reminder")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var hour: Int16
    @NSManaged public var minute: Int16
    @NSManaged public var repeatsOn: NSArray?
    @NSManaged public var isEnabled: Bool
}

extension Reminder: Identifiable {

}