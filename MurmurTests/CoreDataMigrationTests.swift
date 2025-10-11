//
//  CoreDataMigrationTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 05/10/2025.
//

import CoreData
import XCTest
@testable import Murmur

final class CoreDataMigrationTests: XCTestCase {
    var testStack: InMemoryCoreDataStack?

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
    }

    override func tearDown() {
        testStack = nil
        super.tearDown()
    }

    // MARK: - Model Loading Tests

    func testCoreDataModelLoads() throws {
        let model = testStack.container.managedObjectModel
        XCTAssertNotNil(model)

        // Verify all expected entities exist
        let entityNames = model.entities.map { $0.name ?? "" }
        XCTAssertTrue(entityNames.contains("SymptomType"))
        XCTAssertTrue(entityNames.contains("SymptomEntry"))
        XCTAssertTrue(entityNames.contains("ActivityEvent"))
        XCTAssertTrue(entityNames.contains("SleepEvent"))
        XCTAssertTrue(entityNames.contains("MealEvent"))
        XCTAssertTrue(entityNames.contains("Reminder"))
        XCTAssertTrue(entityNames.contains("ManualCycleEntry"))
    }

    func testNewEntitiesHaveCorrectAttributes() throws {
        let model = testStack.container.managedObjectModel

        // Test SleepEvent entity
        let sleepEntity = model.entitiesByName["SleepEvent"]
        XCTAssertNotNil(sleepEntity)

        let sleepAttributes = sleepEntity?.attributesByName.keys.sorted()
        XCTAssertTrue(sleepAttributes?.contains("id") ?? false)
        XCTAssertTrue(sleepAttributes?.contains("createdAt") ?? false)
        XCTAssertTrue(sleepAttributes?.contains("backdatedAt") ?? false)
        XCTAssertTrue(sleepAttributes?.contains("bedTime") ?? false)
        XCTAssertTrue(sleepAttributes?.contains("wakeTime") ?? false)
        XCTAssertTrue(sleepAttributes?.contains("quality") ?? false)
        XCTAssertTrue(sleepAttributes?.contains("note") ?? false)
        XCTAssertTrue(sleepAttributes?.contains("hkSleepHours") ?? false)
        XCTAssertTrue(sleepAttributes?.contains("hkHRV") ?? false)
        XCTAssertTrue(sleepAttributes?.contains("hkRestingHR") ?? false)

        // Test MealEvent entity
        let mealEntity = model.entitiesByName["MealEvent"]
        XCTAssertNotNil(mealEntity)

        let mealAttributes = mealEntity?.attributesByName.keys.sorted()
        XCTAssertTrue(mealAttributes?.contains("id") ?? false)
        XCTAssertTrue(mealAttributes?.contains("createdAt") ?? false)
        XCTAssertTrue(mealAttributes?.contains("backdatedAt") ?? false)
        XCTAssertTrue(mealAttributes?.contains("mealType") ?? false)
        XCTAssertTrue(mealAttributes?.contains("mealDescription") ?? false)
        XCTAssertTrue(mealAttributes?.contains("note") ?? false)
    }

    func testSleepEventSymptomRelationship() throws {
        let model = testStack.container.managedObjectModel

        let sleepEntity = model.entitiesByName["SleepEvent"]
        XCTAssertNotNil(sleepEntity)

        let symptomsRelationship = sleepEntity?.relationshipsByName["symptoms"]
        XCTAssertNotNil(symptomsRelationship)
        XCTAssertEqual(symptomsRelationship?.destinationEntity?.name, "SymptomType")
        XCTAssertTrue(symptomsRelationship?.isToMany ?? false)
        XCTAssertEqual(symptomsRelationship?.deleteRule, .nullifyDeleteRule)

        // Check inverse relationship
        let symptomTypeEntity = model.entitiesByName["SymptomType"]
        let sleepEventsRelationship = symptomTypeEntity?.relationshipsByName["sleepEvents"]
        XCTAssertNotNil(sleepEventsRelationship)
        XCTAssertEqual(sleepEventsRelationship?.destinationEntity?.name, "SleepEvent")
        XCTAssertEqual(sleepEventsRelationship?.inverseRelationship?.name, "symptoms")
    }

    // MARK: - Migration Compatibility Tests

    func testExistingDataTypesStillWork() throws {
        // Seed sample data including existing types
        SampleDataSeeder.seedIfNeeded(in: testStack!.context, forceSeed: true)

        // Test SymptomType still works
        let symptomType = SymptomType(context: testStack!.context)
        symptomType.id = UUID()
        symptomType.name = "Test Symptom"
        symptomType.color = "#FF0000"
        symptomType.iconName = "star"

        // Test SymptomEntry still works
        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.severity = 3
        entry.symptomType = symptomType

        // Test ActivityEvent still works
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test Activity"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        try testStack!.context.save()

        // Verify all saved correctly
        let symptomTypes = try testStack!.context.fetch(SymptomType.fetchRequest())
        let entries = try testStack!.context.fetch(SymptomEntry.fetchRequest())
        let activities = try testStack!.context.fetch(ActivityEvent.fetchRequest())

        XCTAssertGreaterThan(symptomTypes.count, 0)
        XCTAssertGreaterThan(entries.count, 0)
        XCTAssertGreaterThan(activities.count, 0)
    }

    func testNewAndOldEntitiesCoexist() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack!.context, forceSeed: true)

        // Create old entity type
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.severity = 3
        entry.symptomType = symptomType

        // Create new entity types
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 4

        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Test meal"

        try testStack!.context.save()

        // Verify all exist together
        let entries = try testStack!.context.fetch(SymptomEntry.fetchRequest())
        let sleeps = try testStack!.context.fetch(SleepEvent.fetchRequest())
        let meals = try testStack!.context.fetch(MealEvent.fetchRequest())

        XCTAssertGreaterThan(entries.count, 0)
        XCTAssertEqual(sleeps.count, 1)
        XCTAssertEqual(meals.count, 1)
    }

    func testSymptomTypeRelationshipsExpanded() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack!.context, forceSeed: true)

        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        // Create SymptomEntry (old relationship)
        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.severity = 3
        entry.symptomType = symptomType

        // Create SleepEvent with symptom (new relationship)
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 3
        sleep.addToSymptoms(symptomType)

        try testStack!.context.save()

        // Verify SymptomType has both relationships
        XCTAssertEqual(symptomType.entries?.count, 1)
        XCTAssertEqual(symptomType.sleepEvents?.count, 1)

        // Verify relationships are distinct
        let entriesArray = symptomType.entries?.allObjects as? [SymptomEntry]
        let sleepEventsArray = symptomType.sleepEvents?.allObjects as? [SleepEvent]

        XCTAssertNotNil(entriesArray)
        XCTAssertNotNil(sleepEventsArray)
        XCTAssertEqual(entriesArray?.first?.id, entry.id)
        XCTAssertEqual(sleepEventsArray?.first?.id, sleep.id)
    }

    // MARK: - Data Integrity Tests

    func testRequiredAttributesEnforcement() throws {
        // Test SleepEvent required attributes
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date()
        sleep.wakeTime = Date()
        sleep.quality = 3
        // Note is optional

        XCTAssertNoThrow(try testStack!.context.save())

        // Test MealEvent required attributes
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "lunch"
        meal.mealDescription = "Salad"
        // Note is optional

        XCTAssertNoThrow(try testStack!.context.save())
    }

    func testOptionalAttributesAllowNil() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date()
        sleep.wakeTime = Date()
        sleep.quality = 3
        // All HealthKit fields are optional (nil)

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNil(fetched.note)
        XCTAssertNil(fetched.hkSleepHours)
        XCTAssertNil(fetched.hkHRV)
        XCTAssertNil(fetched.hkRestingHR)
        XCTAssertNil(fetched.backdatedAt)
    }

    func testDeleteRulesPreserveData() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack!.context, forceSeed: true)

        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date()
        sleep.wakeTime = Date()
        sleep.quality = 3
        sleep.addToSymptoms(symptomType)

        try testStack!.context.save()

        // Delete sleep event
        testStack!.context.delete(sleep)
        try testStack!.context.save()

        // SymptomType should still exist (nullify rule)
        let stillExists = try testStack!.context.fetch(SymptomType.fetchRequest())
        XCTAssertFalse(stillExists.isEmpty)

        // Verify symptom no longer references deleted sleep event
        let refreshedSymptom = stillExists.first { $0.id == symptomType.id }
        XCTAssertEqual(refreshedSymptom?.sleepEvents?.count, 0)
    }

    // MARK: - Attribute Type Tests

    func testHealthKitAttributeTypes() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date()
        sleep.wakeTime = Date()
        sleep.quality = 3
        sleep.hkSleepHours = NSNumber(value: 7.5)
        sleep.hkHRV = NSNumber(value: 45.2)
        sleep.hkRestingHR = NSNumber(value: 62.0)

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))

        // Verify NSNumber can be converted to Double
        XCTAssertEqual(fetched.hkSleepHours?.doubleValue ?? 0, 7.5, accuracy: 0.01)
        XCTAssertEqual(fetched.hkHRV?.doubleValue ?? 0, 45.2, accuracy: 0.01)
        XCTAssertEqual(fetched.hkRestingHR?.doubleValue ?? 0, 62.0, accuracy: 0.01)
    }

    func testQualityAttributeRange() throws {
        // Quality should be Int16 with valid range 1-5
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date()
        sleep.wakeTime = Date()
        sleep.quality = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))

        // Verify it's stored as Int16
        XCTAssertTrue(type(of: fetched.quality) == Int16.self)
        XCTAssertGreaterThanOrEqual(fetched.quality, 1)
        XCTAssertLessThanOrEqual(fetched.quality, 5)
    }

    func testDateAttributePersistence() throws {
        let bedTime = Date().addingTimeInterval(-8 * 3600)
        let wakeTime = Date()
        let createdAt = Date()
        let backdatedAt = bedTime

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = createdAt
        sleep.backdatedAt = backdatedAt
        sleep.bedTime = bedTime
        sleep.wakeTime = wakeTime
        sleep.quality = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))

        // Verify dates are preserved
        XCTAssertEqual(fetched.bedTime?.timeIntervalSince1970 ?? 0, bedTime.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(fetched.wakeTime?.timeIntervalSince1970 ?? 0, wakeTime.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(fetched.createdAt?.timeIntervalSince1970 ?? 0, createdAt.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(fetched.backdatedAt?.timeIntervalSince1970 ?? 0, backdatedAt.timeIntervalSince1970, accuracy: 1)
    }

    // MARK: - Performance Tests

    func testBulkEventCreationPerformance() throws {
        self.measure {
            let context = testStack.container.newBackgroundContext()

            for i in 0..<100 {
                let sleep = SleepEvent(context: context)
                sleep.id = UUID()
                sleep.createdAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
                sleep.bedTime = Date().addingTimeInterval(TimeInterval(-i * 3600 - 28800))
                sleep.wakeTime = Date().addingTimeInterval(TimeInterval(-i * 3600))
                sleep.quality = Int16((i % 5) + 1)
            }

            try? context.save()
        }
    }

    func testComplexRelationshipPerformance() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack!.context, forceSeed: true)

        let symptoms = try testStack!.context.fetch(SymptomType.fetchRequest()).prefix(5)

        self.measure {
            let context = testStack.container.newBackgroundContext()

            for i in 0..<50 {
                let sleep = SleepEvent(context: context)
                sleep.id = UUID()
                sleep.createdAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
                sleep.bedTime = Date()
                sleep.wakeTime = Date()
                sleep.quality = 3

                // Add relationships
                for symptom in symptoms {
                    if let symptomInContext = try? context.existingObject(with: symptom.objectID) as? SymptomType {
                        sleep.addToSymptoms(symptomInContext)
                    }
                }
            }

            try? context.save()
        }
    }
}
