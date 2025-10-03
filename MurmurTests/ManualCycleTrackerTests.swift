//
//  ManualCycleTrackerTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 03/10/2025.
//

import CoreData
import XCTest
@testable import Murmur

final class ManualCycleTrackerTests: XCTestCase {
    var testStack: InMemoryCoreDataStack!

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
    }

    override func tearDown() {
        testStack = nil
        super.tearDown()
    }

    // Since ManualCycleTracker is @MainActor, we need to test it differently
    @MainActor
    func testAddManualCycleEntry() async throws {
        let tracker = ManualCycleTracker(context: testStack.context)

        let date = Date()
        try tracker.addEntry(date: date, flowLevel: "medium")

        // Verify entry was created
        let request = ManualCycleEntry.fetchRequest()
        let entries = try testStack.context.fetch(request)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.flowLevel, "medium")
        XCTAssertNotNil(entries.first?.date)
    }

    @MainActor
    func testRemoveManualCycleEntry() async throws {
        let tracker = ManualCycleTracker(context: testStack.context)

        // Add an entry
        let date = Date()
        try tracker.addEntry(date: date, flowLevel: "heavy")

        // Verify it was added
        let request = ManualCycleEntry.fetchRequest()
        var entries = try testStack.context.fetch(request)
        XCTAssertEqual(entries.count, 1)

        // Remove the entry
        try tracker.removeEntry(date: date)

        // Verify it was removed
        entries = try testStack.context.fetch(request)
        XCTAssertEqual(entries.count, 0)
    }

    @MainActor
    func testUpdateExistingEntry() async throws {
        let tracker = ManualCycleTracker(context: testStack.context)

        let date = Date()

        // Add initial entry
        try tracker.addEntry(date: date, flowLevel: "light")

        // Update the same date with different flow level
        try tracker.addEntry(date: date, flowLevel: "heavy")

        // Should still only have one entry but with updated flow level
        let request = ManualCycleEntry.fetchRequest()
        let entries = try testStack.context.fetch(request)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.flowLevel, "heavy")
    }

    @MainActor
    func testGetFlowLevelForDate() async throws {
        let tracker = ManualCycleTracker(context: testStack.context)
        tracker.setEnabled(true)

        let date = Date()
        try tracker.addEntry(date: date, flowLevel: "medium")

        // Give it a moment to refresh
        try await Task.sleep(nanoseconds: 100_000_000)

        let flowLevel = tracker.flowLevel(for: date)
        XCTAssertEqual(flowLevel, "medium")
    }

    @MainActor
    func testEnableDisableTracking() async throws {
        let tracker = ManualCycleTracker(context: testStack.context)

        // Initially disabled
        XCTAssertFalse(tracker.isEnabled)

        // Enable tracking
        tracker.setEnabled(true)
        XCTAssertTrue(tracker.isEnabled)

        // Disable tracking
        tracker.setEnabled(false)
        XCTAssertFalse(tracker.isEnabled)
    }

    func testManualCycleEntryCreation() throws {
        let entry = ManualCycleEntry.create(
            date: Date(),
            flowLevel: "light",
            in: testStack.context
        )

        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.date)
        XCTAssertEqual(entry.flowLevel, "light")

        try testStack.context.save()

        let request = ManualCycleEntry.fetchRequest()
        let entries = try testStack.context.fetch(request)
        XCTAssertEqual(entries.count, 1)
    }

    @MainActor
    func testSetCycleDay() async throws {
        let tracker = ManualCycleTracker(context: testStack.context)
        tracker.setEnabled(true)

        // Set cycle day 15
        tracker.setCycleDay(15)

        // Give it a moment to update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Check that the cycle day was set
        XCTAssertEqual(tracker.latestCycleDay, 15)
    }

    func testMultipleEntriesOverTime() throws {
        let calendar = Calendar.current

        // Create entries for different days
        for i in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let flowLevel = ["light", "medium", "heavy", "spotting", "none"][i]
            _ = ManualCycleEntry.create(date: date, flowLevel: flowLevel, in: testStack.context)
        }

        try testStack.context.save()

        // Verify all entries were created
        let request = ManualCycleEntry.fetchRequest()
        let entries = try testStack.context.fetch(request)
        XCTAssertEqual(entries.count, 5)
    }
}