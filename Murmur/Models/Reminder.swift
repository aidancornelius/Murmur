// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Reminder.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Core Data entity for user-configured reminders.
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