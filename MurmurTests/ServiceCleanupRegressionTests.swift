//
//  ServiceCleanupRegressionTests.swift
//  MurmurTests
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//  Regression tests to verify service cleanup works correctly
//

import XCTest
import CoreData
@testable import Murmur

@MainActor
final class ServiceCleanupRegressionTests: XCTestCase {

    // MARK: - HealthKitAssistant Cleanup Tests

    func testHealthKitAssistantCleanup() async throws {
        // Given
        let healthKit = HealthKitAssistant()

        // Simulate some usage that would create state
        await healthKit.refreshContext()

        // When
        healthKit.cleanup()

        // Then - Verify published state is cleared
        XCTAssertNil(healthKit.latestHRV)
        XCTAssertNil(healthKit.latestRestingHR)
        XCTAssertNil(healthKit.latestSleepHours)
        XCTAssertNil(healthKit.latestWorkoutMinutes)
        XCTAssertNil(healthKit.latestCycleDay)
        XCTAssertNil(healthKit.latestFlowLevel)
    }

    // MARK: - CoreDataStack Cleanup Tests

    func testCoreDataStackSavesPendingChangesOnCleanup() throws {
        // Given
        let stack = CoreDataStack.shared
        let context = stack.context

        // Create a test symptom type
        let symptomType = SymptomType(context: context)
        symptomType.id = UUID()
        symptomType.name = "Test Symptom"
        symptomType.category = "physical"

        XCTAssertTrue(context.hasChanges)

        // When
        stack.cleanup()

        // Then - Changes should be saved
        XCTAssertFalse(context.hasChanges)

        // Cleanup
        context.delete(symptomType)
        try? context.save()
    }

    // MARK: - TimelineDataController Cleanup Tests

    func testTimelineDataControllerClearsDelegatesOnCleanup() async throws {
        // Given
        let context = CoreDataStack.shared.context
        let controller = TimelineDataController(context: context)

        // When
        controller.cleanup()

        // Then - Verify state is cleared
        XCTAssertTrue(controller.daySections.isEmpty)
    }

    // MARK: - ManualCycleTracker Cleanup Tests

    func testManualCycleTrackerClearsStateOnCleanup() async throws {
        // Given
        let context = CoreDataStack.shared.context
        let tracker = ManualCycleTracker(context: context)

        // Manually set some state
        tracker.setCycleDay(15)

        // When
        tracker.cleanup()

        // Then - Verify state is cleared
        XCTAssertNil(tracker.latestCycleDay)
        XCTAssertNil(tracker.latestFlowLevel)
    }

    // MARK: - CalendarAssistant Cleanup Tests

    func testCalendarAssistantClearsEventsOnCleanup() async throws {
        // Given
        let calendar = CalendarAssistant()

        // Simulate having some events (would normally fetch from calendar)
        // For testing, just verify cleanup doesn't crash

        // When
        calendar.cleanup()

        // Then - Verify event arrays are cleared
        XCTAssertTrue(calendar.upcomingEvents.isEmpty)
        XCTAssertTrue(calendar.recentEvents.isEmpty)
    }

    // MARK: - StoreManager Cleanup Tests

    func testStoreManagerCancelsTasksOnCleanup() async throws {
        // Given
        let storeManager = StoreManager()

        // Wait a moment for initialisation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // When
        await storeManager.cleanup()

        // Then - Verify state is cleared
        XCTAssertTrue(storeManager.products.isEmpty)
        XCTAssertEqual(storeManager.purchaseState, .idle)
    }

    // MARK: - ResourceManager Integration Tests

    func testResourceManagerCleansUpAllServicesInCorrectOrder() async throws {
        // Given
        let manager = ResourceManager()

        let healthKit = HealthKitAssistant()
        let calendar = CalendarAssistant()
        let context = CoreDataStack.shared.context
        let tracker = ManualCycleTracker(context: context)

        try await manager.register(healthKit)
        try await manager.register(calendar)
        try await manager.register(tracker)
        try await manager.register(CoreDataStack.shared)

        let count = await manager.managedResourceCount
        XCTAssertEqual(count, 4)

        // When
        await manager.cleanupAll()

        // Then
        let countAfter = await manager.managedResourceCount
        XCTAssertEqual(countAfter, 0)

        // Verify services are cleaned up
        XCTAssertNil(healthKit.latestHRV)
        XCTAssertTrue(calendar.upcomingEvents.isEmpty)
        XCTAssertNil(tracker.latestCycleDay)
    }

    // MARK: - App Lifecycle Integration Tests

    func testAppDelegateRegistersServicesWithResourceManager() throws {
        // Given
        let appDelegate = MurmurAppDelegate()

        // When - Init creates ResourceManager and registers services
        // This happens in init

        // Then - Verify ResourceManager exists
        XCTAssertNotNil(appDelegate.resourceManager)

        // Note: Can't verify count because registration happens in async Task
        // but we can verify the services exist
        XCTAssertNotNil(appDelegate.healthKitAssistant)
        XCTAssertNotNil(appDelegate.calendarAssistant)
    }

    // MARK: - Memory Leak Prevention Tests

    func testWeakReferencesPreventRetainCycles() async throws {
        // Given
        let manager = ResourceManager()
        var healthKit: HealthKitAssistant? = HealthKitAssistant()

        try await manager.register(healthKit!)

        var count = await manager.managedResourceCount
        XCTAssertEqual(count, 1)

        // When - Release the service
        healthKit = nil

        // Then - Manager should not keep it alive
        await manager.pruneDeadReferences()
        count = await manager.managedResourceCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - Cleanup Idempotency Tests

    func testMultipleCleanupCallsSafe() async throws {
        // Given
        let healthKit = HealthKitAssistant()

        // When - Call cleanup multiple times
        healthKit.cleanup()
        healthKit.cleanup()
        healthKit.cleanup()

        // Then - Should not crash or cause issues
        XCTAssertNil(healthKit.latestHRV)
    }

    // MARK: - Scene Phase Integration Tests

    func testCoreDataSavesOnBackgroundTransition() throws {
        // Given
        let stack = CoreDataStack.shared
        let context = stack.context

        // Create test data
        let symptomType = SymptomType(context: context)
        symptomType.id = UUID()
        symptomType.name = "Background Test"
        symptomType.category = "test"

        XCTAssertTrue(context.hasChanges)

        // When - Simulate background transition
        stack.cleanup()

        // Then - Changes should be saved
        XCTAssertFalse(context.hasChanges)

        // Cleanup
        context.delete(symptomType)
        try? context.save()
    }
}
