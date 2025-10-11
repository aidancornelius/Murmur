//
//  SymptomHistoryTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import CoreData
import XCTest
@testable import Murmur

final class SymptomHistoryTests: XCTestCase {
    var testStack: InMemoryCoreDataStack?
    let calendar = Calendar.current

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
        SampleDataSeeder.seedIfNeeded(in: testStack!.context, forceSeed: true)
    }

    override func tearDown() {
        testStack = nil
        super.tearDown()
    }

    // MARK: - Symptom Count Loading Tests

    func testLoadSymptomCountsFetchesAllSymptomTypes() throws {
        // Get all symptom types that have entries
        let typeRequest = SymptomType.fetchRequest()
        let allTypes = try testStack!.context.fetch(typeRequest)

        // Create entries for 3 different symptom types
        let types = Array(allTypes.prefix(3))
        for symptomType in types {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = Date()
            entry.symptomType = symptomType
            entry.severity = 3
        }

        try testStack!.context.save()

        // Simulate SymptomHistoryView's loadSymptomCounts logic
        let symptomTypesRequest = SymptomType.fetchRequest()
        symptomTypesRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomType.name, ascending: true)]

        let symptomTypes = try testStack!.context.fetch(symptomTypesRequest)

        let counts = symptomTypes.compactMap { symptomType -> Int? in
            guard let entries = symptomType.entries as? Set<SymptomEntry>, !entries.isEmpty else { return nil }
            return entries.count
        }

        // Should have counts for 3 symptom types
        XCTAssertEqual(counts.count, 3)
    }

    func testSymptomCountsCalculateCorrectFrequency() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        // Create 5 entries for this symptom type
        for i in 0..<5 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = calendar.date(byAdding: .day, value: -i, to: Date())
            entry.symptomType = symptomType
            entry.severity = 3
        }

        try testStack!.context.save()

        // Fetch the symptom type with its entries
        testStack!.context.refresh(symptomType, mergeChanges: true)

        guard let entries = symptomType.entries as? Set<SymptomEntry> else {
            XCTFail("Could not get entries")
            return
        }

        XCTAssertEqual(entries.count, 5)
    }

    func testSymptomCountsIdentifyLastOccurrence() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let now = Date()

        // Create entries at different times
        let dates = [
            calendar.date(byAdding: .day, value: -10, to: now)!,
            calendar.date(byAdding: .day, value: -5, to: now)!,
            calendar.date(byAdding: .day, value: -1, to: now)! // Most recent
        ]

        for date in dates {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = date
            entry.symptomType = symptomType
            entry.severity = 3
        }

        try testStack!.context.save()

        // Refresh to get updated relationships
        testStack!.context.refresh(symptomType, mergeChanges: true)

        guard let entries = symptomType.entries as? Set<SymptomEntry> else {
            XCTFail("Could not get entries")
            return
        }

        // Sort entries to find last occurrence
        let sortedEntries = entries.sorted { entry1, entry2 in
            let date1 = entry1.backdatedAt ?? entry1.createdAt ?? Date()
            let date2 = entry2.backdatedAt ?? entry2.createdAt ?? Date()
            return date1 > date2
        }

        let lastOccurrence = sortedEntries.first?.createdAt

        // Last occurrence should be the most recent date
        XCTAssertNotNil(lastOccurrence)
        if let lastOccurrence = lastOccurrence {
            XCTAssertEqual(calendar.compare(lastOccurrence, to: dates[2], toGranularity: .second), .orderedSame)
        }
    }

    func testSymptomCountsCalculateAverageSeverity() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        // Create entries with known severities
        let severities: [Int16] = [1, 2, 3, 4, 5]
        for severity in severities {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = Date()
            entry.symptomType = symptomType
            entry.severity = severity
        }

        try testStack!.context.save()

        // Refresh to get updated relationships
        testStack!.context.refresh(symptomType, mergeChanges: true)

        guard let entries = symptomType.entries as? Set<SymptomEntry> else {
            XCTFail("Could not get entries")
            return
        }

        // Calculate raw average (for display)
        let rawTotalSeverity = entries.reduce(0.0) { total, entry in
            return total + Double(entry.severity)
        }
        let rawAverageSeverity = rawTotalSeverity / Double(entries.count)

        // Expected average: (1 + 2 + 3 + 4 + 5) / 5 = 3.0
        XCTAssertEqual(rawAverageSeverity, 3.0, accuracy: 0.01)
    }

    func testSymptomCountsHandleEmptySymptomTypes() throws {
        let typeRequest = SymptomType.fetchRequest()
        let allTypes = try testStack!.context.fetch(typeRequest)

        // Don't create any entries for any symptom types
        let symptomCounts = allTypes.compactMap { symptomType -> Int? in
            guard let entries = symptomType.entries as? Set<SymptomEntry>, !entries.isEmpty else { return nil }
            return entries.count
        }

        // Should have no symptom counts
        XCTAssertTrue(symptomCounts.isEmpty)
    }

    func testSymptomCountsSortedByFrequency() throws {
        let typeRequest = SymptomType.fetchRequest()
        let allTypes = try testStack!.context.fetch(typeRequest)

        // Create different numbers of entries for different types
        let types = Array(allTypes.prefix(3))

        // Type 1: 1 entry
        let entry1 = SymptomEntry(context: testStack!.context)
        entry1.id = UUID()
        entry1.createdAt = Date()
        entry1.symptomType = types[0]
        entry1.severity = 3

        // Type 2: 5 entries
        for _ in 0..<5 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = Date()
            entry.symptomType = types[1]
            entry.severity = 3
        }

        // Type 3: 3 entries
        for _ in 0..<3 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = Date()
            entry.symptomType = types[2]
            entry.severity = 3
        }

        try testStack!.context.save()

        // Fetch and sort symptom counts
        struct SymptomCount {
            let type: SymptomType
            let count: Int
        }

        let symptomTypesRequest = SymptomType.fetchRequest()
        let symptomTypes = try testStack!.context.fetch(symptomTypesRequest)

        let counts = symptomTypes.compactMap { symptomType -> SymptomCount? in
            guard let entries = symptomType.entries as? Set<SymptomEntry>, !entries.isEmpty else { return nil }
            return SymptomCount(type: symptomType, count: entries.count)
        }
        .sorted { $0.count > $1.count } // Sort by frequency descending

        // Should be sorted: 5, 3, 1
        XCTAssertEqual(counts.count, 3)
        XCTAssertEqual(counts[0].count, 5)
        XCTAssertEqual(counts[1].count, 3)
        XCTAssertEqual(counts[2].count, 1)
    }

    // MARK: - Symptom Detail Entry Loading Tests

    func testLoadEntriesForSymptomType() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        // Create 10 entries for this symptom type
        for i in 0..<10 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = calendar.date(byAdding: .day, value: -i, to: Date())
            entry.symptomType = symptomType
            entry.severity = 3
        }

        try testStack!.context.save()

        // Simulate SymptomHistoryView's loadMoreEntries
        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(format: "symptomType == %@", symptomType)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
        ]

        let results = try testStack!.context.fetch(request)

        XCTAssertEqual(results.count, 10)

        // All results should belong to the specified symptom type
        for entry in results {
            XCTAssertEqual(entry.symptomType, symptomType)
        }
    }

    func testLoadEntriesSortedByDate() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let now = Date()

        // Create entries in random order
        let dates = [
            calendar.date(byAdding: .day, value: -5, to: now)!,
            calendar.date(byAdding: .day, value: -1, to: now)!,
            calendar.date(byAdding: .day, value: -10, to: now)!,
            calendar.date(byAdding: .day, value: -3, to: now)!
        ]

        for date in dates {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = date
            entry.symptomType = symptomType
            entry.severity = 3
        }

        try testStack!.context.save()

        // Fetch with sorting
        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(format: "symptomType == %@", symptomType)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
        ]

        let results = try testStack!.context.fetch(request)

        // Results should be sorted by date descending (most recent first)
        for i in 0..<results.count - 1 {
            let date1 = results[i].backdatedAt ?? results[i].createdAt ?? Date()
            let date2 = results[i + 1].backdatedAt ?? results[i + 1].createdAt ?? Date()
            XCTAssertGreaterThanOrEqual(date1, date2)
        }
    }

    func testLoadEntriesPagination() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        // Create 50 entries
        for i in 0..<50 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = calendar.date(byAdding: .hour, value: -i, to: Date())
            entry.symptomType = symptomType
            entry.severity = 3
        }

        try testStack!.context.save()

        let pageSize = 20

        // Fetch first page
        let request1 = SymptomEntry.fetchRequest()
        request1.predicate = NSPredicate(format: "symptomType == %@", symptomType)
        request1.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
        ]
        request1.fetchLimit = pageSize
        request1.fetchOffset = 0

        let page1 = try testStack!.context.fetch(request1)
        XCTAssertEqual(page1.count, pageSize)

        // Fetch second page
        let request2 = SymptomEntry.fetchRequest()
        request2.predicate = NSPredicate(format: "symptomType == %@", symptomType)
        request2.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
        ]
        request2.fetchLimit = pageSize
        request2.fetchOffset = pageSize

        let page2 = try testStack!.context.fetch(request2)
        XCTAssertEqual(page2.count, pageSize)

        // Fetch third page
        let request3 = SymptomEntry.fetchRequest()
        request3.predicate = NSPredicate(format: "symptomType == %@", symptomType)
        request3.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
        ]
        request3.fetchLimit = pageSize
        request3.fetchOffset = pageSize * 2

        let page3 = try testStack!.context.fetch(request3)
        XCTAssertEqual(page3.count, 10) // Remaining 10 entries

        // Pages should not contain duplicate entries
        let page1IDs = Set(page1.map { $0.objectID })
        let page2IDs = Set(page2.map { $0.objectID })
        let page3IDs = Set(page3.map { $0.objectID })

        XCTAssertTrue(page1IDs.isDisjoint(with: page2IDs))
        XCTAssertTrue(page1IDs.isDisjoint(with: page3IDs))
        XCTAssertTrue(page2IDs.isDisjoint(with: page3IDs))
    }

    func testLoadEntriesHandlesNoEntries() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        // Don't create any entries

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(format: "symptomType == %@", symptomType)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
        ]

        let results = try testStack!.context.fetch(request)

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Backdated Entry Tests

    func testHistoryHandlesBackdatedEntries() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let now = Date()

        // Create entry with backdatedAt
        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = now
        entry.backdatedAt = calendar.date(byAdding: .day, value: -5, to: now)
        entry.symptomType = symptomType
        entry.severity = 3

        try testStack!.context.save()

        // Fetch and verify sorting uses backdatedAt
        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(format: "symptomType == %@", symptomType)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
        ]

        let results = try testStack!.context.fetch(request)

        XCTAssertTrue(results.contains(entry))
    }

    func testHistoryGroupsEntriesByDate() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let baseDate = calendar.startOfDay(for: Date())

        // Create multiple entries on the same day
        for i in 0..<3 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = calendar.date(byAdding: .hour, value: i, to: baseDate)
            entry.symptomType = symptomType
            entry.severity = Int16(i + 2)
        }

        // Create entry on different day
        let differentDay = calendar.date(byAdding: .day, value: -1, to: baseDate)!
        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = differentDay
        entry.symptomType = symptomType
        entry.severity = 3

        try testStack!.context.save()

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(format: "symptomType == %@", symptomType)

        let results = try testStack!.context.fetch(request)

        // Group by date
        let groupedByDate = Dictionary(grouping: results) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
        }

        // Should have 2 groups (2 different days)
        XCTAssertEqual(groupedByDate.count, 2)

        // First group should have 3 entries
        XCTAssertEqual(groupedByDate[baseDate]?.count, 3)

        // Second group should have 1 entry
        XCTAssertEqual(groupedByDate[differentDay]?.count, 1)
    }

    // MARK: - Positive vs Negative Symptom Tests

    func testHistoryDistinguishesPositiveSymptoms() throws {
        let typeRequest = SymptomType.fetchRequest()
        let allTypes = try testStack!.context.fetch(typeRequest)

        // Find or create positive symptom
        var positiveType = allTypes.first { $0.isPositive }
        if positiveType == nil {
            positiveType = SymptomType(context: testStack!.context)
            positiveType?.id = UUID()
            positiveType?.name = "Test Positive"
            positiveType?.category = "Positive wellbeing"
            positiveType?.color = "green"
            positiveType?.iconName = "star.fill"
        }

        guard let positiveType = positiveType else {
            XCTFail("Could not create positive symptom type")
            return
        }

        // Create entry
        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.symptomType = positiveType
        entry.severity = 4

        try testStack!.context.save()

        // Verify the symptom type is marked as positive
        XCTAssertTrue(positiveType.isPositive)

        // Verify the entry is associated with a positive symptom
        XCTAssertTrue(entry.symptomType?.isPositive ?? false)
    }
}
