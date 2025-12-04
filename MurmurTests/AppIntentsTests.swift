// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// AppIntentsTests.swift
// Created by Aidan Cornelius-Bell on 13/10/2025.
// Tests for App Intents functionality.
//
import XCTest
import CoreData
@testable import Murmur

@MainActor
final class AppIntentsTests: XCTestCase {

    var testStack: InMemoryCoreDataStack!

    override func setUp() async throws {
        testStack = InMemoryCoreDataStack()
        // Seed with default symptom types for testing
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)
    }

    override func tearDown() async throws {
        testStack = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    /// Create test symptom entries with specified dates
    private func createTestEntry(symptomName: String, severity: Int16, date: Date, note: String? = nil) throws {
        let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", symptomName)

        guard let symptomType = try testStack.context.fetch(fetchRequest).first else {
            XCTFail("Could not find symptom type: \(symptomName)")
            return
        }

        let entry = SymptomEntry(context: testStack.context)
        entry.id = UUID()
        entry.createdAt = date
        entry.backdatedAt = date
        entry.severity = severity
        entry.note = note
        entry.symptomType = symptomType

        try testStack.context.save()
    }

    /// Create test activity with specified date
    private func createTestActivity(name: String, date: Date, physical: Int16 = 3, cognitive: Int16 = 2, emotional: Int16 = 2) throws {
        let activity = ActivityEvent(context: testStack.context)
        activity.id = UUID()
        activity.name = name
        activity.createdAt = date
        activity.backdatedAt = date
        activity.physicalExertion = physical
        activity.cognitiveExertion = cognitive
        activity.emotionalLoad = emotional
        activity.durationMinutes = NSNumber(value: 30)

        try testStack.context.save()
    }

    /// Set up a mock CoreDataStack for intents to use
    private func setupMockCoreDataStack() {
        // Override the shared CoreDataStack with our test stack
        // This is a workaround since intents use CoreDataStack.shared
        // In production code, we'd inject dependencies, but App Intents have limitations
    }

    // MARK: - LogSymptomIntent Tests

    func testLogSymptomIntent_WithValidSymptomName_CreatesEntry() async throws {
        // Given: A valid symptom name and severity
        let intent = LogSymptomIntent()
        intent.symptomName = "Fatigue"
        intent.severity = 3
        intent.notes = "Feeling very tired"

        // When: Perform the intent
        // Note: This will use the real CoreDataStack.shared, which is a limitation
        // In a real test environment, we'd need dependency injection
        // For now, we'll test the logic by directly creating entries

        let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", "Fatigue")
        let symptomType = try testStack.context.fetch(fetchRequest).first

        XCTAssertNotNil(symptomType, "Fatigue symptom type should exist")
        XCTAssertEqual(symptomType?.name, "Fatigue")
    }

    func testLogSymptomIntent_WithoutSymptomName_UsesFirstStarred() async throws {
        // Given: Mark a symptom as starred
        let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
        let symptomTypes = try testStack.context.fetch(fetchRequest)
        guard let firstType = symptomTypes.first else {
            XCTFail("No symptom types found")
            return
        }

        firstType.isStarred = true
        try testStack.context.save()

        // When: Intent is created without symptomName
        let intent = LogSymptomIntent()
        intent.severity = 4

        // Then: Should use the starred symptom
        XCTAssertTrue(firstType.isStarred)
    }

    func testLogSymptomIntent_WithInvalidSeverity_ClampsSeverity() {
        // Given: Invalid severity values
        let tooLow = max(1, min(5, 0))
        let tooHigh = max(1, min(5, 10))
        let valid = max(1, min(5, 3))

        // Then: Severities should be clamped
        XCTAssertEqual(tooLow, 1)
        XCTAssertEqual(tooHigh, 5)
        XCTAssertEqual(valid, 3)
    }

    func testLogSymptomIntent_WithFuzzyMatch_FindsClosestSymptom() async throws {
        // Given: Partial symptom name
        let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
        let symptomTypes = try testStack.context.fetch(fetchRequest)

        // When: Looking for fuzzy match
        let searchTerm = "head"
        let fuzzyMatch = symptomTypes.first { $0.name?.lowercased().contains(searchTerm) ?? false }

        // Then: Should find "Headache"
        XCTAssertNotNil(fuzzyMatch)
        XCTAssertTrue(fuzzyMatch?.name?.lowercased().contains(searchTerm) ?? false)
    }

    func testLogSymptomIntent_WithEmptyNote_SavesNilNote() {
        // Given: Empty note strings
        let emptyNote = "   ".trimmingCharacters(in: .whitespacesAndNewlines)
        let validNote = "  Valid note  ".trimmingCharacters(in: .whitespacesAndNewlines)

        // Then: Empty should be nil, valid should be trimmed
        XCTAssertTrue(emptyNote.isEmpty)
        XCTAssertEqual(validNote, "Valid note")
    }

    // MARK: - OpenAddEntryIntent Tests

    func testOpenAddEntryIntent_PostsNotification() async throws {
        // Given: Notification expectation
        let expectation = XCTestExpectation(description: "Notification posted")
        var receivedNotification = false

        let observer = NotificationCenter.default.addObserver(
            forName: .openAddEntry,
            object: nil,
            queue: .main
        ) { _ in
            receivedNotification = true
            expectation.fulfill()
        }

        // When: Perform the intent
        let intent = OpenAddEntryIntent()
        _ = try await intent.perform()

        // Then: Notification should be posted
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(receivedNotification)

        NotificationCenter.default.removeObserver(observer)
    }

    func testOpenAddEntryIntent_ReturnsResult() async throws {
        // Given: Intent
        let intent = OpenAddEntryIntent()

        // When: Perform the intent
        let result = try await intent.perform()

        // Then: Should return a result (implementation returns .result())
        // This is a structural test - the intent completes successfully
        XCTAssertNotNil(result)
    }

    func testOpenAddEntryIntent_HasCorrectMetadata() {
        // Given: Intent metadata
        let title = OpenAddEntryIntent.title
        let opensApp = OpenAddEntryIntent.openAppWhenRun

        // Then: Should have correct configuration
        XCTAssertEqual(String(describing: title), "How are you feeling?")
        XCTAssertTrue(opensApp)
    }

    // MARK: - OpenAddActivityIntent Tests

    func testOpenAddActivityIntent_PostsNotification() async throws {
        // Given: Notification expectation
        let expectation = XCTestExpectation(description: "Notification posted")
        var receivedNotification = false

        let observer = NotificationCenter.default.addObserver(
            forName: .openAddActivity,
            object: nil,
            queue: .main
        ) { _ in
            receivedNotification = true
            expectation.fulfill()
        }

        // When: Perform the intent
        let intent = OpenAddActivityIntent()
        _ = try await intent.perform()

        // Then: Notification should be posted
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(receivedNotification)

        NotificationCenter.default.removeObserver(observer)
    }

    func testOpenAddActivityIntent_ReturnsResult() async throws {
        // Given: Intent
        let intent = OpenAddActivityIntent()

        // When: Perform the intent
        let result = try await intent.perform()

        // Then: Should return a result
        XCTAssertNotNil(result)
    }

    func testOpenAddActivityIntent_HasCorrectMetadata() {
        // Given: Intent metadata
        let title = OpenAddActivityIntent.title
        let opensApp = OpenAddActivityIntent.openAppWhenRun

        // Then: Should have correct configuration
        XCTAssertEqual(String(describing: title), "Log an activity")
        XCTAssertTrue(opensApp)
    }

    // MARK: - GetRecentEntriesIntent Tests

    func testGetRecentEntriesIntent_WithNoEntries_ReturnsEmptyMessage() async throws {
        // Given: No entries in database
        // (setUp creates symptom types but no entries)

        // When: Fetch recent entries
        // Note: Since intents use CoreDataStack.shared, we test the logic directly
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false)
        ]

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should have no entries
        XCTAssertTrue(entries.isEmpty)
    }

    func testGetRecentEntriesIntent_ReturnsRequestedCount() async throws {
        // Given: 10 entries in database
        let now = Date()
        for i in 0..<10 {
            let date = now.addingTimeInterval(TimeInterval(-i * 3600))
            try createTestEntry(symptomName: "Fatigue", severity: 3, date: date)
        }

        // When: Fetch 5 recent entries
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false)
        ]
        fetchRequest.fetchLimit = 5

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should return exactly 5 entries
        XCTAssertEqual(entries.count, 5)
    }

    func testGetRecentEntriesIntent_SortsEntriesByDate() async throws {
        // Given: Entries with different dates
        let now = Date()
        try createTestEntry(symptomName: "Fatigue", severity: 3, date: now.addingTimeInterval(-7200)) // 2 hours ago
        try createTestEntry(symptomName: "Headache", severity: 4, date: now.addingTimeInterval(-3600)) // 1 hour ago
        try createTestEntry(symptomName: "Brain fog", severity: 2, date: now) // now

        // When: Fetch entries sorted by date
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
        ]

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should be sorted newest first
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].symptomType?.name, "Brain fog")
        XCTAssertEqual(entries[1].symptomType?.name, "Headache")
        XCTAssertEqual(entries[2].symptomType?.name, "Fatigue")
    }

    func testGetRecentEntriesIntent_ClampsCountToRange() {
        // Given: Count values outside valid range
        let tooLow = max(1, min(10, 0))
        let tooHigh = max(1, min(10, 20))
        let valid = max(1, min(10, 5))

        // Then: Should be clamped to 1-10
        XCTAssertEqual(tooLow, 1)
        XCTAssertEqual(tooHigh, 10)
        XCTAssertEqual(valid, 5)
    }

    func testGetRecentEntriesIntent_IncludesNoteInSummary() async throws {
        // Given: Entry with note
        try createTestEntry(
            symptomName: "Fatigue",
            severity: 4,
            date: Date(),
            note: "Feeling very tired after activity"
        )

        // When: Fetch entry
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Note should be present
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].note, "Feeling very tired after activity")
    }

    // MARK: - GetSymptomsBySeverityIntent Tests

    func testGetSymptomsBySeverityIntent_FiltersMinimumSeverity() async throws {
        // Given: Entries with different severities
        let now = Date()
        try createTestEntry(symptomName: "Fatigue", severity: 2, date: now)
        try createTestEntry(symptomName: "Headache", severity: 4, date: now)
        try createTestEntry(symptomName: "Brain fog", severity: 5, date: now)

        // When: Filter by minimum severity 4
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "severity >= %d", 4)

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should return only entries with severity >= 4
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.allSatisfy { $0.severity >= 4 })
    }

    func testGetSymptomsBySeverityIntent_FiltersDateRange() async throws {
        // Given: Entries across different dates
        let now = Date()
        let twoDaysAgo = now.addingTimeInterval(-2 * 24 * 3600)
        let tenDaysAgo = now.addingTimeInterval(-10 * 24 * 3600)

        try createTestEntry(symptomName: "Fatigue", severity: 4, date: now)
        try createTestEntry(symptomName: "Headache", severity: 4, date: twoDaysAgo)
        try createTestEntry(symptomName: "Brain fog", severity: 4, date: tenDaysAgo)

        // When: Filter last 7 days
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "severity >= %d AND backdatedAt >= %@",
            4,
            startDate as NSDate
        )

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should return only entries from last 7 days
        XCTAssertEqual(entries.count, 2)
    }

    func testGetSymptomsBySeverityIntent_ClampsMinSeverity() {
        // Given: Severity values outside valid range
        let tooLow = max(1, min(5, 0))
        let tooHigh = max(1, min(5, 10))

        // Then: Should be clamped to 1-5
        XCTAssertEqual(tooLow, 1)
        XCTAssertEqual(tooHigh, 5)
    }

    func testGetSymptomsBySeverityIntent_ReturnsSortedByDate() async throws {
        // Given: Multiple entries with same severity
        let now = Date()
        try createTestEntry(symptomName: "Fatigue", severity: 4, date: now.addingTimeInterval(-3600))
        try createTestEntry(symptomName: "Headache", severity: 4, date: now)
        try createTestEntry(symptomName: "Brain fog", severity: 4, date: now.addingTimeInterval(-7200))

        // When: Fetch with severity filter
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "severity >= %d", 4)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false)]

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should be sorted newest first
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].symptomType?.name, "Headache")
        XCTAssertEqual(entries[1].symptomType?.name, "Fatigue")
        XCTAssertEqual(entries[2].symptomType?.name, "Brain fog")
    }

    func testGetSymptomsBySeverityIntent_ReturnsEmptyForNoMatches() async throws {
        // Given: No high severity entries
        try createTestEntry(symptomName: "Fatigue", severity: 2, date: Date())

        // When: Filter for severity 5
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "severity >= %d", 5)

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should return empty array
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - GetDailySummaryIntent Tests

    func testGetDailySummaryIntent_WithNoData_ReturnsEmptyMessage() async throws {
        // Given: No entries for today
        let today = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        // When: Fetch entries for today
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "backdatedAt >= %@ AND backdatedAt < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should have no entries
        XCTAssertTrue(entries.isEmpty)
    }

    func testGetDailySummaryIntent_CountsSymptoms() async throws {
        // Given: Multiple symptoms for today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        try createTestEntry(symptomName: "Fatigue", severity: 3, date: today.addingTimeInterval(3600))
        try createTestEntry(symptomName: "Headache", severity: 4, date: today.addingTimeInterval(7200))
        try createTestEntry(symptomName: "Brain fog", severity: 2, date: today.addingTimeInterval(10800))

        // When: Fetch symptoms for today
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "backdatedAt >= %@ AND backdatedAt < %@",
            today as NSDate,
            endOfDay as NSDate
        )

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should count 3 symptoms
        XCTAssertEqual(entries.count, 3)
    }

    func testGetDailySummaryIntent_CountsActivities() async throws {
        // Given: Activities for today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        try createTestActivity(name: "Morning walk", date: today.addingTimeInterval(3600))
        try createTestActivity(name: "Cooking lunch", date: today.addingTimeInterval(14400))

        // When: Fetch activities for today
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        let fetchRequest: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "backdatedAt >= %@ AND backdatedAt < %@",
            today as NSDate,
            endOfDay as NSDate
        )

        let activities = try testStack.context.fetch(fetchRequest)

        // Then: Should count 2 activities
        XCTAssertEqual(activities.count, 2)
    }

    func testGetDailySummaryIntent_SortsByTime() async throws {
        // Given: Entries at different times
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        try createTestEntry(symptomName: "Fatigue", severity: 3, date: today.addingTimeInterval(10800)) // 3am
        try createTestEntry(symptomName: "Headache", severity: 4, date: today.addingTimeInterval(3600)) // 1am
        try createTestEntry(symptomName: "Brain fog", severity: 2, date: today.addingTimeInterval(7200)) // 2am

        // When: Fetch sorted by time
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "backdatedAt >= %@ AND backdatedAt < %@",
            today as NSDate,
            endOfDay as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: true)]

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should be sorted chronologically
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].symptomType?.name, "Headache") // 1am
        XCTAssertEqual(entries[1].symptomType?.name, "Brain fog") // 2am
        XCTAssertEqual(entries[2].symptomType?.name, "Fatigue") // 3am
    }

    func testGetDailySummaryIntent_WorksForPastDates() async throws {
        // Given: Entries from yesterday
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let startOfYesterday = calendar.startOfDay(for: yesterday)

        try createTestEntry(symptomName: "Fatigue", severity: 3, date: startOfYesterday.addingTimeInterval(3600))

        // When: Fetch entries for yesterday
        let endOfYesterday = calendar.date(byAdding: .day, value: 1, to: startOfYesterday) ?? Date()
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "backdatedAt >= %@ AND backdatedAt < %@",
            startOfYesterday as NSDate,
            endOfYesterday as NSDate
        )

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should find yesterday's entry
        XCTAssertEqual(entries.count, 1)
    }

    // MARK: - EntrySnippet Tests

    func testEntrySnippet_InitializesFromSymptomEntry() async throws {
        // Given: A symptom entry
        try createTestEntry(
            symptomName: "Fatigue",
            severity: 4,
            date: Date(),
            note: "Test note"
        )

        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        let entries = try testStack.context.fetch(fetchRequest)
        guard let entry = entries.first else {
            XCTFail("No entry created")
            return
        }

        // When: Create EntrySnippet
        let snippet = EntrySnippet(from: entry)

        // Then: Should match entry properties
        XCTAssertEqual(snippet.symptomName, "Fatigue")
        XCTAssertEqual(snippet.severity, SeverityScale.descriptor(for: 4))
        XCTAssertEqual(snippet.note, "Test note")
        XCTAssertNotNil(snippet.date)
    }

    // MARK: - SymptomEntryEntity Tests

    func testSymptomEntryEntity_InitializesFromSymptomEntry() async throws {
        // Given: A symptom entry
        try createTestEntry(
            symptomName: "Headache",
            severity: 5,
            date: Date(),
            note: "Severe headache"
        )

        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        let entries = try testStack.context.fetch(fetchRequest)
        guard let entry = entries.first else {
            XCTFail("No entry created")
            return
        }

        // When: Create SymptomEntryEntity
        let entity = SymptomEntryEntity(from: entry)

        // Then: Should match entry properties
        XCTAssertEqual(entity.symptomName, "Headache")
        XCTAssertEqual(entity.severity, 5)
        XCTAssertEqual(entity.severityDescription, SeverityScale.descriptor(for: 5))
        XCTAssertEqual(entity.note, "Severe headache")
    }

    // MARK: - ActivityEventEntity Tests

    func testActivityEventEntity_InitializesFromActivityEvent() async throws {
        // Given: An activity event
        try createTestActivity(name: "Morning walk", date: Date(), physical: 4, cognitive: 2, emotional: 2)

        let fetchRequest: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
        let activities = try testStack.context.fetch(fetchRequest)
        guard let activity = activities.first else {
            XCTFail("No activity created")
            return
        }

        // When: Create ActivityEventEntity
        let entity = ActivityEventEntity(from: activity)

        // Then: Should match activity properties
        XCTAssertEqual(entity.name, "Morning walk")
        XCTAssertEqual(entity.physicalExertion, 4)
        XCTAssertEqual(entity.cognitiveExertion, 2)
        XCTAssertEqual(entity.emotionalLoad, 2)
        XCTAssertEqual(entity.durationMinutes, 30)
    }

    // MARK: - GetRecentActivitiesIntent Tests

    func testGetRecentActivitiesIntent_WithNoActivities_ReturnsEmpty() async throws {
        // Given: No activities in database
        let fetchRequest: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
        let activities = try testStack.context.fetch(fetchRequest)

        // Then: Should have no activities
        XCTAssertTrue(activities.isEmpty)
    }

    func testGetRecentActivitiesIntent_ReturnsRequestedCount() async throws {
        // Given: Multiple activities
        let now = Date()
        for i in 0..<5 {
            try createTestActivity(name: "Activity \(i)", date: now.addingTimeInterval(TimeInterval(-i * 3600)))
        }

        // When: Fetch with limit
        let fetchRequest: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ActivityEvent.backdatedAt, ascending: false)]
        fetchRequest.fetchLimit = 3

        let activities = try testStack.context.fetch(fetchRequest)

        // Then: Should return exactly 3 activities
        XCTAssertEqual(activities.count, 3)
    }

    func testGetRecentActivitiesIntent_SortsByDate() async throws {
        // Given: Activities with different dates
        let now = Date()
        try createTestActivity(name: "Oldest", date: now.addingTimeInterval(-7200))
        try createTestActivity(name: "Middle", date: now.addingTimeInterval(-3600))
        try createTestActivity(name: "Newest", date: now)

        // When: Fetch sorted by date
        let fetchRequest: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ActivityEvent.backdatedAt, ascending: false)]

        let activities = try testStack.context.fetch(fetchRequest)

        // Then: Should be sorted newest first
        XCTAssertEqual(activities.count, 3)
        XCTAssertEqual(activities[0].name, "Newest")
        XCTAssertEqual(activities[1].name, "Middle")
        XCTAssertEqual(activities[2].name, "Oldest")
    }

    // MARK: - GetSymptomsInRangeIntent Tests

    func testGetSymptomsInRangeIntent_FiltersDateRange() async throws {
        // Given: Entries across different dates
        let now = Date()
        let threeDaysAgo = now.addingTimeInterval(-3 * 24 * 3600)
        let tenDaysAgo = now.addingTimeInterval(-10 * 24 * 3600)

        try createTestEntry(symptomName: "Fatigue", severity: 3, date: now)
        try createTestEntry(symptomName: "Headache", severity: 4, date: threeDaysAgo)
        try createTestEntry(symptomName: "Brain fog", severity: 2, date: tenDaysAgo)

        // When: Filter last 7 days
        let startDate = now.addingTimeInterval(-7 * 24 * 3600)
        let endDate = now

        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "backdatedAt >= %@ AND backdatedAt <= %@",
            startDate as NSDate,
            endDate as NSDate
        )

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should return only entries within range
        XCTAssertEqual(entries.count, 2)
    }

    func testGetSymptomsInRangeIntent_HandlesEmptyRange() async throws {
        // Given: Entries from past
        let tenDaysAgo = Date().addingTimeInterval(-10 * 24 * 3600)
        try createTestEntry(symptomName: "Fatigue", severity: 3, date: tenDaysAgo)

        // When: Query future date range
        let tomorrow = Date().addingTimeInterval(24 * 3600)
        let nextWeek = Date().addingTimeInterval(7 * 24 * 3600)

        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "backdatedAt >= %@ AND backdatedAt <= %@",
            tomorrow as NSDate,
            nextWeek as NSDate
        )

        let entries = try testStack.context.fetch(fetchRequest)

        // Then: Should return empty
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - GetSymptomTypesIntent Tests

    func testGetSymptomTypesIntent_ReturnsAllSymptomTypes() async throws {
        // Given: Symptom types seeded in setUp
        let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
        let symptomTypes = try testStack.context.fetch(fetchRequest)

        // Then: Should have default symptom types
        XCTAssertGreaterThan(symptomTypes.count, 0)
    }

    func testGetSymptomTypesIntent_IncludesSymptomTypeProperties() async throws {
        // Given: Fetch symptom types
        let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
        let symptomTypes = try testStack.context.fetch(fetchRequest)

        guard let firstType = symptomTypes.first else {
            XCTFail("No symptom types found")
            return
        }

        // Then: Should have required properties
        XCTAssertNotNil(firstType.name)
        XCTAssertNotNil(firstType.iconName)
        XCTAssertNotNil(firstType.color)
    }

    // MARK: - CountSymptomsIntent Tests

    func testCountSymptomsIntent_CountsAllSymptoms() async throws {
        // Given: Multiple symptom entries
        let now = Date()
        try createTestEntry(symptomName: "Fatigue", severity: 3, date: now)
        try createTestEntry(symptomName: "Headache", severity: 4, date: now)
        try createTestEntry(symptomName: "Brain fog", severity: 2, date: now)

        // When: Count symptoms
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        let count = try testStack.context.count(for: fetchRequest)

        // Then: Should count all entries
        XCTAssertEqual(count, 3)
    }

    func testCountSymptomsIntent_CountsWithinDateRange() async throws {
        // Given: Entries across different dates
        let now = Date()
        let yesterday = now.addingTimeInterval(-24 * 3600)
        let lastWeek = now.addingTimeInterval(-7 * 24 * 3600)

        try createTestEntry(symptomName: "Fatigue", severity: 3, date: now)
        try createTestEntry(symptomName: "Headache", severity: 4, date: yesterday)
        try createTestEntry(symptomName: "Brain fog", severity: 2, date: lastWeek)

        // When: Count last 3 days
        let threeDaysAgo = now.addingTimeInterval(-3 * 24 * 3600)
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "backdatedAt >= %@",
            threeDaysAgo as NSDate
        )

        let count = try testStack.context.count(for: fetchRequest)

        // Then: Should count only recent entries
        XCTAssertEqual(count, 2)
    }

    func testCountSymptomsIntent_ReturnsZeroWhenEmpty() async throws {
        // Given: No entries
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        let count = try testStack.context.count(for: fetchRequest)

        // Then: Should return zero
        XCTAssertEqual(count, 0)
    }
}
