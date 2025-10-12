//
//  DaySummaryTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 03/10/2025.
//

import CoreData
import XCTest
@testable import Murmur

@MainActor
final class DaySummaryTests: XCTestCase {
    var testStack: InMemoryCoreDataStack?

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
    }

    override func tearDown() {
        testStack = nil
        super.tearDown()
    }

    func testCreateDaySummary() throws {
        let date = Date()
        let summary = DaySummary(
            date: date,
            entryCount: 4,
            uniqueSymptoms: 2,
            averageSeverity: 3.5,
            rawAverageSeverity: 3.5,
            severityLevel: 4,
            appleHealthMoodUUID: nil,
            loadScore: nil
        )

        XCTAssertEqual(summary.date, date)
        XCTAssertEqual(summary.entryCount, 4)
        XCTAssertEqual(summary.uniqueSymptoms, 2)
        XCTAssertEqual(summary.averageSeverity, 3.5)
        XCTAssertEqual(summary.rawAverageSeverity, 3.5)
        XCTAssertEqual(summary.severityLevel, 4)
    }

    func testDaySummaryFromEntries() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack!.context, forceSeed: true)

        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let today = Date()

        // Create entries for today
        var entries: [SymptomEntry] = []
        let severities: [Int16] = [1, 3, 5, 2, 4]
        for severity in severities {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = today
            entry.severity = severity
            entry.symptomType = symptomType
            entries.append(entry)
        }

        try testStack!.context.save()

        // Create summary from entries using the static make method
        let summary = DaySummary.make(for: today, entries: entries)
        XCTAssertNotNil(summary)

        // Verify calculations
        XCTAssertEqual(summary?.entryCount, 5)
        XCTAssertEqual(summary?.averageSeverity, 3.0)
        XCTAssertEqual(summary?.severityLevel, 3)
    }

    func testMultipleDaySummaries() throws {
        let calendar = Calendar.current
        var summaries: [DaySummary] = []

        // Create summaries for the last 7 days
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let summary = DaySummary(
                date: date,
                entryCount: i + 1,
                uniqueSymptoms: 1,
                averageSeverity: Double(i + 1),
                rawAverageSeverity: Double(i + 1),
                severityLevel: min(5, i + 1),
                appleHealthMoodUUID: nil,
                loadScore: nil
            )
            summaries.append(summary)
        }

        // Sort and verify
        summaries.sort { $0.date > $1.date }

        XCTAssertEqual(summaries.count, 7)
        XCTAssertEqual(summaries.first?.rawAverageSeverity, 1.0)
        XCTAssertEqual(summaries.last?.rawAverageSeverity, 7.0)
    }

    func testDaySummaryWithNoEntries() throws {
        let entries: [SymptomEntry] = []
        let summary = DaySummary.make(for: Date(), entries: entries)

        // Should return nil for no entries
        XCTAssertNil(summary)
    }

    func testDaySummaryMakeWithLoadScore() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack!.context, forceSeed: true)

        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let today = Date()

        // Create entries
        var entries: [SymptomEntry] = []
        for i in 1...3 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = today
            entry.severity = Int16(i)
            entry.symptomType = symptomType
            entries.append(entry)
        }

        // Create a mock load score
        let loadScore = LoadScore(
            date: today,
            rawLoad: 50,
            decayedLoad: 45,
            riskLevel: .caution
        )

        let summary = DaySummary.makeWithLoadScore(for: today, entries: entries, loadScore: loadScore)

        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.entryCount, 3)
        XCTAssertEqual(summary?.loadScore?.rawLoad, 50)
    }

    func testDaySummaryTrendCalculation() throws {
        let calendar = Calendar.current
        var summaries: [DaySummary] = []

        // Create a trend: severity decreasing over time (improvement)
        // Working backwards from today: today=1, yesterday=2, ..., 4 days ago=5
        // After sorting by date ascending: 4 days ago=5, 3 days ago=4, ..., today=1
        for i in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let summary = DaySummary(
                date: date,
                entryCount: 3,
                uniqueSymptoms: 2,
                averageSeverity: Double(i + 1), // today=1, yesterday=2, 2 days ago=3, 3 days ago=4, 4 days ago=5
                rawAverageSeverity: Double(i + 1),
                severityLevel: i + 1,
                appleHealthMoodUUID: nil,
                loadScore: nil
            )
            summaries.append(summary)
        }

        // Sort by date ascending (oldest to newest)
        summaries.sort { $0.date < $1.date }

        let severities = summaries.map { $0.averageSeverity }
        let firstHalf = Array(severities.prefix(2)) // First 2 days (oldest): [5, 4]
        let secondHalf = Array(severities.suffix(2)) // Last 2 days (newest): [2, 1]

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count) // (5+4)/2 = 4.5
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count) // (2+1)/2 = 1.5

        // Trend should show improvement (lower severity in recent days)
        XCTAssertLessThan(secondAvg, firstAvg) // 1.5 < 4.5
    }
}

// MARK: - Test Helpers