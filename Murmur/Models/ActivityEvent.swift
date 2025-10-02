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
