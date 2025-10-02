import CoreData
import XCTest
@testable import Murmur

final class MurmurTests: XCTestCase {
    func testSampleDataSeedCreatesTypes() throws {
        let stack = InMemoryCoreDataStack()
        SampleDataSeeder.seedIfNeeded(in: stack.context)
        let request = SymptomType.fetchRequest()
        let types = try stack.context.fetch(request)
        XCTAssertFalse(types.isEmpty)
    }
}

private final class InMemoryCoreDataStack {
    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }

    init() {
        container = NSPersistentContainer(name: "Murmur")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
    }
}
