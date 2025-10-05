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
