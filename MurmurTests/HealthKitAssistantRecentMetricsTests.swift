//
//  HealthKitAssistantRecentMetricsTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import HealthKit
import XCTest
@testable import Murmur

@MainActor
final class HealthKitAssistantRecentMetricsTests: HealthKitAssistantTestCase {

    // MARK: - HRV Tests

    func testRecentHRVReturnsMostRecentSample() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create two HRV samples, most recent should be returned
        let olderSample = HKQuantitySample.mockHRV(value: 45.0, date: .hoursAgo(2))
        let newerSample = HKQuantitySample.mockHRV(value: 50.0, date: .minutesAgo(5))
        provider.mockQuantitySamples = [newerSample, olderSample]

        // Act
        let hrv = await assistant.recentHRV()

        // Assert
        XCTAssertEqual(hrv ?? 0, 50.0, accuracy: 0.01)
        XCTAssertEqual(provider.executeCount, 1)
    }

    func testRecentHRVConvertsUnitCorrectly() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: HRV should be in milliseconds
        provider.mockQuantitySamples = [HKQuantitySample.mockHRV(value: 42.5, date: Date())]

        // Act
        let hrv = await assistant.recentHRV()

        // Assert: Value should be preserved in ms
        XCTAssertEqual(hrv ?? 0, 42.5, accuracy: 0.01)
    }

    func testRecentHRVUsesCacheWhenValid() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: First call populates cache
        provider.mockQuantitySamples = [HKQuantitySample.mockHRV(value: 45.0, date: Date())]
        let firstResult = await assistant.recentHRV()

        // Clear mock samples to verify cache is used
        provider.mockQuantitySamples = []
        provider.reset()

        // Act: Second call within cache window (30 minutes)
        let secondResult = await assistant.recentHRV()

        // Assert: Cache was used, no new query executed
        XCTAssertEqual(firstResult, secondResult)
        XCTAssertEqual(provider.executeCount, 0) // No new query
    }

    func testRecentHRVBypassesStaleCache() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: First call populates cache
        provider.mockQuantitySamples = [HKQuantitySample.mockHRV(value: 45.0, date: Date())]
        _ = await assistant.recentHRV()

        // Simulate cache expiration (31 minutes ago)
        assistant._setCacheTimestamp(.minutesAgo(31), for: "hrv")

        // New data available
        provider.reset()
        provider.mockQuantitySamples = [HKQuantitySample.mockHRV(value: 52.0, date: Date())]

        // Act: Second call after cache expiry
        let result = await assistant.recentHRV()

        // Assert: Cache was refreshed
        XCTAssertEqual(result ?? 0, 52.0, accuracy: 0.01)
        XCTAssertEqual(provider.executeCount, 1) // New query executed
    }

    func testRecentHRVReturnsNilWhenNoData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: No samples available
        provider.mockQuantitySamples = []

        // Act
        let hrv = await assistant.recentHRV()

        // Assert
        XCTAssertNil(hrv)
    }

    // MARK: - Resting Heart Rate Tests

    func testRecentRestingHRReturnsMostRecentSample() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        let olderSample = HKQuantitySample.mockRestingHR(value: 65.0, date: .hoursAgo(2))
        let newerSample = HKQuantitySample.mockRestingHR(value: 62.0, date: .minutesAgo(10))
        provider.mockQuantitySamples = [newerSample, olderSample]

        // Act
        let restingHR = await assistant.recentRestingHR()

        // Assert
        XCTAssertEqual(restingHR ?? 0, 62.0, accuracy: 0.01)
    }

    func testRecentRestingHRConvertsToBPM() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        provider.mockQuantitySamples = [HKQuantitySample.mockRestingHR(value: 68.5, date: Date())]

        // Act
        let restingHR = await assistant.recentRestingHR()

        // Assert: Should be in beats per minute
        XCTAssertEqual(restingHR ?? 0, 68.5, accuracy: 0.01)
    }

    func testRecentRestingHRUsesCacheWhenValid() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Populate cache
        provider.mockQuantitySamples = [HKQuantitySample.mockRestingHR(value: 65.0, date: Date())]
        _ = await assistant.recentRestingHR()

        provider.reset()
        provider.mockQuantitySamples = []

        // Act: Query within cache window (60 minutes)
        let result = await assistant.recentRestingHR()

        // Assert: Cache used
        XCTAssertEqual(result ?? 0, 65.0, accuracy: 0.01)
        XCTAssertEqual(provider.executeCount, 0)
    }

    func testRecentRestingHRReturnsNilWhenNoData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        provider.mockQuantitySamples = []

        // Act
        let result = await assistant.recentRestingHR()

        // Assert
        XCTAssertNil(result)
    }

    func testRecentRestingHRHandlesError() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        provider.shouldThrowError = NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationDenied.rawValue)

        // Act
        let result = await assistant.recentRestingHR()

        // Assert
        XCTAssertNil(result)
    }

    // MARK: - Sleep Hours Tests

    func testRecentSleepHoursAggregatesLast24Hours() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

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
        provider.mockCategorySamples = [session1, session2, session3]

        // Act
        let sleepHours = await assistant.recentSleepHours()

        // Assert: Total should be 6.5 hours
        XCTAssertEqual(sleepHours ?? 0, 6.5, accuracy: 0.01)
    }

    func testRecentSleepHoursIncludesAllSleepStages() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: One sample of each sleep stage
        let core = HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 3600)
        let deep = HKCategorySample.mockSleep(value: .asleepDeep, start: .hoursAgo(7), duration: 3600)
        let rem = HKCategorySample.mockSleep(value: .asleepREM, start: .hoursAgo(6), duration: 3600)
        let unspecified = HKCategorySample.mockSleep(value: .asleepUnspecified, start: .hoursAgo(5), duration: 3600)

        provider.mockCategorySamples = [core, deep, rem, unspecified]

        // Act
        let sleepHours = await assistant.recentSleepHours()

        // Assert: Should sum all stages = 4 hours
        XCTAssertEqual(sleepHours ?? 0, 4.0, accuracy: 0.01)
    }

    func testRecentSleepHoursExcludesInBed() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Mix of asleep and in bed samples
        let asleep = HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 7 * 3600)
        let inBed = HKCategorySample.mockSleep(value: .inBed, start: .hoursAgo(9), duration: 8 * 3600)

        provider.mockCategorySamples = [asleep, inBed]

        // Act
        let sleepHours = await assistant.recentSleepHours()

        // Assert: Should only count asleep time (7 hours)
        XCTAssertEqual(sleepHours ?? 0, 7.0, accuracy: 0.01)
    }

    func testRecentSleepHoursUsesCacheWhenValid() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        provider.mockCategorySamples = [
            HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 7 * 3600)
        ]
        _ = await assistant.recentSleepHours()

        provider.reset()

        // Act: Within cache window (6 hours)
        let result = await assistant.recentSleepHours()

        // Assert
        XCTAssertEqual(result ?? 0, 7.0, accuracy: 0.01)
        XCTAssertEqual(provider.executeCount, 0)
    }

    func testRecentSleepHoursReturnsNilWhenNoData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        provider.mockCategorySamples = []

        // Act
        let result = await assistant.recentSleepHours()

        // Assert
        XCTAssertEqual(result, 0.0) // Empty array sums to 0
    }

    // MARK: - Detailed Sleep Data Tests

    func testFetchDetailedSleepDataReturnsCompleteSession() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Single continuous sleep session
        let bedTime = Date.hoursAgo(8)
        let wakeTime = bedTime.addingTimeInterval(7 * 3600)

        provider.mockCategorySamples = [
            HKCategorySample.mockSleep(value: .asleepCore, start: bedTime, duration: 3 * 3600),
            HKCategorySample.mockSleep(value: .asleepDeep, start: bedTime.addingTimeInterval(3 * 3600), duration: 2 * 3600),
            HKCategorySample.mockSleep(value: .asleepREM, start: bedTime.addingTimeInterval(5 * 3600), duration: 2 * 3600)
        ]

        // Act
        let result = await assistant.fetchDetailedSleepData()

        // Assert
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalHours ?? 0, 7.0, accuracy: 0.01)
        XCTAssertEqual(result?.bedTime?.timeIntervalSince1970 ?? 0, bedTime.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(result?.wakeTime?.timeIntervalSince1970 ?? 0, wakeTime.timeIntervalSince1970, accuracy: 1.0)
    }

    func testFetchDetailedSleepDataGroupsFragmentedSleep() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Two separate sleep sessions with >1hr gap
        let session1Start = Date.hoursAgo(20)
        let session2Start = Date.hoursAgo(8)

        provider.mockCategorySamples = [
            HKCategorySample.mockSleep(value: .asleepCore, start: session1Start, duration: 1 * 3600),
            HKCategorySample.mockSleep(value: .asleepCore, start: session2Start, duration: 7 * 3600)
        ]

        // Act
        let result = await assistant.fetchDetailedSleepData()

        // Assert: Should return most recent session (7 hours)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalHours ?? 0, 7.0, accuracy: 0.01)
        XCTAssertEqual(result?.bedTime?.timeIntervalSince1970 ?? 0, session2Start.timeIntervalSince1970, accuracy: 1.0)
    }

    func testFetchDetailedSleepDataReturnsNilWhenNoData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        provider.mockCategorySamples = []

        // Act
        let result = await assistant.fetchDetailedSleepData()

        // Assert
        XCTAssertNil(result)
    }

    // MARK: - Workout Minutes Tests

    func testRecentWorkoutMinutesSumsLast24Hours() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Multiple workouts
        let workout1 = HKWorkout.mockWorkout(start: .hoursAgo(20), duration: 30 * 60) // 30 minutes
        let workout2 = HKWorkout.mockWorkout(start: .hoursAgo(12), duration: 45 * 60) // 45 minutes
        let workout3 = HKWorkout.mockWorkout(start: .hoursAgo(2), duration: 25 * 60)  // 25 minutes

        provider.mockWorkouts = [workout1, workout2, workout3]

        // Act
        let workoutMinutes = await assistant.recentWorkoutMinutes()

        // Assert: Total 100 minutes
        XCTAssertEqual(workoutMinutes ?? 0, 100.0, accuracy: 0.01)
    }

    func testRecentWorkoutMinutesIncludesAllWorkoutTypes() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Different workout types
        let running = HKWorkout.mockWorkout(activityType: .running, start: .hoursAgo(10), duration: 30 * 60)
        let cycling = HKWorkout.mockWorkout(activityType: .cycling, start: .hoursAgo(8), duration: 45 * 60)
        let yoga = HKWorkout.mockWorkout(activityType: .yoga, start: .hoursAgo(6), duration: 60 * 60)

        provider.mockWorkouts = [running, cycling, yoga]

        // Act
        let workoutMinutes = await assistant.recentWorkoutMinutes()

        // Assert: Total 135 minutes
        XCTAssertEqual(workoutMinutes ?? 0, 135.0, accuracy: 0.01)
    }

    func testRecentWorkoutMinutesUsesCacheWhenValid() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        provider.mockWorkouts = [
            HKWorkout.mockWorkout(start: .hoursAgo(5), duration: 30 * 60)
        ]
        _ = await assistant.recentWorkoutMinutes()

        provider.reset()

        // Act: Within cache window (6 hours)
        let result = await assistant.recentWorkoutMinutes()

        // Assert
        XCTAssertEqual(result ?? 0, 30.0, accuracy: 0.01)
        XCTAssertEqual(provider.executeCount, 0)
    }

    func testRecentWorkoutMinutesReturnsNilWhenNoData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        provider.mockWorkouts = []

        // Act
        let result = await assistant.recentWorkoutMinutes()

        // Assert
        XCTAssertEqual(result, 0.0) // Empty array sums to 0
    }

    // MARK: - Menstrual Cycle Day Tests

    func testRecentCycleDayCalculatesDaysSincePeriodStart() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Period started 12 days ago
        let periodStart = Calendar.current.startOfDay(for: .daysAgo(12))
        provider.mockCategorySamples = [
            HKCategorySample.mockMenstrualFlow(value: .medium, date: periodStart)
        ]

        // Act
        let cycleDay = await assistant.recentCycleDay()

        // Assert: Should be day 13 (12 days ago + 1)
        XCTAssertEqual(cycleDay, 13)
    }

    func testRecentCycleDayUsesStartOfDay() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Period started at specific time today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let periodStart = today.addingTimeInterval(14 * 3600) // 2pm today

        provider.mockCategorySamples = [
            HKCategorySample.mockMenstrualFlow(value: .heavy, date: periodStart)
        ]

        // Act
        let cycleDay = await assistant.recentCycleDay()

        // Assert: Should be day 1 regardless of time
        XCTAssertEqual(cycleDay, 1)
    }

    func testRecentCycleDayReturnsNilWhenNoData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        provider.mockCategorySamples = []

        // Act
        let cycleDay = await assistant.recentCycleDay()

        // Assert
        XCTAssertNil(cycleDay)
    }

    // MARK: - Menstrual Flow Level Tests

    func testRecentFlowLevelReturnsTodaysFlow() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Flow entry for today
        let today = Calendar.current.startOfDay(for: Date())
        provider.mockCategorySamples = [
            HKCategorySample.mockMenstrualFlow(value: .medium, date: today)
        ]

        // Act
        let flowLevel = await assistant.recentFlowLevel()

        // Assert
        XCTAssertEqual(flowLevel, "medium")
    }

    func testRecentFlowLevelMapsHealthKitValues() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        let today = Calendar.current.startOfDay(for: Date())

        // Test light
        provider.mockCategorySamples = [HKCategorySample.mockMenstrualFlow(value: .light, date: today)]
        var result = await assistant.recentFlowLevel()
        XCTAssertEqual(result, "light")

        // Test medium
        provider.mockCategorySamples = [HKCategorySample.mockMenstrualFlow(value: .medium, date: today)]
        assistant._setCacheTimestamp(.daysAgo(1), for: "cycle") // Invalidate cache
        result = await assistant.recentFlowLevel()
        XCTAssertEqual(result, "medium")

        // Test heavy
        provider.mockCategorySamples = [HKCategorySample.mockMenstrualFlow(value: .heavy, date: today)]
        assistant._setCacheTimestamp(.daysAgo(1), for: "cycle")
        result = await assistant.recentFlowLevel()
        XCTAssertEqual(result, "heavy")

        // Test spotting (unspecified maps to spotting)
        provider.mockCategorySamples = [HKCategorySample.mockMenstrualFlow(value: .unspecified, date: today)]
        assistant._setCacheTimestamp(.daysAgo(1), for: "cycle")
        result = await assistant.recentFlowLevel()
        XCTAssertEqual(result, "spotting")
    }

    func testRecentFlowLevelReturnsNilForNonBleedingDays() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: No flow data for today
        provider.mockCategorySamples = []

        // Act
        let result = await assistant.recentFlowLevel()

        // Assert
        XCTAssertNil(result)
    }
}
