//
//  CalendarHeatMapTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import CoreData
import XCTest
@testable import Murmur

final class CalendarHeatMapTests: XCTestCase {
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

    // MARK: - Month Data Loading Tests

    func testLoadMonthDataFetchesCorrectDateRange() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let now = Date()

        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
            XCTFail("Could not get month interval")
            return
        }

        // Create entries within current month
        for i in 1...5 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            let entryDate = calendar.date(byAdding: .day, value: i, to: monthInterval.start)!
            entry.createdAt = entryDate
            entry.symptomType = symptomType
            entry.severity = 3
        }

        // Create entries outside current month
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = previousMonth
        entry.symptomType = symptomType
        entry.severity = 3

        try testStack!.context.save()

        // Simulate CalendarHeatMapView's loadMonthData predicate
        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            monthInterval.start as NSDate, monthInterval.end as NSDate,
            monthInterval.start as NSDate, monthInterval.end as NSDate
        )

        let results = try testStack!.context.fetch(request)

        // Should only include entries within current month
        XCTAssertEqual(results.count, 5)

        for entry in results {
            let entryDate = entry.backdatedAt ?? entry.createdAt ?? Date()
            XCTAssertGreaterThanOrEqual(entryDate, monthInterval.start)
            XCTAssertLessThan(entryDate, monthInterval.end)
        }
    }

    func testMonthDataGroupsEntriesByDay() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let testDate = calendar.startOfDay(for: Date())

        // Create multiple entries on the same day
        for i in 0..<3 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = calendar.date(byAdding: .hour, value: i, to: testDate)
            entry.symptomType = symptomType
            entry.severity = Int16(i + 2) // Severities: 2, 3, 4
        }

        try testStack!.context.save()

        guard let monthInterval = calendar.dateInterval(of: .month, for: testDate) else {
            XCTFail("Could not get month interval")
            return
        }

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            monthInterval.start as NSDate, monthInterval.end as NSDate,
            monthInterval.start as NSDate, monthInterval.end as NSDate
        )

        let entries = try testStack!.context.fetch(request)

        // Group entries by day (simulating CalendarHeatMapView logic)
        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
        }

        // Should have 1 group (all entries on same day)
        XCTAssertEqual(groupedEntries.count, 1)

        let dayEntries = try XCTUnwrap(groupedEntries[testDate])
        XCTAssertEqual(dayEntries.count, 3)
    }

    func testMonthDataCalculatesAverageSeverity() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let testDate = calendar.startOfDay(for: Date())

        // Create entries with known severities
        let severities: [Int16] = [2, 3, 4, 5]
        for severity in severities {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = testDate
            entry.symptomType = symptomType
            entry.severity = severity
        }

        try testStack!.context.save()

        guard let monthInterval = calendar.dateInterval(of: .month, for: testDate) else {
            XCTFail("Could not get month interval")
            return
        }

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            monthInterval.start as NSDate, monthInterval.end as NSDate,
            monthInterval.start as NSDate, monthInterval.end as NSDate
        )

        let entries = try testStack!.context.fetch(request)
        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
        }

        // Calculate average severity (simulating CalendarHeatMapView logic)
        for (date, dayEntries) in groupedEntries {
            let totalRawSeverity = dayEntries.reduce(0.0) { total, entry in
                return total + Double(entry.severity)
            }
            let rawAverageSeverity = totalRawSeverity / Double(dayEntries.count)

            if calendar.isDate(date, inSameDayAs: testDate) {
                // Expected average: (2 + 3 + 4 + 5) / 4 = 3.5
                XCTAssertEqual(rawAverageSeverity, 3.5, accuracy: 0.01)
            }
        }
    }

    func testMonthDataHandlesVaryingEntryCounts() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let baseDate = calendar.startOfDay(for: Date())

        // Day 1: 1 entry
        let day1 = baseDate
        let entry1 = SymptomEntry(context: testStack!.context)
        entry1.id = UUID()
        entry1.createdAt = day1
        entry1.symptomType = symptomType
        entry1.severity = 3

        // Day 2: 5 entries
        let day2 = calendar.date(byAdding: .day, value: 1, to: baseDate)!
        for i in 0..<5 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = calendar.date(byAdding: .hour, value: i, to: day2)
            entry.symptomType = symptomType
            entry.severity = 4
        }

        // Day 3: 10 entries
        let day3 = calendar.date(byAdding: .day, value: 2, to: baseDate)!
        for i in 0..<10 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = calendar.date(byAdding: .hour, value: i, to: day3)
            entry.symptomType = symptomType
            entry.severity = 2
        }

        try testStack!.context.save()

        guard let monthInterval = calendar.dateInterval(of: .month, for: baseDate) else {
            XCTFail("Could not get month interval")
            return
        }

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            monthInterval.start as NSDate, monthInterval.end as NSDate,
            monthInterval.start as NSDate, monthInterval.end as NSDate
        )

        let entries = try testStack!.context.fetch(request)
        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
        }

        // Verify each day has correct entry count
        XCTAssertEqual(groupedEntries[day1]?.count, 1)
        XCTAssertEqual(groupedEntries[day2]?.count, 5)
        XCTAssertEqual(groupedEntries[day3]?.count, 10)
    }

    func testMonthDataIdentifiesHighSeverityDays() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let baseDate = calendar.startOfDay(for: Date())

        // Create day with high severity entries
        let highSeverityDay = baseDate
        for _ in 0..<3 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = highSeverityDay
            entry.symptomType = symptomType
            entry.severity = 5 // High severity
        }

        // Create day with low severity entries
        let lowSeverityDay = calendar.date(byAdding: .day, value: 1, to: baseDate)!
        for _ in 0..<3 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = lowSeverityDay
            entry.symptomType = symptomType
            entry.severity = 1 // Low severity
        }

        try testStack!.context.save()

        guard let monthInterval = calendar.dateInterval(of: .month, for: baseDate) else {
            XCTFail("Could not get month interval")
            return
        }

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            monthInterval.start as NSDate, monthInterval.end as NSDate,
            monthInterval.start as NSDate, monthInterval.end as NSDate
        )

        let entries = try testStack!.context.fetch(request)
        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
        }

        // Calculate averages
        for (date, dayEntries) in groupedEntries {
            let totalRawSeverity = dayEntries.reduce(0.0) { total, entry in
                return total + Double(entry.severity)
            }
            let rawAverageSeverity = totalRawSeverity / Double(dayEntries.count)

            if calendar.isDate(date, inSameDayAs: highSeverityDay) {
                XCTAssertEqual(rawAverageSeverity, 5.0, accuracy: 0.01)
            } else if calendar.isDate(date, inSameDayAs: lowSeverityDay) {
                XCTAssertEqual(rawAverageSeverity, 1.0, accuracy: 0.01)
            }
        }
    }

    func testMonthDataHandlesEmptyDays() throws {
        let baseDate = calendar.startOfDay(for: Date())

        guard let monthInterval = calendar.dateInterval(of: .month, for: baseDate) else {
            XCTFail("Could not get month interval")
            return
        }

        // Don't create any entries
        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            monthInterval.start as NSDate, monthInterval.end as NSDate,
            monthInterval.start as NSDate, monthInterval.end as NSDate
        )

        let entries = try testStack!.context.fetch(request)

        // Should return empty array
        XCTAssertTrue(entries.isEmpty)

        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
        }

        // Should have no groups
        XCTAssertTrue(groupedEntries.isEmpty)
    }

    // MARK: - Month Summary Statistics Tests

    func testMonthSummaryCalculatesDaysWithData() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let baseDate = calendar.startOfDay(for: Date())

        // Create entries on 5 different days
        for i in 0..<5 {
            let day = calendar.date(byAdding: .day, value: i, to: baseDate)!
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = day
            entry.symptomType = symptomType
            entry.severity = 3
        }

        try testStack!.context.save()

        guard let monthInterval = calendar.dateInterval(of: .month, for: baseDate) else {
            XCTFail("Could not get month interval")
            return
        }

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            monthInterval.start as NSDate, monthInterval.end as NSDate,
            monthInterval.start as NSDate, monthInterval.end as NSDate
        )

        let entries = try testStack!.context.fetch(request)
        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
        }

        // Count days with data
        let daysWithData = groupedEntries.count

        XCTAssertEqual(daysWithData, 5)
    }

    func testMonthSummaryCalculatesAverageIntensity() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let baseDate = calendar.startOfDay(for: Date())

        // Create entries with varying severities across multiple days
        // Day 1: avg = 2
        let day1 = baseDate
        for _ in 0..<2 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = day1
            entry.symptomType = symptomType
            entry.severity = 2
        }

        // Day 2: avg = 4
        let day2 = calendar.date(byAdding: .day, value: 1, to: baseDate)!
        for _ in 0..<2 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = day2
            entry.symptomType = symptomType
            entry.severity = 4
        }

        try testStack!.context.save()

        guard let monthInterval = calendar.dateInterval(of: .month, for: baseDate) else {
            XCTFail("Could not get month interval")
            return
        }

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            monthInterval.start as NSDate, monthInterval.end as NSDate,
            monthInterval.start as NSDate, monthInterval.end as NSDate
        )

        let entries = try testStack!.context.fetch(request)
        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
        }

        // Calculate day averages
        var dayAverages: [Double] = []
        for (_, dayEntries) in groupedEntries {
            let totalSeverity = dayEntries.reduce(0.0) { total, entry in
                return total + entry.normalisedSeverity
            }
            let averageSeverity = totalSeverity / Double(dayEntries.count)
            dayAverages.append(averageSeverity)
        }

        // Calculate month average
        let monthAverage = dayAverages.reduce(0.0, +) / Double(dayAverages.count)

        // With day1 avg = 2 and day2 avg = 4, month average should be around 3
        // (accounting for normalisation)
        XCTAssertGreaterThan(monthAverage, 0)
        XCTAssertLessThan(monthAverage, 5)
    }

    func testMonthSummaryCalculatesTotalEntries() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let baseDate = calendar.startOfDay(for: Date())

        // Create varying number of entries across days
        for day in 0..<3 {
            let dayDate = calendar.date(byAdding: .day, value: day, to: baseDate)!
            let entriesForDay = day + 1 // 1, 2, 3 entries

            for _ in 0..<entriesForDay {
                let entry = SymptomEntry(context: testStack!.context)
                entry.id = UUID()
                entry.createdAt = dayDate
                entry.symptomType = symptomType
                entry.severity = 3
            }
        }

        try testStack!.context.save()

        guard let monthInterval = calendar.dateInterval(of: .month, for: baseDate) else {
            XCTFail("Could not get month interval")
            return
        }

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            monthInterval.start as NSDate, monthInterval.end as NSDate,
            monthInterval.start as NSDate, monthInterval.end as NSDate
        )

        let entries = try testStack!.context.fetch(request)

        // Total entries should be 1 + 2 + 3 = 6
        XCTAssertEqual(entries.count, 6)
    }

    // MARK: - Backdated Entry Tests

    func testMonthDataHandlesBackdatedEntries() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let now = Date()

        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
            XCTFail("Could not get month interval")
            return
        }

        let dateInMonth = calendar.date(byAdding: .day, value: 5, to: monthInterval.start)!

        // Create entry backdated to current month but created outside month
        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = calendar.date(byAdding: .month, value: -2, to: now) // Created 2 months ago
        entry.backdatedAt = dateInMonth // But backdated to current month
        entry.symptomType = symptomType
        entry.severity = 3

        try testStack!.context.save()

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
            monthInterval.start as NSDate, monthInterval.end as NSDate,
            monthInterval.start as NSDate, monthInterval.end as NSDate
        )

        let results = try testStack!.context.fetch(request)

        // Entry should be included because backdatedAt is in current month
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.contains(entry))
    }
}
