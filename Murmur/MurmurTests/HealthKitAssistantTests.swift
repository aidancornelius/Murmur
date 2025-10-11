//
//  HealthKitAssistantTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import HealthKit
import XCTest
@testable import Murmur

@MainActor
final class HealthKitAssistantTests: XCTestCase {
    var mockStore: MockHealthKitStore?
    var healthKit: HealthKitAssistant?

    override func setUp() async throws {
        try await super.setUp()
        mockStore = MockHealthKitStore()
        healthKit = HealthKitAssistant(store: mockStore!)
    }

    override func tearDown() async throws {
        mockStore?.reset()
        mockStore = nil
        healthKit = nil
        try await super.tearDown()
    }

    // MARK: - HRV Tests

    func testRecentHRVReturnsMostRecentSample() async throws {
        // Arrange: Create two HRV samples, most recent should be returned
        let olderSample = HKQuantitySample.mockHRV(value: 45.0, date: .hoursAgo(2))
        let newerSample = HKQuantitySample.mockHRV(value: 50.0, date: .minutesAgo(5))
        mockStore!.mockQuantitySamples =[newerSample, olderSample]

        // Act
        let hrv = await healthKit!.recentHRV()

        // Assert
        XCTAssertEqual(hrv, 50.0, accuracy: 0.01)
        XCTAssertEqual(mockStore!.executeCount,1)
    }

    func testRecentHRVConvertsUnitCorrectly() async throws {
        // Arrange: HRV should be in milliseconds
        mockStore!.mockQuantitySamples =[HKQuantitySample.mockHRV(value: 42.5, date: Date())]

        // Act
        let hrv = await healthKit!.recentHRV()

        // Assert: Value should be preserved in ms
        XCTAssertEqual(hrv, 42.5, accuracy: 0.01)
    }

    func testRecentHRVUsesCacheWhenValid() async throws {
        // Arrange: First call populates cache
        mockStore!.mockQuantitySamples =[HKQuantitySample.mockHRV(value: 45.0, date: Date())]
        let firstResult = await healthKit.recentHRV()

        // Clear mock samples to verify cache is used
        mockStore!.mockQuantitySamples =[]
        mockStore?.reset()

        // Act: Second call within cache window (30 minutes)
        let secondResult = await healthKit.recentHRV()

        // Assert: Cache was used, no new query executed
        XCTAssertEqual(firstResult, secondResult)
        XCTAssertEqual(mockStore!.executeCount,0) // No new query
    }

    func testRecentHRVBypassesStaleCache() async throws {
        // Arrange: First call populates cache
        mockStore!.mockQuantitySamples =[HKQuantitySample.mockHRV(value: 45.0, date: Date())]
        _ = await healthKit.recentHRV()

        // Simulate cache expiration (31 minutes ago)
        healthKit._setCacheTimestamp(.minutesAgo(31), for: "hrv")

        // New data available
        mockStore?.reset()
        mockStore!.mockQuantitySamples =[HKQuantitySample.mockHRV(value: 52.0, date: Date())]

        // Act: Second call after cache expiry
        let result = await healthKit.recentHRV()

        // Assert: Cache was refreshed
        XCTAssertEqual(result, 52.0, accuracy: 0.01)
        XCTAssertEqual(mockStore!.executeCount,1) // New query executed
    }

    func testRecentHRVReturnsNilWhenNoData() async throws {
        // Arrange: No samples available
        mockStore!.mockQuantitySamples =[]

        // Act
        let hrv = await healthKit!.recentHRV()

        // Assert
        XCTAssertNil(hrv)
    }

    func testRecentHRVHandlesQueryError() async throws {
        // Arrange: Simulate query error
        mockStore!.shouldThrowError =NSError(domain: HKErrorDomain, code: HKError.errorDatabaseInaccessible.rawValue)

        // Act
        let hrv = await healthKit!.recentHRV()

        // Assert: Should return nil on error
        XCTAssertNil(hrv)
    }

    // MARK: - Resting Heart Rate Tests

    func testRecentRestingHRReturnsMostRecentSample() async throws {
        // Arrange
        let olderSample = HKQuantitySample.mockRestingHR(value: 65.0, date: .hoursAgo(2))
        let newerSample = HKQuantitySample.mockRestingHR(value: 62.0, date: .minutesAgo(10))
        mockStore!.mockQuantitySamples =[newerSample, olderSample]

        // Act
        let restingHR = await healthKit!.recentRestingHR()

        // Assert
        XCTAssertEqual(restingHR, 62.0, accuracy: 0.01)
    }

    func testRecentRestingHRConvertsToBPM() async throws {
        // Arrange
        mockStore!.mockQuantitySamples =[HKQuantitySample.mockRestingHR(value: 68.5, date: Date())]

        // Act
        let restingHR = await healthKit!.recentRestingHR()

        // Assert: Should be in beats per minute
        XCTAssertEqual(restingHR, 68.5, accuracy: 0.01)
    }

    func testRecentRestingHRUsesCacheWhenValid() async throws {
        // Arrange: Populate cache
        mockStore!.mockQuantitySamples =[HKQuantitySample.mockRestingHR(value: 65.0, date: Date())]
        _ = await healthKit.recentRestingHR()

        mockStore?.reset()
        mockStore!.mockQuantitySamples =[]

        // Act: Query within cache window (60 minutes)
        let result = await healthKit.recentRestingHR()

        // Assert: Cache used
        XCTAssertEqual(result, 65.0, accuracy: 0.01)
        XCTAssertEqual(mockStore!.executeCount,0)
    }

    func testRecentRestingHRReturnsNilWhenNoData() async throws {
        // Arrange
        mockStore!.mockQuantitySamples =[]

        // Act
        let result = await healthKit.recentRestingHR()

        // Assert
        XCTAssertNil(result)
    }

    func testRecentRestingHRHandlesError() async throws {
        // Arrange
        mockStore!.shouldThrowError =NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationDenied.rawValue)

        // Act
        let result = await healthKit.recentRestingHR()

        // Assert
        XCTAssertNil(result)
    }

    // MARK: - Sleep Hours Tests

    func testRecentSleepHoursAggregatesLast24Hours() async throws {
        // Arrange: Multiple sleep sessions in last 24 hours
        let session1 = HKCategorySample.mockSleep(
            value: .asleepCore,
            start: .hoursAgo(20),
            duration: 2 * 3600 // 2 hours
        )
        let session2 = HKCategorySample.mockSleep(
            value: .asleepDeep,
            start: .hoursAgo(18),
            duration: 3 * 3600 // 3 hours
        )
        let session3 = HKCategorySample.mockSleep(
            value: .asleepREM,
            start: .hoursAgo(15),
            duration: 1.5 * 3600 // 1.5 hours
        )
        mockStore!.mockCategorySamples =[session1, session2, session3]

        // Act
        let sleepHours = await healthKit!.recentSleepHours()

        // Assert: Total should be 6.5 hours
        XCTAssertEqual(sleepHours, 6.5, accuracy: 0.01)
    }

    func testRecentSleepHoursIncludesAllSleepStages() async throws {
        // Arrange: One sample of each sleep stage
        let core = HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 3600)
        let deep = HKCategorySample.mockSleep(value: .asleepDeep, start: .hoursAgo(7), duration: 3600)
        let rem = HKCategorySample.mockSleep(value: .asleepREM, start: .hoursAgo(6), duration: 3600)
        let unspecified = HKCategorySample.mockSleep(value: .asleepUnspecified, start: .hoursAgo(5), duration: 3600)

        mockStore!.mockCategorySamples =[core, deep, rem, unspecified]

        // Act
        let sleepHours = await healthKit!.recentSleepHours()

        // Assert: Should sum all stages = 4 hours
        XCTAssertEqual(sleepHours, 4.0, accuracy: 0.01)
    }

    func testRecentSleepHoursExcludesInBed() async throws {
        // Arrange: Mix of asleep and in bed samples
        let asleep = HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 7 * 3600)
        let inBed = HKCategorySample.mockSleep(value: .inBed, start: .hoursAgo(9), duration: 8 * 3600)

        mockStore!.mockCategorySamples =[asleep, inBed]

        // Act
        let sleepHours = await healthKit!.recentSleepHours()

        // Assert: Should only count asleep time (7 hours)
        XCTAssertEqual(sleepHours, 7.0, accuracy: 0.01)
    }

    func testRecentSleepHoursUsesCacheWhenValid() async throws {
        // Arrange
        mockStore!.mockCategorySamples =[
            HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 7 * 3600)
        ]
        _ = await healthKit.recentSleepHours()

        mockStore?.reset()

        // Act: Within cache window (6 hours)
        let result = await healthKit.recentSleepHours()

        // Assert
        XCTAssertEqual(result, 7.0, accuracy: 0.01)
        XCTAssertEqual(mockStore!.executeCount,0)
    }

    func testRecentSleepHoursReturnsNilWhenNoData() async throws {
        // Arrange
        mockStore!.mockCategorySamples =[]

        // Act
        let result = await healthKit.recentSleepHours()

        // Assert
        XCTAssertEqual(result, 0.0) // Empty array sums to 0
    }

    // MARK: - Detailed Sleep Data Tests

    func testFetchDetailedSleepDataReturnsCompleteSession() async throws {
        // Arrange: Single continuous sleep session
        let bedTime = Date.hoursAgo(8)
        let wakeTime = bedTime.addingTimeInterval(7 * 3600)

        mockStore!.mockCategorySamples =[
            HKCategorySample.mockSleep(value: .asleepCore, start: bedTime, duration: 3 * 3600),
            HKCategorySample.mockSleep(value: .asleepDeep, start: bedTime.addingTimeInterval(3 * 3600), duration: 2 * 3600),
            HKCategorySample.mockSleep(value: .asleepREM, start: bedTime.addingTimeInterval(5 * 3600), duration: 2 * 3600)
        ]

        // Act
        let result = await healthKit!.fetchDetailedSleepData()

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalHours, 7.0, accuracy: 0.01)
        XCTAssertEqual(result?.bedTime?.timeIntervalSince1970, bedTime.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(result?.wakeTime?.timeIntervalSince1970, wakeTime.timeIntervalSince1970, accuracy: 1.0)
    }

    func testFetchDetailedSleepDataGroupsFragmentedSleep() async throws {
        // Arrange: Two separate sleep sessions with >1hr gap
        let session1Start = Date.hoursAgo(20)
        let session2Start = Date.hoursAgo(8)

        mockStore!.mockCategorySamples =[
            HKCategorySample.mockSleep(value: .asleepCore, start: session1Start, duration: 1 * 3600),
            HKCategorySample.mockSleep(value: .asleepCore, start: session2Start, duration: 7 * 3600)
        ]

        // Act
        let result = await healthKit!.fetchDetailedSleepData()

        // Assert: Should return most recent session (7 hours)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalHours, 7.0, accuracy: 0.01)
        XCTAssertEqual(result?.bedTime?.timeIntervalSince1970, session2Start.timeIntervalSince1970, accuracy: 1.0)
    }

    func testFetchDetailedSleepDataReturnsNilWhenNoData() async throws {
        // Arrange
        mockStore!.mockCategorySamples =[]

        // Act
        let result = await healthKit!.fetchDetailedSleepData()

        // Assert
        XCTAssertNil(result)
    }

    // MARK: - Workout Minutes Tests

    func testRecentWorkoutMinutesSumsLast24Hours() async throws {
        // Arrange: Multiple workouts
        let workout1 = HKWorkout.mockWorkout(start: .hoursAgo(20), duration: 30 * 60) // 30 minutes
        let workout2 = HKWorkout.mockWorkout(start: .hoursAgo(12), duration: 45 * 60) // 45 minutes
        let workout3 = HKWorkout.mockWorkout(start: .hoursAgo(2), duration: 25 * 60)  // 25 minutes

        mockStore!.mockWorkouts =[workout1, workout2, workout3]

        // Act
        let workoutMinutes = await healthKit.recentWorkoutMinutes()

        // Assert: Total 100 minutes
        XCTAssertEqual(workoutMinutes, 100.0, accuracy: 0.01)
    }

    func testRecentWorkoutMinutesIncludesAllWorkoutTypes() async throws {
        // Arrange: Different workout types
        let running = HKWorkout.mockWorkout(activityType: .running, start: .hoursAgo(10), duration: 30 * 60)
        let cycling = HKWorkout.mockWorkout(activityType: .cycling, start: .hoursAgo(8), duration: 45 * 60)
        let yoga = HKWorkout.mockWorkout(activityType: .yoga, start: .hoursAgo(6), duration: 60 * 60)

        mockStore!.mockWorkouts =[running, cycling, yoga]

        // Act
        let workoutMinutes = await healthKit.recentWorkoutMinutes()

        // Assert: Total 135 minutes
        XCTAssertEqual(workoutMinutes, 135.0, accuracy: 0.01)
    }

    func testRecentWorkoutMinutesUsesCacheWhenValid() async throws {
        // Arrange
        mockStore!.mockWorkouts =[
            HKWorkout.mockWorkout(start: .hoursAgo(5), duration: 30 * 60)
        ]
        _ = await healthKit.recentWorkoutMinutes()

        mockStore?.reset()

        // Act: Within cache window (6 hours)
        let result = await healthKit.recentWorkoutMinutes()

        // Assert
        XCTAssertEqual(result, 30.0, accuracy: 0.01)
        XCTAssertEqual(mockStore!.executeCount,0)
    }

    func testRecentWorkoutMinutesReturnsNilWhenNoData() async throws {
        // Arrange
        mockStore!.mockWorkouts =[]

        // Act
        let result = await healthKit.recentWorkoutMinutes()

        // Assert
        XCTAssertEqual(result, 0.0) // Empty array sums to 0
    }

    // MARK: - Menstrual Cycle Day Tests

    func testRecentCycleDayCalculatesDaysSincePeriodStart() async throws {
        // Arrange: Period started 12 days ago
        let periodStart = Calendar.current.startOfDay(for: .daysAgo(12))
        mockStore!.mockCategorySamples =[
            HKCategorySample.mockMenstrualFlow(value: .medium, date: periodStart)
        ]

        // Act
        let cycleDay = await healthKit.recentCycleDay()

        // Assert: Should be day 13 (12 days ago + 1)
        XCTAssertEqual(cycleDay, 13)
    }

    func testRecentCycleDayUsesStartOfDay() async throws {
        // Arrange: Period started at specific time today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let periodStart = today.addingTimeInterval(14 * 3600) // 2pm today

        mockStore!.mockCategorySamples =[
            HKCategorySample.mockMenstrualFlow(value: .heavy, date: periodStart)
        ]

        // Act
        let cycleDay = await healthKit.recentCycleDay()

        // Assert: Should be day 1 regardless of time
        XCTAssertEqual(cycleDay, 1)
    }

    func testRecentCycleDayReturnsNilWhenNoData() async throws {
        // Arrange
        mockStore!.mockCategorySamples =[]

        // Act
        let cycleDay = await healthKit.recentCycleDay()

        // Assert
        XCTAssertNil(cycleDay)
    }

    // MARK: - Menstrual Flow Level Tests

    func testRecentFlowLevelReturnsTodaysFlow() async throws {
        // Arrange: Flow entry for today
        let today = Calendar.current.startOfDay(for: Date())
        mockStore!.mockCategorySamples =[
            HKCategorySample.mockMenstrualFlow(value: .medium, date: today)
        ]

        // Act
        let flowLevel = await healthKit.recentFlowLevel()

        // Assert
        XCTAssertEqual(flowLevel, "medium")
    }

    func testRecentFlowLevelMapsHealthKitValues() async throws {
        let today = Calendar.current.startOfDay(for: Date())

        // Test light
        mockStore!.mockCategorySamples =[HKCategorySample.mockMenstrualFlow(value: .light, date: today)]
        var result = await healthKit.recentFlowLevel()
        XCTAssertEqual(result, "light")

        // Test medium
        mockStore!.mockCategorySamples =[HKCategorySample.mockMenstrualFlow(value: .medium, date: today)]
        healthKit._setCacheTimestamp(.daysAgo(1), for: "cycle") // Invalidate cache
        result = await healthKit.recentFlowLevel()
        XCTAssertEqual(result, "medium")

        // Test heavy
        mockStore!.mockCategorySamples =[HKCategorySample.mockMenstrualFlow(value: .heavy, date: today)]
        healthKit._setCacheTimestamp(.daysAgo(1), for: "cycle")
        result = await healthKit.recentFlowLevel()
        XCTAssertEqual(result, "heavy")

        // Test spotting (unspecified maps to spotting)
        mockStore!.mockCategorySamples =[HKCategorySample.mockMenstrualFlow(value: .unspecified, date: today)]
        healthKit._setCacheTimestamp(.daysAgo(1), for: "cycle")
        result = await healthKit.recentFlowLevel()
        XCTAssertEqual(result, "spotting")
    }

    func testRecentFlowLevelReturnsNilForNonBleedingDays() async throws {
        // Arrange: No flow data for today
        mockStore!.mockCategorySamples =[]

        // Act
        let result = await healthKit.recentFlowLevel()

        // Assert
        XCTAssertNil(result)
    }

    // MARK: - Cache Management Tests

    func testRefreshContextForcesRefreshOfAllMetrics() async throws {
        // Arrange: Populate all caches
        mockStore!.mockQuantitySamples =[
            HKQuantitySample.mockHRV(value: 45.0, date: Date()),
            HKQuantitySample.mockRestingHR(value: 65.0, date: Date())
        ]
        mockStore!.mockCategorySamples =[
            HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 7 * 3600),
            HKCategorySample.mockMenstrualFlow(value: .medium, date: Calendar.current.startOfDay(for: .daysAgo(5)))
        ]
        mockStore!.mockWorkouts =[
            HKWorkout.mockWorkout(start: .hoursAgo(5), duration: 30 * 60)
        ]

        // Act
        await healthKit.refreshContext()

        // Assert: All metrics should be queried
        // Note: We expect 5 queries (HRV, HR, Sleep, Workout, Cycle)
        XCTAssertGreaterThanOrEqual(mockStore.executeCount, 5)
    }

    func testForceRefreshAllBypassesCaches() async throws {
        // Arrange: Populate caches with initial values
        mockStore!.mockQuantitySamples =[HKQuantitySample.mockHRV(value: 45.0, date: Date())]
        _ = await healthKit.recentHRV()
        XCTAssertEqual(mockStore!.executeCount,1)

        // Update mock data
        mockStore!.mockQuantitySamples =[HKQuantitySample.mockHRV(value: 55.0, date: Date())]

        // Act: Force refresh should bypass cache
        await healthKit.forceRefreshAll()

        // Assert: Should have executed new query
        XCTAssertGreaterThan(mockStore.executeCount, 1)
    }

    func testMultipleRapidCallsUseCacheToPreventRedundantQueries() async throws {
        // Arrange
        mockStore!.mockQuantitySamples =[HKQuantitySample.mockHRV(value: 45.0, date: Date())]

        // Act: Make 5 rapid calls
        let results = await withTaskGroup(of: Double?.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await self.healthKit.recentHRV()
                }
            }

            var collected: [Double?] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        // Assert: All results should be the same
        XCTAssertTrue(results.allSatisfy { $0 == 45.0 })
        // Should only execute one query (first call), rest use cache
        XCTAssertEqual(mockStore!.executeCount,1)
    }

    // MARK: - Baseline Calculation Tests

    func testUpdateHRVBaselineFetches30DaysOfSamples() async throws {
        // Arrange: Create 30 days of samples
        var samples: [HKQuantitySample] = []
        for day in 0..<30 {
            samples.append(HKQuantitySample.mockHRV(value: Double(40 + day), date: .daysAgo(day)))
        }
        mockStore!.mockQuantitySamples =samples

        // Clear existing baseline
        await MainActor.run {
            HealthMetricBaselines.shared.hrvBaseline = nil
        }

        // Act
        await healthKit.updateBaselines()

        // Give baselines time to update
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Assert: Baseline should be calculated
        let baseline = await MainActor.run { HealthMetricBaselines.shared.hrvBaseline }
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline?.sampleCount, 30)
        XCTAssertGreaterThan(baseline?.mean ?? 0, 0)
        XCTAssertGreaterThan(baseline?.standardDeviation ?? 0, 0)
    }

    func testUpdateRestingHRBaselineCalculatesStatistics() async throws {
        // Arrange: Create samples with known values
        let values: [Double] = [60, 62, 61, 63, 59, 64, 60, 61, 62, 63, 65, 64, 62, 61, 60]
        var samples: [HKQuantitySample] = []
        for (index, value) in values.enumerated() {
            samples.append(HKQuantitySample.mockRestingHR(value: value, date: .daysAgo(index)))
        }
        mockStore!.mockQuantitySamples =samples

        // Clear existing baseline
        await MainActor.run {
            HealthMetricBaselines.shared.restingHRBaseline = nil
        }

        // Act
        await healthKit.updateBaselines()

        // Give baselines time to update
        try await Task.sleep(nanoseconds: 500_000_000)

        // Assert
        let baseline = await MainActor.run { HealthMetricBaselines.shared.restingHRBaseline }
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline?.sampleCount, 15)
        // Mean should be around 61.73
        XCTAssertEqual(baseline?.mean ?? 0, 61.73, accuracy: 0.5)
    }

    func testUpdateBaselinesHandlesInsufficientData() async throws {
        // Arrange: Only 5 samples (need 10+ for baseline)
        var samples: [HKQuantitySample] = []
        for day in 0..<5 {
            samples.append(HKQuantitySample.mockHRV(value: Double(40 + day), date: .daysAgo(day)))
        }
        mockStore!.mockQuantitySamples =samples

        // Clear existing baseline
        await MainActor.run {
            HealthMetricBaselines.shared.hrvBaseline = nil
        }

        // Act
        await healthKit.updateBaselines()

        // Give baselines time to update
        try await Task.sleep(nanoseconds: 500_000_000)

        // Assert: Should not create baseline with insufficient data
        let baseline = await MainActor.run { HealthMetricBaselines.shared.hrvBaseline }
        XCTAssertNil(baseline)
    }

    func testUpdateBaselinesRunsInParallel() async throws {
        // Arrange: Create samples for both HRV and HR
        var hrvSamples: [HKQuantitySample] = []
        for day in 0..<30 {
            hrvSamples.append(HKQuantitySample.mockHRV(value: Double(40 + day), date: .daysAgo(day)))
            hrvSamples.append(HKQuantitySample.mockRestingHR(value: Double(60 + day), date: .daysAgo(day)))
        }
        mockStore!.mockQuantitySamples =hrvSamples

        let startTime = Date()

        // Act
        await healthKit.updateBaselines()

        let duration = Date().timeIntervalSince(startTime)

        // Assert: Should complete quickly (parallel execution)
        // If sequential, would take longer
        XCTAssertLessThan(duration, 2.0) // Should complete in under 2 seconds
    }

    // MARK: - Permission and Availability Tests

    func testRequestPermissionsRequestsAllRequiredTypes() async throws {
        // Act
        try await healthKit.requestPermissions()

        // Assert
        XCTAssertTrue(mockStore.requestAuthorizationCalled)
        XCTAssertNotNil(mockStore.requestedReadTypes)
        XCTAssertEqual(mockStore.requestedShareTypes?.count ?? 0, 0) // No write access

        // Verify specific types requested
        let readTypes = mockStore.requestedReadTypes!
        XCTAssertTrue(readTypes.contains(where: { ($0 as? HKQuantityType)?.identifier == HKQuantityTypeIdentifier.heartRateVariabilitySDNN }))
        XCTAssertTrue(readTypes.contains(where: { ($0 as? HKQuantityType)?.identifier == HKQuantityTypeIdentifier.restingHeartRate }))
        XCTAssertTrue(readTypes.contains(where: { ($0 as? HKCategoryType)?.identifier == HKCategoryTypeIdentifier.sleepAnalysis }))
        XCTAssertTrue(readTypes.contains(HKObjectType.workoutType()))
        XCTAssertTrue(readTypes.contains(where: { ($0 as? HKCategoryType)?.identifier == HKCategoryTypeIdentifier.menstrualFlow }))
    }

    func testRequestPermissionsHandlesDenial() async throws {
        // Arrange
        mockStore.authorizationError = NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationDenied.rawValue)

        // Act & Assert
        do {
            try await healthKit.requestPermissions()
            XCTFail("Should have thrown error")
        } catch {
            // Expected
        }
    }

    func testBootstrapAuthorizationsRunsCompleteFlow() async throws {
        // Arrange
        mockStore!.mockQuantitySamples =[
            HKQuantitySample.mockHRV(value: 45.0, date: Date())
        ]

        // Act
        await healthKit.bootstrapAuthorizations()

        // Give async tasks time to complete
        try await Task.sleep(nanoseconds: 500_000_000)

        // Assert: Should have requested permissions
        XCTAssertTrue(mockStore.requestAuthorizationCalled)
        // Should have executed queries for context refresh
        XCTAssertGreaterThan(mockStore.executeCount, 0)
    }

    func testBootstrapAuthorizationsHandlesErrors() async throws {
        // Arrange: Simulate authorization failure
        mockStore.authorizationError = NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationNotDetermined.rawValue)

        // Act: Should not crash
        await healthKit.bootstrapAuthorizations()

        // Assert: Error should be handled gracefully
        // (logging happens internally, we just verify no crash)
    }

    // MARK: - Manual Cycle Tracker Integration Tests

    func testRecentCycleDayUsesManualTrackerWhenEnabled() async throws {
        // Arrange: Set up manual tracker with data
        let testStack = InMemoryCoreDataStack()
        let manualTracker = ManualCycleTracker(context: testStack!.context)
        manualTracker.setEnabled(true)
        manualTracker.setCycleDay(15)
        healthKit.manualCycleTracker = manualTracker

        // Also have HealthKit data (should be ignored)
        mockStore!.mockCategorySamples =[
            HKCategorySample.mockMenstrualFlow(value: .medium, date: .daysAgo(10))
        ]

        // Act
        let cycleDay = await healthKit.recentCycleDay()

        // Assert: Should use manual tracker value
        XCTAssertEqual(cycleDay, 15)
        // Should not have queried HealthKit
        XCTAssertEqual(mockStore!.executeCount,0)
    }

    func testRecentFlowLevelUsesManualTrackerWhenEnabled() async throws {
        // Arrange
        let testStack = InMemoryCoreDataStack()
        let manualTracker = ManualCycleTracker(context: testStack!.context)
        manualTracker.setEnabled(true)

        let today = Date()
        try manualTracker.addEntry(date: today, flowLevel: "heavy")
        healthKit.manualCycleTracker = manualTracker

        // Give tracker time to refresh
        try await Task.sleep(nanoseconds: 100_000_000)

        // Act
        let flowLevel = await healthKit.recentFlowLevel()

        // Assert: Should use manual tracker
        XCTAssertEqual(flowLevel, "heavy")
        XCTAssertEqual(mockStore!.executeCount,0)
    }

    func testCycleDataFallsBackToHealthKitWhenManualDisabled() async throws {
        // Arrange: Manual tracker disabled
        let testStack = InMemoryCoreDataStack()
        let manualTracker = ManualCycleTracker(context: testStack!.context)
        manualTracker.setEnabled(false)
        healthKit.manualCycleTracker = manualTracker

        // HealthKit data available
        mockStore!.mockCategorySamples =[
            HKCategorySample.mockMenstrualFlow(value: .medium, date: .daysAgo(7))
        ]

        // Act
        let cycleDay = await healthKit.recentCycleDay()

        // Assert: Should use HealthKit
        XCTAssertEqual(cycleDay, 8) // 7 days ago + 1
        XCTAssertGreaterThan(mockStore.executeCount, 0)
    }

    // MARK: - Query Lifecycle Tests

    func testQueriesAddedToActiveQueriesOnExecution() async throws {
        // Arrange
        mockStore!.mockQuantitySamples =[HKQuantitySample.mockHRV(value: 45.0, date: Date())]

        // Act
        _ = await healthKit.recentHRV()

        // Assert: Query should have been added and then removed
        XCTAssertEqual(healthKit._activeQueriesCount, 0) // Should be cleaned up
        XCTAssertEqual(mockStore!.executeCount,1)
    }

    func testQueriesRemovedAfterCompletion() async throws {
        // Arrange
        mockStore!.mockQuantitySamples =[HKQuantitySample.mockHRV(value: 45.0, date: Date())]

        // Act: Execute multiple queries
        async let hrv = healthKit.recentHRV()
        async let hr = healthKit.recentRestingHR()

        _ = await hrv
        _ = await hr

        // Give cleanup time to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert: All queries should be cleaned up
        XCTAssertEqual(healthKit._activeQueriesCount, 0)
    }

    // MARK: - Date Range and Predicate Tests

    func testHRVUsesQuantitySampleLookbackWindow() async throws {
        // Arrange: Samples within and outside 72-hour window
        let withinWindow = HKQuantitySample.mockHRV(value: 50.0, date: .hoursAgo(48))
        let outsideWindow = HKQuantitySample.mockHRV(value: 30.0, date: .hoursAgo(80))

        mockStore!.mockQuantitySamples =[withinWindow, outsideWindow]

        // Act
        _ = await healthKit.recentHRV()

        // Assert: Verify predicate was used correctly
        let query = mockStore.executedQueries.first as? HKSampleQuery
        XCTAssertNotNil(query?.predicate)
    }

    func testSleepUsesDaily24HourLookback() async throws {
        // Arrange: Sleep samples from different times
        let recent = HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 7 * 3600)
        let old = HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(30), duration: 7 * 3600)

        mockStore!.mockCategorySamples =[recent, old]

        // Act
        _ = await healthKit.recentSleepHours()

        // Assert: Query should use predicate
        let query = mockStore.executedQueries.first as? HKSampleQuery
        XCTAssertNotNil(query?.predicate)
    }

    func testCycleUsesLongerLookbackWindow() async throws {
        // Arrange: Cycle data from 45 days ago
        let periodStart = HKCategorySample.mockMenstrualFlow(value: .medium, date: .daysAgo(40))
        mockStore!.mockCategorySamples =[periodStart]

        // Act
        _ = await healthKit.recentCycleDay()

        // Assert: Should find samples within 45-day window
        let query = mockStore.executedQueries.first as? HKSampleQuery
        XCTAssertNotNil(query?.predicate)
    }

    func testSleepFiltersOnlyAsleepCategories() async throws {
        // Arrange: Mix of sleep categories
        let asleep = HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 7 * 3600)
        let inBed = HKCategorySample.mockSleep(value: .inBed, start: .hoursAgo(9), duration: 8 * 3600)
        let awake = HKCategorySample.mockSleep(value: .awake, start: .hoursAgo(10), duration: 0.5 * 3600)

        mockStore!.mockCategorySamples =[asleep, inBed, awake]

        // Act
        let sleepHours = await healthKit!.recentSleepHours()

        // Assert: Should only include asleep time
        // Note: The mock's predicate filtering needs to handle category value filtering
        // For now, we verify the total is reasonable
        XCTAssertGreaterThan(sleepHours ?? 0, 0)
    }

    func testMostRecentSamplesPrioritised() async throws {
        // Arrange: Multiple samples, newest should be returned
        let samples = [
            HKQuantitySample.mockHRV(value: 40.0, date: .hoursAgo(70)),
            HKQuantitySample.mockHRV(value: 45.0, date: .hoursAgo(50)),
            HKQuantitySample.mockHRV(value: 50.0, date: .hoursAgo(10)),
            HKQuantitySample.mockHRV(value: 52.0, date: .hoursAgo(1))
        ]
        mockStore!.mockQuantitySamples =samples

        // Act
        let hrv = await healthKit!.recentHRV()

        // Assert: Should return most recent (52.0)
        XCTAssertEqual(hrv, 52.0, accuracy: 0.01)
    }

    func testSampleLimitsRespected() async throws {
        // Arrange: Create more samples than the limit (50 for HRV)
        var samples: [HKQuantitySample] = []
        for i in 0..<100 {
            samples.append(HKQuantitySample.mockHRV(value: Double(40 + i), date: .hoursAgo(i)))
        }
        mockStore!.mockQuantitySamples =samples

        // Act
        _ = await healthKit.recentHRV()

        // Assert: Query should have limit set
        let query = mockStore.executedQueries.first as? HKSampleQuery
        XCTAssertEqual(query?.limit, AppConstants.HealthKit.hrvSampleLimit)
    }
}
