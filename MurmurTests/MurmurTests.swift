//
//  MurmurTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CoreData
import XCTest
@testable import Murmur

final class MurmurTests: XCTestCase {
    var testStack: InMemoryCoreDataStack!

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
    }

    override func tearDown() {
        testStack = nil
        super.tearDown()
    }

    // MARK: - Sample Data Tests

    func testSampleDataSeedCreatesTypes() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        let request = SymptomType.fetchRequest()
        let types = try testStack.context.fetch(request)
        XCTAssertFalse(types.isEmpty, "Should create default symptom types")
        XCTAssertGreaterThan(types.count, 50, "Should have many default symptoms")
    }

    func testPositiveSymptomsExist() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        let request = SymptomType.fetchRequest()
        let types = try testStack.context.fetch(request)

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
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        let request = SymptomType.fetchRequest()
        let types = try testStack.context.fetch(request)

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

    func testSymptomCategoriesAreCorrect() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        let request = SymptomType.fetchRequest()
        let types = try testStack.context.fetch(request)

        // Check category distribution
        let categories = Set(types.compactMap { $0.category })
        XCTAssertTrue(categories.contains("Physical"), "Should have Physical category")
        XCTAssertTrue(categories.contains("Mental/emotional"), "Should have Mental/emotional category")
        XCTAssertTrue(categories.contains("Positive wellbeing"), "Should have Positive wellbeing category")

        // Verify at least some symptoms in each category
        for category in categories {
            let symptomsInCategory = types.filter { $0.category == category }
            XCTAssertFalse(symptomsInCategory.isEmpty, "Category \(category) should have symptoms")
        }
    }

    // MARK: - Symptom Entry Tests

    func testCreateSymptomEntry() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))

        let entry = SymptomEntry(context: testStack.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.severity = 3
        entry.symptomType = symptomType
        entry.note = "Test note"

        try testStack.context.save()

        let fetchedEntry = try XCTUnwrap(fetchFirstObject(SymptomEntry.fetchRequest(), in: testStack.context))
        XCTAssertEqual(fetchedEntry.severity, 3)
        XCTAssertEqual(fetchedEntry.note, "Test note")
        XCTAssertEqual(fetchedEntry.symptomType, symptomType)
    }

    func testSymptomEntrySafeAccessors() throws {
        let entry = SymptomEntry(context: testStack.context)

        // Test safeId generation
        XCTAssertNil(entry.id)
        let generatedId = entry.safeId
        XCTAssertNotNil(generatedId)
        XCTAssertEqual(entry.id, generatedId)

        // Test safeCreatedAt with nil date
        XCTAssertNil(entry.createdAt)
        let safeDate = entry.safeCreatedAt
        XCTAssertNotNil(safeDate)

        // Test backdated date
        let backdatedDate = Date().addingTimeInterval(-3600)
        entry.backdatedAt = backdatedDate
        XCTAssertEqual(entry.backdatedAt, backdatedDate)
    }

    func testMultipleEntriesForSameSymptom() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))

        // Create multiple entries for the same symptom
        for i in 1...5 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            entry.createdAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
            entry.severity = Int16(i)
            entry.symptomType = symptomType
        }

        try testStack.context.save()

        // Fetch and verify
        let request: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(format: "symptomType == %@", symptomType)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)]

        let entries = try testStack.context.fetch(request)
        XCTAssertEqual(entries.count, 5)
        XCTAssertEqual(entries.first?.severity, 1)
        XCTAssertEqual(entries.last?.severity, 5)
    }

    // MARK: - Severity Scale Tests

    func testSeverityScaleDescriptorsForNegativeSymptoms() {
        XCTAssertEqual(SeverityScale.descriptor(for: 1, isPositive: false), "Stable")
        XCTAssertEqual(SeverityScale.descriptor(for: 2, isPositive: false), "Manageable")
        XCTAssertEqual(SeverityScale.descriptor(for: 3, isPositive: false), "Challenging")
        XCTAssertEqual(SeverityScale.descriptor(for: 4, isPositive: false), "Severe")
        XCTAssertEqual(SeverityScale.descriptor(for: 5, isPositive: false), "Crisis")
    }

    func testSeverityScaleDescriptorsForPositiveSymptoms() {
        XCTAssertEqual(SeverityScale.descriptor(for: 1, isPositive: true), "Very low")
        XCTAssertEqual(SeverityScale.descriptor(for: 2, isPositive: true), "Low")
        XCTAssertEqual(SeverityScale.descriptor(for: 3, isPositive: true), "Moderate")
        XCTAssertEqual(SeverityScale.descriptor(for: 4, isPositive: true), "High")
        XCTAssertEqual(SeverityScale.descriptor(for: 5, isPositive: true), "Very high")
    }

    func testSeverityScaleClampsBounds() {
        // Test values below minimum
        XCTAssertEqual(SeverityScale.descriptor(for: 0, isPositive: false), "Stable")
        XCTAssertEqual(SeverityScale.descriptor(for: -1, isPositive: false), "Stable")

        // Test values above maximum
        XCTAssertEqual(SeverityScale.descriptor(for: 6, isPositive: false), "Crisis")
        XCTAssertEqual(SeverityScale.descriptor(for: 100, isPositive: false), "Crisis")

        // Same for positive symptoms
        XCTAssertEqual(SeverityScale.descriptor(for: 0, isPositive: true), "Very low")
        XCTAssertEqual(SeverityScale.descriptor(for: 6, isPositive: true), "Very high")
    }

    // MARK: - Color Palette Tests

    func testColorPaletteDefaultValues() {
        let defaultPalette = ColorPalette.lightPalettes.first { $0.id == "default" }
        XCTAssertNotNil(defaultPalette)
        XCTAssertEqual(defaultPalette?.name, "Default")
        XCTAssertEqual(defaultPalette?.accent, "#007AFF")
    }

    func testColorPaletteAllHaveRequiredFields() {
        for palette in ColorPalette.lightPalettes {
            XCTAssertFalse(palette.id.isEmpty)
            XCTAssertFalse(palette.name.isEmpty)
            XCTAssertTrue(palette.background.hasPrefix("#"))
            XCTAssertTrue(palette.surface.hasPrefix("#"))
            XCTAssertTrue(palette.accent.hasPrefix("#"))
            XCTAssertTrue(palette.severity1.hasPrefix("#"))
            XCTAssertTrue(palette.severity2.hasPrefix("#"))
            XCTAssertTrue(palette.severity3.hasPrefix("#"))
            XCTAssertTrue(palette.severity4.hasPrefix("#"))
            XCTAssertTrue(palette.severity5.hasPrefix("#"))
        }

        for palette in ColorPalette.darkPalettes {
            XCTAssertFalse(palette.id.isEmpty)
            XCTAssertFalse(palette.name.isEmpty)
            XCTAssertTrue(palette.background.hasPrefix("#"))
            XCTAssertTrue(palette.surface.hasPrefix("#"))
            XCTAssertTrue(palette.accent.hasPrefix("#"))
        }
    }

    func testColorPaletteUniqueness() {
        let lightIds = ColorPalette.lightPalettes.map { $0.id }
        let darkIds = ColorPalette.darkPalettes.map { $0.id }

        XCTAssertEqual(Set(lightIds).count, lightIds.count, "Light palette IDs should be unique")
        XCTAssertEqual(Set(darkIds).count, darkIds.count, "Dark palette IDs should be unique")
    }
}
