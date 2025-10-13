//
//  MurmurWidgetTestsBase.swift
//  MurmurWidgetTests
//
//  Created by Claude Code on 13/10/2025.
//

import CoreData
import XCTest
import WidgetKit
@testable import Murmur
@testable import MurmurWidgets

// MARK: - Base Test Case

class MurmurWidgetTestsBase: XCTestCase {
    var testStack: InMemoryCoreDataStack?

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
    }

    override func tearDown() {
        testStack = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    func createSymptomEntry(
        severity: Int16,
        createdAt: Date = Date(),
        note: String? = nil,
        symptomType: SymptomType? = nil
    ) throws -> SymptomEntry {
        guard let context = testStack?.context else {
            throw TestError.noContext
        }

        let entry = SymptomEntry(context: context)
        entry.id = UUID()
        entry.createdAt = createdAt
        entry.severity = severity
        entry.note = note

        if let symptomType = symptomType {
            entry.symptomType = symptomType
        } else {
            // Create a default symptom type if none provided
            let type = SymptomType(context: context)
            type.id = UUID()
            type.name = "Test Symptom"
            type.category = "Test"
            entry.symptomType = type
        }

        try context.save()
        return entry
    }

    func createActivityEvent(
        name: String,
        createdAt: Date = Date(),
        physicalExertion: Int16 = 3,
        cognitiveExertion: Int16 = 2,
        emotionalLoad: Int16 = 2,
        durationMinutes: Int? = nil
    ) throws -> ActivityEvent {
        guard let context = testStack?.context else {
            throw TestError.noContext
        }

        let event = ActivityEvent(context: context)
        event.id = UUID()
        event.name = name
        event.createdAt = createdAt
        event.physicalExertion = physicalExertion
        event.cognitiveExertion = cognitiveExertion
        event.emotionalLoad = emotionalLoad
        if let duration = durationMinutes {
            event.durationMinutes = NSNumber(value: duration)
        }

        try context.save()
        return event
    }

    func createMealEvent(
        mealType: String,
        mealDescription: String,
        createdAt: Date = Date(),
        physicalExertion: Int16 = 2,
        cognitiveExertion: Int16 = 1,
        emotionalLoad: Int16 = 1
    ) throws -> MealEvent {
        guard let context = testStack?.context else {
            throw TestError.noContext
        }

        let event = MealEvent(context: context)
        event.id = UUID()
        event.mealType = mealType
        event.mealDescription = mealDescription
        event.createdAt = createdAt
        event.physicalExertion = NSNumber(value: physicalExertion)
        event.cognitiveExertion = NSNumber(value: cognitiveExertion)
        event.emotionalLoad = NSNumber(value: emotionalLoad)

        try context.save()
        return event
    }

    func fetchFirstObject<T: NSManagedObject>(_ request: NSFetchRequest<T>) -> T? {
        guard let context = testStack?.context else {
            return nil
        }
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    // MARK: - Widget Timeline Helpers

    func createTimelineEntry(
        date: Date = Date(),
        policy: TimelineReloadPolicy = .never
    ) -> (entry: TimelineEntry, policy: TimelineReloadPolicy) {
        // Generic timeline entry structure
        // Specific widget tests will override this
        return (entry: MockTimelineEntry(date: date), policy: policy)
    }

    func verifyTimelineRefreshPolicy(
        _ policy: TimelineReloadPolicy,
        expectedType: TimelineReloadPolicyType
    ) {
        // Note: This is a simplified verification that doesn't check .after dates
        switch (policy, expectedType) {
        case (.never, .never):
            XCTAssertTrue(true, "Policy matches: never")
        case (.atEnd, .atEnd):
            XCTAssertTrue(true, "Policy matches: atEnd")
        default:
            // For .after cases, we'd need to extract and compare dates
            // For now, just note the types in the failure message
            XCTFail("Timeline reload policy mismatch or .after case: got \(policy), expected \(expectedType)")
        }
    }

    // MARK: - Mock Data Helpers

    func seedSampleData() throws {
        guard let context = testStack?.context else {
            throw TestError.noContext
        }
        SampleDataSeeder.seedIfNeeded(in: context, forceSeed: true)
    }

    func createTestSymptomType(
        name: String,
        category: String = "Test"
    ) throws -> SymptomType {
        guard let context = testStack?.context else {
            throw TestError.noContext
        }

        let type = SymptomType(context: context)
        type.id = UUID()
        type.name = name
        type.category = category

        try context.save()
        return type
    }

    // MARK: - Assertions

    func assertValidTimeline<Entry>(
        _ timeline: Timeline<Entry>,
        minimumEntries: Int = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) where Entry: TimelineEntry {
        XCTAssertGreaterThanOrEqual(
            timeline.entries.count,
            minimumEntries,
            "Timeline should have at least \(minimumEntries) entry/entries",
            file: file,
            line: line
        )

        // Verify entries are in chronological order
        if timeline.entries.count > 1 {
            for i in 0..<timeline.entries.count - 1 {
                XCTAssertLessThanOrEqual(
                    timeline.entries[i].date,
                    timeline.entries[i + 1].date,
                    "Timeline entries should be in chronological order",
                    file: file,
                    line: line
                )
            }
        }
    }
}

// MARK: - In-Memory Core Data Stack

final class InMemoryCoreDataStack {
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

// MARK: - Mock Types

struct MockTimelineEntry: TimelineEntry {
    let date: Date
}

enum TimelineReloadPolicyType {
    case never
    case atEnd
    case after(Date)
}

// MARK: - Test Errors

enum TestError: Error {
    case noContext
    case invalidConfiguration
    case missingData
}
