//
//  SymptomEntryCreationTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import CoreData
import CoreLocation
import XCTest
@testable import Murmur

@MainActor
final class SymptomEntryCreationTests: XCTestCase {

    var testStack: InMemoryCoreDataStack!
    var mockHealthKit: MockHealthKitAssistant!
    var mockLocation: MockLocationAssistant!

    override func setUp() async throws {
        testStack = InMemoryCoreDataStack()
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        mockHealthKit = MockHealthKitAssistant()
        mockLocation = MockLocationAssistant()
    }

    override func tearDown() {
        testStack = nil
        mockHealthKit = nil
        mockLocation = nil
    }

    // MARK: - Basic Entry Creation Tests

    func testSaveSingleSymptomEntry() async throws {
        // Given: One selected symptom
        let symptomTypes = try testStack.context.fetch(SymptomType.fetchRequest())
        guard let symptomType = symptomTypes.first else {
            XCTFail("No symptom types available")
            return
        }

        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Should create one entry
        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(entry.createdAt)
        XCTAssertEqual(entry.severity, 3)
        XCTAssertEqual(entry.symptomType, symptomType)
    }

    func testSaveMultipleSymptomEntries() async throws {
        // Given: Multiple selected symptoms
        let symptomTypes = try testStack.context.fetch(SymptomType.fetchRequest())
        let selectedSymptoms = symptomTypes.prefix(3).map {
            SelectedSymptom(symptomType: $0, severity: 4)
        }

        // When: Create entries
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: selectedSymptoms,
            note: "Multiple symptoms",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Should create three entries
        XCTAssertEqual(entries.count, 3)

        // All entries should have unique IDs
        let ids = Set(entries.compactMap { $0.id })
        XCTAssertEqual(ids.count, 3)

        // All entries should have same note and severity
        for entry in entries {
            XCTAssertEqual(entry.note, "Multiple symptoms")
            XCTAssertEqual(entry.severity, 4)
        }
    }

    func testSaveWithMaxSymptoms() async throws {
        // Given: Maximum allowed symptoms (5)
        let symptomTypes = try testStack.context.fetch(SymptomType.fetchRequest())
        let selectedSymptoms = symptomTypes.prefix(5).map {
            SelectedSymptom(symptomType: $0, severity: 2)
        }

        // When: Create entries
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: selectedSymptoms,
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Should create all five entries
        XCTAssertEqual(entries.count, 5)
    }

    func testEachEntryGetsUniqueUUID() async throws {
        // Given: Multiple symptoms
        let symptomTypes = try testStack.context.fetch(SymptomType.fetchRequest())
        let selectedSymptoms = symptomTypes.prefix(3).map {
            SelectedSymptom(symptomType: $0, severity: 3)
        }

        // When: Create entries
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: selectedSymptoms,
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Each entry should have a unique UUID
        let uuids = entries.compactMap { $0.id }
        XCTAssertEqual(uuids.count, 3)
        XCTAssertEqual(Set(uuids).count, 3) // All unique
    }

    func testCreatedAtSetToCurrentTime() async throws {
        // Given: Symptom to save
        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        let beforeSave = Date()

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date().addingTimeInterval(-3600), // Backdated 1 hour
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        let afterSave = Date()

        // Then: createdAt should be current time (not backdated)
        let entry = entries[0]
        XCTAssertNotNil(entry.createdAt)
        XCTAssertGreaterThanOrEqual(entry.createdAt!, beforeSave)
        XCTAssertLessThanOrEqual(entry.createdAt!, afterSave)
    }

    func testBackdatedAtSetToUserSelectedTimestamp() async throws {
        // Given: Symptom with backdated timestamp
        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)
        let backdatedTime = Date().addingTimeInterval(-7200) // 2 hours ago

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: backdatedTime,
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: backdatedAt should match user-selected timestamp
        let entry = entries[0]
        XCTAssertEqual(entry.backdatedAt, backdatedTime)
    }

    func testSeveritySavedCorrectly() async throws {
        // Given: Symptoms with different severities
        let symptomTypes = try testStack.context.fetch(SymptomType.fetchRequest())
        let severities: [Double] = [1, 2, 3, 4, 5]
        let selectedSymptoms = zip(symptomTypes.prefix(5), severities).map { type, severity in
            SelectedSymptom(symptomType: type, severity: severity)
        }

        // When: Create entries
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: selectedSymptoms,
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Each entry should have correct severity
        for (index, entry) in entries.enumerated() {
            XCTAssertEqual(entry.severity, Int16(severities[index]))
        }
    }

    func testNotesTrimmedAndSaved() async throws {
        // Given: Symptom with note containing whitespace
        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry with padded note
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "  Test note with spaces  ",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Note should be trimmed
        XCTAssertEqual(entries[0].note, "Test note with spaces")
    }

    func testEmptyNoteBecomesNil() async throws {
        // Given: Symptom with empty note
        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry with empty/whitespace note
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "   ",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Note should be nil
        XCTAssertNil(entries[0].note)
    }

    func testRelationshipToSymptomTypeEstablished() async throws {
        // Given: Symptom to save
        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Relationship should be set
        XCTAssertEqual(entries[0].symptomType, symptomType)
    }

    // MARK: - HealthKit Enrichment Tests

    func testAllHealthKitMetricsFetchedInParallel() async throws {
        // Given: Mock HealthKit with all metrics
        mockHealthKit.configureAllMetrics(
            hrv: 45.2,
            restingHR: 62.0,
            sleepHours: 7.5,
            workoutMinutes: 30.0,
            cycleDay: 14,
            flowLevel: "light"
        )

        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        _ = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: All metrics should have been fetched
        XCTAssertEqual(mockHealthKit.hrvCallCount, 1)
        XCTAssertEqual(mockHealthKit.restingHRCallCount, 1)
        XCTAssertEqual(mockHealthKit.sleepCallCount, 1)
        XCTAssertEqual(mockHealthKit.workoutCallCount, 1)
        XCTAssertEqual(mockHealthKit.cycleDayCallCount, 1)
        XCTAssertEqual(mockHealthKit.flowLevelCallCount, 1)
    }

    func testHRVAttachedWhenAvailable() async throws {
        // Given: Mock HealthKit with HRV
        mockHealthKit.mockHRV = 45.2

        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: HRV should be attached
        XCTAssertEqual(entries[0].hkHRV?.doubleValue, 45.2)
    }

    func testRestingHRAttachedWhenAvailable() async throws {
        // Given: Mock HealthKit with resting HR
        mockHealthKit.mockRestingHR = 62.0

        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Resting HR should be attached
        XCTAssertEqual(entries[0].hkRestingHR?.doubleValue, 62.0)
    }

    func testSleepHoursAttachedWhenAvailable() async throws {
        // Given: Mock HealthKit with sleep data
        mockHealthKit.mockSleepHours = 7.5

        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Sleep hours should be attached
        XCTAssertEqual(entries[0].hkSleepHours?.doubleValue, 7.5)
    }

    func testWorkoutMinutesAttachedWhenAvailable() async throws {
        // Given: Mock HealthKit with workout data
        mockHealthKit.mockWorkoutMinutes = 30.0

        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Workout minutes should be attached
        XCTAssertEqual(entries[0].hkWorkoutMinutes?.doubleValue, 30.0)
    }

    func testCycleDayAttachedWhenAvailable() async throws {
        // Given: Mock HealthKit with cycle data
        mockHealthKit.mockCycleDay = 14

        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Cycle day should be attached
        XCTAssertEqual(entries[0].hkCycleDay?.intValue, 14)
    }

    func testFlowLevelAttachedWhenAvailable() async throws {
        // Given: Mock HealthKit with flow data
        mockHealthKit.mockFlowLevel = "light"

        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Flow level should be attached
        XCTAssertEqual(entries[0].hkFlowLevel, "light")
    }

    func testAllEntriesGetSameHealthKitData() async throws {
        // Given: Multiple symptoms and HealthKit data
        mockHealthKit.configureAllMetrics(
            hrv: 45.2,
            restingHR: 62.0,
            sleepHours: 7.5,
            workoutMinutes: 30.0,
            cycleDay: 14,
            flowLevel: "light"
        )

        let symptomTypes = try testStack.context.fetch(SymptomType.fetchRequest())
        let selectedSymptoms = symptomTypes.prefix(3).map {
            SelectedSymptom(symptomType: $0, severity: 4)
        }

        // When: Create entries
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: selectedSymptoms,
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: All entries should have same HealthKit data
        for entry in entries {
            XCTAssertEqual(entry.hkHRV?.doubleValue, 45.2)
            XCTAssertEqual(entry.hkRestingHR?.doubleValue, 62.0)
            XCTAssertEqual(entry.hkSleepHours?.doubleValue, 7.5)
            XCTAssertEqual(entry.hkWorkoutMinutes?.doubleValue, 30.0)
            XCTAssertEqual(entry.hkCycleDay?.intValue, 14)
            XCTAssertEqual(entry.hkFlowLevel, "light")
        }

        // HealthKit should only be queried once per metric
        XCTAssertEqual(mockHealthKit.hrvCallCount, 1)
        XCTAssertEqual(mockHealthKit.restingHRCallCount, 1)
        XCTAssertEqual(mockHealthKit.sleepCallCount, 1)
    }

    func testMissingHealthKitDataHandledGracefully() async throws {
        // Given: Mock HealthKit with no data (all nil)
        mockHealthKit.reset() // All metrics are nil

        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Entry should be created without HealthKit data
        let entry = entries[0]
        XCTAssertNil(entry.hkHRV)
        XCTAssertNil(entry.hkRestingHR)
        XCTAssertNil(entry.hkSleepHours)
        XCTAssertNil(entry.hkWorkoutMinutes)
        XCTAssertNil(entry.hkCycleDay)
        XCTAssertNil(entry.hkFlowLevel)
    }

    // MARK: - Location Enrichment Tests

    func testLocationAttachedWhenEnabled() async throws {
        // Given: Location enabled with mock placemark
        let placemark = CLPlacemark.mockSydney()
        mockLocation.mockPlacemark = placemark

        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry with location
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: true,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Location should be attached
        XCTAssertNotNil(entries[0].locationPlacemark)
        XCTAssertEqual(entries[0].locationPlacemark?.locality, "Sydney")
    }

    func testLocationNotAttachedWhenDisabled() async throws {
        // Given: Location disabled
        let placemark = CLPlacemark.mockSydney()
        mockLocation.mockPlacemark = placemark

        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry without location
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Location should not be attached
        XCTAssertNil(entries[0].locationPlacemark)
    }

    func testSamePlacemarkSharedAcrossAllEntries() async throws {
        // Given: Multiple symptoms with location enabled
        let placemark = CLPlacemark.mockMelbourne()
        mockLocation.mockPlacemark = placemark

        let symptomTypes = try testStack.context.fetch(SymptomType.fetchRequest())
        let selectedSymptoms = symptomTypes.prefix(3).map {
            SelectedSymptom(symptomType: $0, severity: 4)
        }

        // When: Create entries
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: selectedSymptoms,
            note: "",
            timestamp: Date(),
            includeLocation: true,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: All entries should have same placemark
        for entry in entries {
            XCTAssertNotNil(entry.locationPlacemark)
            XCTAssertEqual(entry.locationPlacemark?.locality, "Melbourne")
        }
    }

    // MARK: - Save Transaction Tests

    func testContextProcessPendingChangesCalled() async throws {
        // Given: Symptom to save
        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        _ = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Context should have been saved
        XCTAssertFalse(testStack.context.hasChanges)
    }

    func testAllEntriesCommittedAtomically() async throws {
        // Given: Multiple symptoms
        let symptomTypes = try testStack.context.fetch(SymptomType.fetchRequest())
        let selectedSymptoms = symptomTypes.prefix(3).map {
            SelectedSymptom(symptomType: $0, severity: 4)
        }

        // When: Create entries
        _ = try await SymptomEntryService.createEntries(
            selectedSymptoms: selectedSymptoms,
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: All entries should be persisted
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        let saved = try testStack.context.fetch(fetchRequest)
        XCTAssertEqual(saved.count, 3)
    }

    // MARK: - Error Handling and Rollback Tests

    func testNoSymptomsSelectedThrowsError() async {
        // Given: Empty symptoms array
        let selectedSymptoms: [SelectedSymptom] = []

        // When/Then: Should throw error
        do {
            _ = try await SymptomEntryService.createEntries(
                selectedSymptoms: selectedSymptoms,
                note: "",
                timestamp: Date(),
                includeLocation: false,
                healthKit: mockHealthKit,
                location: mockLocation,
                context: testStack.context
            )
            XCTFail("Should have thrown error")
        } catch SymptomEntryService.ServiceError.noSymptomsSelected {
            // Expected error
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testTaskCancellationTriggersRollback() async throws {
        // Given: Symptom to save
        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create task and cancel it immediately
        let task = Task {
            try await SymptomEntryService.createEntries(
                selectedSymptoms: [selectedSymptom],
                note: "Should be cancelled",
                timestamp: Date(),
                includeLocation: false,
                healthKit: mockHealthKit,
                location: mockLocation,
                context: testStack.context
            )
        }

        task.cancel()

        // Wait briefly
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: No entries should be saved
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        let saved = try testStack.context.fetch(fetchRequest)
        XCTAssertEqual(saved.count, 0)

        // Context should have no changes
        XCTAssertFalse(testStack.context.hasChanges)
    }

    // MARK: - Edge Cases

    func testSaveWithVeryLongNote() async throws {
        // Given: Symptom with very long note
        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)
        let longNote = String(repeating: "This is a long note. ", count: 100) // ~2000 chars

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: longNote,
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Note should be saved (possibly truncated by Core Data constraints)
        XCTAssertNotNil(entries[0].note)
    }

    func testBackdatedEntryInPast() async throws {
        // Given: Symptom backdated to yesterday
        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)
        let yesterday = Date().addingTimeInterval(-24 * 3600)

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: yesterday,
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Should accept past dates
        XCTAssertEqual(entries[0].backdatedAt, yesterday)
    }

    func testPartialHealthKitData() async throws {
        // Given: Mock HealthKit with only some metrics
        mockHealthKit.mockHRV = 45.2
        mockHealthKit.mockSleepHours = 7.5
        // Other metrics are nil

        let symptomType = try testStack.context.fetch(SymptomType.fetchRequest()).first!
        let selectedSymptom = SelectedSymptom(symptomType: symptomType, severity: 3)

        // When: Create entry
        let entries = try await SymptomEntryService.createEntries(
            selectedSymptoms: [selectedSymptom],
            note: "",
            timestamp: Date(),
            includeLocation: false,
            healthKit: mockHealthKit,
            location: mockLocation,
            context: testStack.context
        )

        // Then: Should save with partial data
        let entry = entries[0]
        XCTAssertEqual(entry.hkHRV?.doubleValue, 45.2)
        XCTAssertNil(entry.hkRestingHR)
        XCTAssertEqual(entry.hkSleepHours?.doubleValue, 7.5)
        XCTAssertNil(entry.hkWorkoutMinutes)
    }
}
