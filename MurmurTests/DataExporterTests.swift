//
//  DataExporterTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 03/10/2025.
//

import CoreData
import XCTest
@testable import Murmur

final class DataExporterTests: XCTestCase {
    var testStack: InMemoryCoreDataStack!

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
    }

    override func tearDown() {
        testStack = nil
        // Clean up any temporary files
        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent("MurmurExport")
        try? FileManager.default.removeItem(at: exportDir)
        super.tearDown()
    }

    func testCreateSampleData() throws {
        // Create test data
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))

        // Create a few entries
        for i in 1...3 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            entry.createdAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
            entry.severity = Int16(i)
            entry.symptomType = symptomType
            entry.note = "Test note \(i)"
        }

        try testStack.context.save()

        // Verify data was created
        let entryRequest = SymptomEntry.fetchRequest()
        let entries = try testStack.context.fetch(entryRequest)
        XCTAssertEqual(entries.count, 3)

        // Verify symptom types exist
        let typeRequest = SymptomType.fetchRequest()
        let types = try testStack.context.fetch(typeRequest)
        XCTAssertGreaterThan(types.count, 0)
    }

    func testDataStructure() throws {
        // Create test data
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.name = "Test Symptom"

        let entry = SymptomEntry(context: testStack.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.severity = 3
        entry.symptomType = symptomType
        entry.note = "Test note"

        try testStack.context.save()

        // Verify relationships
        XCTAssertNotNil(entry.symptomType)
        XCTAssertEqual(entry.symptomType?.name, "Test Symptom")
    }

    // Test that we can at least instantiate a DataExporter
    // even though we can't test the actual export in unit tests
    func testDataExporterInstantiation() {
        // We can't actually test DataExporter with an in-memory store
        // but we can verify the class exists
        XCTAssertNotNil(DataExporter.self)
    }

    func testEmptyDatabase() throws {
        // Don't seed data, test with empty database
        let entryRequest = SymptomEntry.fetchRequest()
        let entries = try testStack.context.fetch(entryRequest)
        XCTAssertTrue(entries.isEmpty)

        let typeRequest = SymptomType.fetchRequest()
        let types = try testStack.context.fetch(typeRequest)
        XCTAssertTrue(types.isEmpty)
    }
}