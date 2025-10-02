import CoreData
import Foundation

@objc(ManualCycleEntry)
final class ManualCycleEntry: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var date: Date
    @NSManaged var flowLevel: String
}

extension ManualCycleEntry {
    static func create(
        date: Date,
        flowLevel: String,
        in context: NSManagedObjectContext
    ) -> ManualCycleEntry {
        let entry = ManualCycleEntry(context: context)
        entry.id = UUID()
        entry.date = date
        entry.flowLevel = flowLevel
        return entry
    }

    static func fetchRequest() -> NSFetchRequest<ManualCycleEntry> {
        NSFetchRequest<ManualCycleEntry>(entityName: "ManualCycleEntry")
    }

    /// Fetch all manual cycle entries within a date range
    static func fetch(
        from startDate: Date,
        to endDate: Date,
        in context: NSManagedObjectContext
    ) throws -> [ManualCycleEntry] {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ManualCycleEntry.date, ascending: false)]
        return try context.fetch(request)
    }

    /// Fetch all manual cycle entries sorted by date
    static func fetchAll(in context: NSManagedObjectContext) throws -> [ManualCycleEntry] {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ManualCycleEntry.date, ascending: false)]
        return try context.fetch(request)
    }
}
