// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// TimelineViewTests.swift
// Created by Aidan Cornelius-Bell on 06/10/2025.
// Tests for timeline view model.
//
import CoreData
import XCTest
@testable import Murmur

final class TimelineViewTests: XCTestCase {
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

    // MARK: - FetchRequest Predicate Tests

    func testFetchRequestPredicateFiltersLast30Days() throws {
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        // Create entries within 30-day window
        for i in 0..<10 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = calendar.date(byAdding: .day, value: -i, to: now)
            entry.symptomType = symptomType
            entry.severity = 3
        }

        // Create entries outside 30-day window
        for i in 31..<35 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = calendar.date(byAdding: .day, value: -i, to: now)
            entry.symptomType = symptomType
            entry.severity = 3
        }

        try testStack!.context.save()

        // Simulate the TimelineView predicate
        let today = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )

        let results = try testStack!.context.fetch(request)

        // Should only include entries within 30-day window (10 entries)
        XCTAssertEqual(results.count, 10)

        // Verify all results are within the window
        for entry in results {
            let entryDate = entry.backdatedAt ?? entry.createdAt ?? Date()
            XCTAssertGreaterThanOrEqual(entryDate, startDate)
        }
    }

    func testFetchRequestHandlesBackdatedAtCorrectly() throws {
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        let today = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        // Create entry with backdatedAt within window
        let entry1 = SymptomEntry(context: testStack!.context)
        entry1.id = UUID()
        entry1.createdAt = calendar.date(byAdding: .day, value: -40, to: now) // Outside window
        entry1.backdatedAt = calendar.date(byAdding: .day, value: -10, to: now) // Inside window
        entry1.symptomType = symptomType
        entry1.severity = 3

        // Create entry with backdatedAt outside window
        let entry2 = SymptomEntry(context: testStack!.context)
        entry2.id = UUID()
        entry2.createdAt = calendar.date(byAdding: .day, value: -5, to: now) // Inside window
        entry2.backdatedAt = calendar.date(byAdding: .day, value: -40, to: now) // Outside window
        entry2.symptomType = symptomType
        entry2.severity = 3

        try testStack!.context.save()

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )

        let results = try testStack!.context.fetch(request)

        // Should include entry1 (backdatedAt in window) but not entry2 (backdatedAt outside window)
        XCTAssertTrue(results.contains(entry1))
        XCTAssertFalse(results.contains(entry2))
    }

    func testFetchRequestHandlesNilBackdatedAt() throws {
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        let today = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        // Create entry with nil backdatedAt, createdAt within window
        let entry1 = SymptomEntry(context: testStack!.context)
        entry1.id = UUID()
        entry1.createdAt = calendar.date(byAdding: .day, value: -10, to: now)
        entry1.backdatedAt = nil
        entry1.symptomType = symptomType
        entry1.severity = 3

        // Create entry with nil backdatedAt, createdAt outside window
        let entry2 = SymptomEntry(context: testStack!.context)
        entry2.id = UUID()
        entry2.createdAt = calendar.date(byAdding: .day, value: -40, to: now)
        entry2.backdatedAt = nil
        entry2.symptomType = symptomType
        entry2.severity = 3

        try testStack!.context.save()

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )

        let results = try testStack!.context.fetch(request)

        // Should include entry1 but not entry2
        XCTAssertTrue(results.contains(entry1))
        XCTAssertFalse(results.contains(entry2))
    }

    func testFetchRequestIncludesAllEventTypes() throws {
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        let today = calendar.startOfDay(for: now)
        let startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let recentDate = calendar.date(byAdding: .day, value: -5, to: now)!

        // Create one of each event type
        let symptomEntry = SymptomEntry(context: testStack!.context)
        symptomEntry.id = UUID()
        symptomEntry.createdAt = recentDate
        symptomEntry.symptomType = symptomType
        symptomEntry.severity = 3

        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = recentDate
        activity.name = "Test Activity"
        activity.physicalExertion = 2
        activity.cognitiveExertion = 1
        activity.emotionalLoad = 1

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = recentDate
        sleep.bedTime = calendar.date(byAdding: .hour, value: -8, to: recentDate)
        sleep.wakeTime = recentDate
        sleep.quality = 3

        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = recentDate
        meal.mealType = "Breakfast"
        meal.mealDescription = "Toast and eggs"

        try testStack!.context.save()

        // Test each event type's fetch request
        let entriesRequest = SymptomEntry.fetchRequest()
        entriesRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )
        let entries = try testStack!.context.fetch(entriesRequest)
        XCTAssertGreaterThan(entries.count, 0)

        let activitiesRequest = ActivityEvent.fetchRequest()
        activitiesRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )
        let activities = try testStack!.context.fetch(activitiesRequest)
        XCTAssertGreaterThan(activities.count, 0)

        let sleepRequest = SleepEvent.fetchRequest()
        sleepRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )
        let sleepEvents = try testStack!.context.fetch(sleepRequest)
        XCTAssertGreaterThan(sleepEvents.count, 0)

        let mealsRequest = MealEvent.fetchRequest()
        mealsRequest.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )
        let meals = try testStack!.context.fetch(mealsRequest)
        XCTAssertGreaterThan(meals.count, 0)
    }

    // MARK: - DaySection Grouping Tests

    @MainActor
    func testDaySectionGroupsByDate() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let now = Date()

        // Create entries on different days
        let entry1 = SymptomEntry(context: testStack!.context)
        entry1.id = UUID()
        entry1.createdAt = calendar.date(byAdding: .day, value: -1, to: now)
        entry1.symptomType = symptomType
        entry1.severity = 3

        let entry2 = SymptomEntry(context: testStack!.context)
        entry2.id = UUID()
        entry2.createdAt = calendar.date(byAdding: .day, value: -1, to: now)! // Same day as entry1
        entry2.symptomType = symptomType
        entry2.severity = 4

        let entry3 = SymptomEntry(context: testStack!.context)
        entry3.id = UUID()
        entry3.createdAt = calendar.date(byAdding: .day, value: -2, to: now)
        entry3.symptomType = symptomType
        entry3.severity = 2

        try testStack!.context.save()

        let sections = DaySection.sectionsFromArrays(
            entries: [entry1, entry2, entry3],
            activities: [],
            sleepEvents: [],
            mealEvents: []
        )

        // Should have 2 sections (2 different days)
        XCTAssertEqual(sections.count, 2)

        // First section (most recent) should have 2 entries
        let firstSection = sections.first
        XCTAssertEqual(firstSection?.entries.count, 2)

        // Second section should have 1 entry
        let secondSection = sections.last
        XCTAssertEqual(secondSection?.entries.count, 1)
    }

    @MainActor
    func testDaySectionHandlesBackdatedEntries() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let now = Date()

        // Create entry backdated to different day
        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = now // Created today
        entry.backdatedAt = calendar.date(byAdding: .day, value: -3, to: now) // But backdated to 3 days ago
        entry.symptomType = symptomType
        entry.severity = 3

        try testStack!.context.save()

        let sections = DaySection.sectionsFromArrays(
            entries: [entry],
            activities: [],
            sleepEvents: [],
            mealEvents: []
        )

        // Entry should appear on backdated date
        let sectionDate = calendar.startOfDay(for: entry.backdatedAt!)
        let matchingSection = sections.first { calendar.isDate($0.date, inSameDayAs: sectionDate) }

        XCTAssertNotNil(matchingSection)
        XCTAssertTrue(matchingSection?.entries.contains(entry) ?? false)
    }

    @MainActor
    func testDaySectionGroupsMixedEventTypes() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let testDate = calendar.date(byAdding: .day, value: -5, to: Date())!

        // Create all event types on the same day
        let symptomEntry = SymptomEntry(context: testStack!.context)
        symptomEntry.id = UUID()
        symptomEntry.createdAt = testDate
        symptomEntry.symptomType = symptomType
        symptomEntry.severity = 3

        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = testDate
        activity.name = "Test Activity"
        activity.physicalExertion = 2
        activity.cognitiveExertion = 1
        activity.emotionalLoad = 1

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = testDate
        sleep.bedTime = calendar.date(byAdding: .hour, value: -8, to: testDate)
        sleep.wakeTime = testDate
        sleep.quality = 4

        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = testDate
        meal.mealType = "Lunch"
        meal.mealDescription = "Salad with chicken"

        try testStack!.context.save()

        let sections = DaySection.sectionsFromArrays(
            entries: [symptomEntry],
            activities: [activity],
            sleepEvents: [sleep],
            mealEvents: [meal]
        )

        // Should have 1 section
        XCTAssertEqual(sections.count, 1)

        let section = try XCTUnwrap(sections.first)

        // Verify all event types are included
        XCTAssertEqual(section.entries.count, 1)
        XCTAssertEqual(section.activities.count, 1)
        XCTAssertEqual(section.sleepEvents.count, 1)
        XCTAssertEqual(section.mealEvents.count, 1)
    }

    @MainActor
    func testDaySectionsSortedChronologically() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let now = Date()

        // Create entries in random order
        let dates = [
            calendar.date(byAdding: .day, value: -5, to: now)!,
            calendar.date(byAdding: .day, value: -1, to: now)!,
            calendar.date(byAdding: .day, value: -10, to: now)!,
            calendar.date(byAdding: .day, value: -3, to: now)!
        ]

        var entries: [SymptomEntry] = []
        for date in dates {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = date
            entry.symptomType = symptomType
            entry.severity = 3
            entries.append(entry)
        }

        try testStack!.context.save()

        let sections = DaySection.sectionsFromArrays(
            entries: entries,
            activities: [],
            sleepEvents: [],
            mealEvents: []
        )

        // Sections should be sorted by date descending (most recent first)
        for i in 0..<sections.count - 1 {
            XCTAssertGreaterThan(sections[i].date, sections[i + 1].date)
        }
    }

    @MainActor
    func testDaySectionHandlesEmptyInput() throws {
        let sections = DaySection.sectionsFromArrays(
            entries: [],
            activities: [],
            sleepEvents: [],
            mealEvents: []
        )

        XCTAssertTrue(sections.isEmpty)
    }

    // MARK: - Timeline Item Ordering Tests

    @MainActor
    func testTimelineItemsWithinDaySortedByTime() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let baseDate = calendar.startOfDay(for: Date())

        // Create entries at different times on the same day
        let entry1 = SymptomEntry(context: testStack!.context)
        entry1.id = UUID()
        entry1.createdAt = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate)
        entry1.symptomType = symptomType
        entry1.severity = 3

        let entry2 = SymptomEntry(context: testStack!.context)
        entry2.id = UUID()
        entry2.createdAt = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: baseDate)
        entry2.symptomType = symptomType
        entry2.severity = 4

        let entry3 = SymptomEntry(context: testStack!.context)
        entry3.id = UUID()
        entry3.createdAt = calendar.date(bySettingHour: 11, minute: 15, second: 0, of: baseDate)
        entry3.symptomType = symptomType
        entry3.severity = 2

        try testStack!.context.save()

        let sections = DaySection.sectionsFromArrays(
            entries: [entry1, entry2, entry3],
            activities: [],
            sleepEvents: [],
            mealEvents: []
        )

        let section = try XCTUnwrap(sections.first)
        let items = section.timelineItems

        // Items should be sorted by time descending (most recent first)
        XCTAssertEqual(items.count, 3)

        // Verify order: 14:30 -> 11:15 -> 9:00
        for i in 0..<items.count - 1 {
            XCTAssertGreaterThan(items[i].date, items[i + 1].date)
        }
    }

    @MainActor
    func testMidnightEntriesBelongToCorrectDay() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let baseDate = calendar.startOfDay(for: Date())

        // Create entry at midnight (start of day)
        let midnightEntry = SymptomEntry(context: testStack!.context)
        midnightEntry.id = UUID()
        midnightEntry.createdAt = baseDate // Exactly midnight
        midnightEntry.symptomType = symptomType
        midnightEntry.severity = 3

        // Create entry one second before midnight (end of previous day)
        let previousDayEntry = SymptomEntry(context: testStack!.context)
        previousDayEntry.id = UUID()
        previousDayEntry.createdAt = calendar.date(byAdding: .second, value: -1, to: baseDate)
        previousDayEntry.symptomType = symptomType
        previousDayEntry.severity = 4

        try testStack!.context.save()

        let sections = DaySection.sectionsFromArrays(
            entries: [midnightEntry, previousDayEntry],
            activities: [],
            sleepEvents: [],
            mealEvents: []
        )

        // Should have 2 sections (2 different days)
        XCTAssertEqual(sections.count, 2)

        // Find the section for baseDate
        let todaySection = sections.first { calendar.isDate($0.date, inSameDayAs: baseDate) }
        XCTAssertNotNil(todaySection)
        XCTAssertTrue(todaySection?.entries.contains(midnightEntry) ?? false)
        XCTAssertFalse(todaySection?.entries.contains(previousDayEntry) ?? false)
    }

    // MARK: - DaySummary Integration Tests

    @MainActor
    func testDaySectionIncludesDaySummary() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let testDate = calendar.date(byAdding: .day, value: -5, to: Date())!

        // Create multiple entries on the same day
        for severity in [2, 3, 4] {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = testDate
            entry.symptomType = symptomType
            entry.severity = Int16(severity)
        }

        try testStack!.context.save()

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt < %@",
            calendar.startOfDay(for: testDate) as NSDate,
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: testDate))! as NSDate
        )
        let entries = try testStack!.context.fetch(request)

        let sections = DaySection.sectionsFromArrays(
            entries: entries,
            activities: [],
            sleepEvents: [],
            mealEvents: []
        )

        let section = try XCTUnwrap(sections.first)
        let summary = try XCTUnwrap(section.summary)

        // Verify summary is calculated correctly
        XCTAssertEqual(summary.entryCount, 3)
        XCTAssertEqual(summary.rawAverageSeverity, 3.0, accuracy: 0.1) // (2+3+4)/3 = 3
    }
}
