import CoreData
import XCTest
@testable import Murmur

final class MurmurTests: XCTestCase {
    func testSampleDataSeedCreatesTypes() throws {
        let stack = InMemoryCoreDataStack()
        SampleDataSeeder.seedIfNeeded(in: stack.context, forceSeed: true)

        let request = SymptomType.fetchRequest()
        let types = try stack.context.fetch(request)
        XCTAssertFalse(types.isEmpty, "Should create default symptom types")
        XCTAssertGreaterThan(types.count, 50, "Should have many default symptoms")
    }

    func testPositiveSymptomsExist() throws {
        let stack = InMemoryCoreDataStack()
        SampleDataSeeder.seedIfNeeded(in: stack.context, forceSeed: true)

        let request = SymptomType.fetchRequest()
        let types = try stack.context.fetch(request)

        // Verify positive symptoms were added
        let positiveSymptoms = types.filter { $0.isPositive }
        XCTAssertFalse(positiveSymptoms.isEmpty, "Should have positive symptoms")
        XCTAssertGreaterThanOrEqual(positiveSymptoms.count, 10, "Should have at least 10 positive symptoms")

        // Check for specific positive symptoms
        let symptomNames = types.compactMap { $0.name }
        XCTAssertTrue(symptomNames.contains("Energy"), "Should include Energy symptom")
        XCTAssertTrue(symptomNames.contains("Joy"), "Should include Joy symptom")
        XCTAssertTrue(symptomNames.contains("Good concentration"), "Should include Good concentration symptom")
    }

    func testPositiveSymptomDetection() throws {
        let stack = InMemoryCoreDataStack()
        SampleDataSeeder.seedIfNeeded(in: stack.context, forceSeed: true)

        let request = SymptomType.fetchRequest()
        let types = try stack.context.fetch(request)

        // Find Energy symptom
        let energy = types.first { $0.name == "Energy" }
        XCTAssertNotNil(energy, "Energy symptom should exist")
        XCTAssertTrue(energy?.isPositive ?? false, "Energy should be detected as positive")
        XCTAssertEqual(energy?.category, "Positive wellbeing", "Energy should have correct category")

        // Find Fatigue symptom (negative)
        let fatigue = types.first { $0.name == "Fatigue" }
        XCTAssertNotNil(fatigue, "Fatigue symptom should exist")
        XCTAssertFalse(fatigue?.isPositive ?? true, "Fatigue should be detected as negative")
        XCTAssertNotEqual(fatigue?.category, "Positive wellbeing", "Fatigue should not be positive category")
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
