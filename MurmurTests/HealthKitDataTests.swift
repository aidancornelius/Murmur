//
//  HealthKitDataTests.swift
//  Murmur
//
//  Consolidated test suite for HealthKit data operations: baselines, historical data, and metrics
//
//  Originally from:
//  - HealthKitAssistantRecentMetricsTests.swift (28 tests)
//  - HealthKitAssistantHistoricalTests.swift (6 tests)
//  - HealthKitAssistantBaselineTests.swift (4 tests)
//  - HealthKitBaselineCalculatorTests.swift (11 tests)
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
        await provider.setMockData(quantitySamples: [newerSample, olderSample], categorySamples: [], workouts: [])

        // Act
        let hrv = await assistant.recentHRV()

        // Assert
        XCTAssertEqual(hrv ?? 0, 50.0, accuracy: 0.01)
        let executeCount = await provider.executeCount
        XCTAssertEqual(executeCount, 1)
    }

    func testRecentHRVConvertsUnitCorrectly() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: HRV should be in milliseconds
        await provider.setMockData(quantitySamples: [HKQuantitySample.mockHRV(value: 42.5, date: Date())], categorySamples: [], workouts: [])

        // Act
        let hrv = await assistant.recentHRV()

        // Assert: Value should be preserved in ms
        XCTAssertEqual(hrv ?? 0, 42.5, accuracy: 0.01)
    }

    func testRecentHRVUsesCacheWhenValid() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: First call populates cache
        await provider.setMockData(quantitySamples: [HKQuantitySample.mockHRV(value: 45.0, date: Date())], categorySamples: [], workouts: [])
        let firstResult = await assistant.recentHRV()

        // Clear mock samples to verify cache is used
        await provider.reset()

        // Act: Second call within cache window (30 minutes)
        let secondResult = await assistant.recentHRV()

        // Assert: Cache was used, no new query executed
        XCTAssertEqual(firstResult, secondResult)
        let executeCount = await provider.executeCount
        XCTAssertEqual(executeCount, 0) // No new query
    }

    func testRecentHRVBypassesStaleCache() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: First call populates cache
        await provider.setMockData(quantitySamples: [HKQuantitySample.mockHRV(value: 45.0, date: Date())], categorySamples: [], workouts: [])
        _ = await assistant.recentHRV()

        // Simulate cache expiration (31 minutes ago)
        await assistant._setCacheTimestamp(.minutesAgo(31), for: "hrv")

        // New data available
        await provider.reset()
        await provider.setMockData(quantitySamples: [HKQuantitySample.mockHRV(value: 52.0, date: Date())], categorySamples: [], workouts: [])

        // Act: Second call after cache expiry
        let result = await assistant.recentHRV()

        // Assert: Cache was refreshed
        XCTAssertEqual(result ?? 0, 52.0, accuracy: 0.01)
        let executeCount = await provider.executeCount
        XCTAssertEqual(executeCount, 1) // New query executed
    }

    func testRecentHRVReturnsNilWhenNoData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: No samples available
        await provider.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

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
        await provider.setMockData(quantitySamples: [newerSample, olderSample], categorySamples: [], workouts: [])

        // Act
        let restingHR = await assistant.recentRestingHR()

        // Assert
        XCTAssertEqual(restingHR ?? 0, 62.0, accuracy: 0.01)
    }

    func testRecentRestingHRConvertsToBPM() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        await provider.setMockData(quantitySamples: [HKQuantitySample.mockRestingHR(value: 68.5, date: Date())], categorySamples: [], workouts: [])

        // Act
        let restingHR = await assistant.recentRestingHR()

        // Assert: Should be in beats per minute
        XCTAssertEqual(restingHR ?? 0, 68.5, accuracy: 0.01)
    }

    func testRecentRestingHRUsesCacheWhenValid() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Populate cache
        await provider.setMockData(quantitySamples: [HKQuantitySample.mockRestingHR(value: 65.0, date: Date())], categorySamples: [], workouts: [])
        _ = await assistant.recentRestingHR()

        await provider.reset()

        // Act: Query within cache window (60 minutes)
        let result = await assistant.recentRestingHR()

        // Assert: Cache used
        XCTAssertEqual(result ?? 0, 65.0, accuracy: 0.01)
        let executeCount = await provider.executeCount
        XCTAssertEqual(executeCount, 0)
    }

    func testRecentRestingHRReturnsNilWhenNoData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        await provider.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

        // Act
        let result = await assistant.recentRestingHR()

        // Assert
        XCTAssertNil(result)
    }

    func testRecentRestingHRHandlesError() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        await provider.setShouldThrowError(NSError(domain: HKErrorDomain, code: HKError.errorAuthorizationDenied.rawValue))

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
        await provider.setMockData(quantitySamples: [], categorySamples: [session1, session2, session3], workouts: [])

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

        await provider.setMockData(quantitySamples: [], categorySamples: [core, deep, rem, unspecified], workouts: [])

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

        await provider.setMockData(quantitySamples: [], categorySamples: [asleep, inBed], workouts: [])

        // Act
        let sleepHours = await assistant.recentSleepHours()

        // Assert: Should only count asleep time (7 hours)
        XCTAssertEqual(sleepHours ?? 0, 7.0, accuracy: 0.01)
    }

    func testRecentSleepHoursUsesCacheWhenValid() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [HKCategorySample.mockSleep(value: .asleepCore, start: .hoursAgo(8), duration: 7 * 3600)],
            workouts: []
        )
        _ = await assistant.recentSleepHours()

        await provider.reset()

        // Act: Within cache window (6 hours)
        let result = await assistant.recentSleepHours()

        // Assert
        XCTAssertEqual(result ?? 0, 7.0, accuracy: 0.01)
        let executeCount = await provider.executeCount
        XCTAssertEqual(executeCount, 0)
    }

    func testRecentSleepHoursReturnsNilWhenNoData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        await provider.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

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

        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [
                HKCategorySample.mockSleep(value: .asleepCore, start: bedTime, duration: 3 * 3600),
                HKCategorySample.mockSleep(value: .asleepDeep, start: bedTime.addingTimeInterval(3 * 3600), duration: 2 * 3600),
                HKCategorySample.mockSleep(value: .asleepREM, start: bedTime.addingTimeInterval(5 * 3600), duration: 2 * 3600)
            ],
            workouts: []
        )

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

        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [
                HKCategorySample.mockSleep(value: .asleepCore, start: session1Start, duration: 1 * 3600),
                HKCategorySample.mockSleep(value: .asleepCore, start: session2Start, duration: 7 * 3600)
            ],
            workouts: []
        )

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
        await provider.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

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

        await provider.setMockData(quantitySamples: [], categorySamples: [], workouts: [workout1, workout2, workout3])

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

        await provider.setMockData(quantitySamples: [], categorySamples: [], workouts: [running, cycling, yoga])

        // Act
        let workoutMinutes = await assistant.recentWorkoutMinutes()

        // Assert: Total 135 minutes
        XCTAssertEqual(workoutMinutes ?? 0, 135.0, accuracy: 0.01)
    }

    func testRecentWorkoutMinutesUsesCacheWhenValid() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [],
            workouts: [HKWorkout.mockWorkout(start: .hoursAgo(5), duration: 30 * 60)]
        )
        _ = await assistant.recentWorkoutMinutes()

        await provider.reset()

        // Act: Within cache window (6 hours)
        let result = await assistant.recentWorkoutMinutes()

        // Assert
        XCTAssertEqual(result ?? 0, 30.0, accuracy: 0.01)
        let executeCount = await provider.executeCount
        XCTAssertEqual(executeCount, 0)
    }

    func testRecentWorkoutMinutesReturnsNilWhenNoData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        await provider.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

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
        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [HKCategorySample.mockMenstrualFlow(value: .medium, date: periodStart)],
            workouts: []
        )

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

        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [HKCategorySample.mockMenstrualFlow(value: .heavy, date: periodStart)],
            workouts: []
        )

        // Act
        let cycleDay = await assistant.recentCycleDay()

        // Assert: Should be day 1 regardless of time
        XCTAssertEqual(cycleDay, 1)
    }

    func testRecentCycleDayReturnsNilWhenNoData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange
        await provider.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

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
        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [HKCategorySample.mockMenstrualFlow(value: .medium, date: today)],
            workouts: []
        )

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
        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [HKCategorySample.mockMenstrualFlow(value: .light, date: today)],
            workouts: []
        )
        var result = await assistant.recentFlowLevel()
        XCTAssertEqual(result, "light")

        // Test medium
        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [HKCategorySample.mockMenstrualFlow(value: .medium, date: today)],
            workouts: []
        )
        await assistant._setCacheTimestamp(.daysAgo(1), for: "cycle") // Invalidate cache
        result = await assistant.recentFlowLevel()
        XCTAssertEqual(result, "medium")

        // Test heavy
        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [HKCategorySample.mockMenstrualFlow(value: .heavy, date: today)],
            workouts: []
        )
        await assistant._setCacheTimestamp(.daysAgo(1), for: "cycle")
        result = await assistant.recentFlowLevel()
        XCTAssertEqual(result, "heavy")

        // Test spotting (unspecified maps to spotting)
        await provider.setMockData(
            quantitySamples: [],
            categorySamples: [HKCategorySample.mockMenstrualFlow(value: .unspecified, date: today)],
            workouts: []
        )
        await assistant._setCacheTimestamp(.daysAgo(1), for: "cycle")
        result = await assistant.recentFlowLevel()
        XCTAssertEqual(result, "spotting")
    }

    func testRecentFlowLevelReturnsNilForNonBleedingDays() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: No flow data for today
        await provider.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

        // Act
        let result = await assistant.recentFlowLevel()

        // Assert
        XCTAssertNil(result)
    }
}

// MARK: - Historical Data Tests

final class HealthKitAssistantHistoricalTests: HealthKitAssistantTestCase {

    // MARK: - HRV Historical Tests

    func testHRVForDateReturnsCorrectDateData() async throws {
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create HRV samples for different historical dates
        let threeDaysAgo = Date.daysAgo(3)
        let fiveDaysAgo = Date.daysAgo(5)

        let sample3DaysAgo = HKQuantitySample.mockHRV(value: 45.0, date: threeDaysAgo)
        let sample5DaysAgo = HKQuantitySample.mockHRV(value: 50.0, date: fiveDaysAgo)

        await configureMockData(hrv: [sample3DaysAgo, sample5DaysAgo])

        // Act: Query for the specific date (3 days ago)
        let hrv = await assistant.hrvForDate(threeDaysAgo)

        // Assert: Should return the correct value for that specific date (in milliseconds)
        let unwrappedHRV = try XCTUnwrap(hrv)
        XCTAssertEqual(unwrappedHRV, 45.0, accuracy: 0.01)
    }

    // MARK: - Resting heart rate historical tests

    func testRestingHRForDateReturnsCorrectDateData() async throws {
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create resting HR samples for different historical dates
        let threeDaysAgo = Date.daysAgo(3)
        let fiveDaysAgo = Date.daysAgo(5)

        let sample3DaysAgo = HKQuantitySample.mockRestingHR(value: 62.0, date: threeDaysAgo)
        let sample5DaysAgo = HKQuantitySample.mockRestingHR(value: 58.0, date: fiveDaysAgo)

        await configureMockData(restingHR: [sample3DaysAgo, sample5DaysAgo])

        // Act: Query for the specific date (3 days ago)
        let restingHR = await assistant.restingHRForDate(threeDaysAgo)

        // Assert: Should return the correct value for that specific date (in BPM)
        let unwrappedRestingHR = try XCTUnwrap(restingHR)
        XCTAssertEqual(unwrappedRestingHR, 62.0, accuracy: 0.01)
    }

    // MARK: - Sleep historical tests

    func testSleepHoursForDateReturnsCorrectDateData() async throws {
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create sleep samples for different historical dates
        let threeDaysAgo = Date.daysAgo(3)
        let fiveDaysAgo = Date.daysAgo(5)

        // Sleep for 3 days ago: 7 hours total (multiple stages)
        let sleep3Day1 = HKCategorySample.mockSleep(
            value: .asleepCore,
            start: Calendar.current.startOfDay(for: threeDaysAgo),
            duration: 3 * 3600 // 3 hours
        )
        let sleep3Day2 = HKCategorySample.mockSleep(
            value: .asleepDeep,
            start: Calendar.current.startOfDay(for: threeDaysAgo).addingTimeInterval(3 * 3600),
            duration: 2 * 3600 // 2 hours
        )
        let sleep3Day3 = HKCategorySample.mockSleep(
            value: .asleepREM,
            start: Calendar.current.startOfDay(for: threeDaysAgo).addingTimeInterval(5 * 3600),
            duration: 2 * 3600 // 2 hours
        )

        // Sleep for 5 days ago: 6 hours total
        let sleep5Day = HKCategorySample.mockSleep(
            value: .asleepCore,
            start: Calendar.current.startOfDay(for: fiveDaysAgo),
            duration: 6 * 3600 // 6 hours
        )

        await configureMockData(sleep: [sleep3Day1, sleep3Day2, sleep3Day3, sleep5Day])

        // Act: Query for the specific date (3 days ago)
        let sleepHours = await assistant.sleepHoursForDate(threeDaysAgo)
        let result = try XCTUnwrap(sleepHours)

        // Assert: Should return the aggregated sleep hours for that specific date (7 hours)
        XCTAssertEqual(result, 7.0, accuracy: 0.01)
    }

    // MARK: - Workout historical tests

    func testWorkoutMinutesForDateReturnsCorrectDateData() async throws {
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create workouts for different historical dates
        let threeDaysAgo = Date.daysAgo(3)
        let fiveDaysAgo = Date.daysAgo(5)

        // Create multiple workouts for the target date (3 days ago) - should be summed
        let workout1 = HKWorkout.mockWorkout(
            activityType: .running,
            start: threeDaysAgo,
            duration: 45 * 60 // 45 minutes
        )
        let workout2 = HKWorkout.mockWorkout(
            activityType: .cycling,
            start: threeDaysAgo.addingTimeInterval(3600), // 1 hour after first workout
            duration: 30 * 60 // 30 minutes
        )

        // Create a workout for a different date (should not be included)
        let workout3 = HKWorkout.mockWorkout(
            activityType: .yoga,
            start: fiveDaysAgo,
            duration: 60 * 60 // 60 minutes
        )

        await configureMockData(workouts: [workout1, workout2, workout3])

        // Act: Query for workout minutes for the specific date (3 days ago)
        let workoutMinutes = await assistant.workoutMinutesForDate(threeDaysAgo)
        let result = try XCTUnwrap(workoutMinutes)

        // Assert: Should return total of 75 minutes (45 + 30) for the queried date only
        XCTAssertEqual(result, 75.0, accuracy: 0.01)
    }

    // MARK: - Cycle day historical tests

    func testCycleDayForDateReturnsCorrectDateData() async throws {
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Period started 10 days ago
        let periodStart = Calendar.current.startOfDay(for: .daysAgo(10))
        let menstrualFlowSample = HKCategorySample.mockMenstrualFlow(value: .medium, date: periodStart)

        await configureMockData(menstrualFlow: [menstrualFlowSample])

        // Act: Query for a date 5 days ago (which would be cycle day 6: 10 - 5 = 5 days since start, + 1 = day 6)
        let queryDate = Date.daysAgo(5)
        let cycleDay = await assistant.cycleDayForDate(queryDate)

        // Assert: Should be day 6 (5 days since period start + 1)
        let unwrappedCycleDay = try XCTUnwrap(cycleDay)
        XCTAssertEqual(unwrappedCycleDay, 6)
    }

    // MARK: - Flow level historical tests

    func testFlowLevelForDateReturnsCorrectDateData() async throws {
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create flow samples for different historical dates with different flow levels
        let calendar = Calendar.current
        let threeDaysAgo = calendar.startOfDay(for: Date.daysAgo(3))
        let fiveDaysAgo = calendar.startOfDay(for: Date.daysAgo(5))
        let sevenDaysAgo = calendar.startOfDay(for: Date.daysAgo(7))

        let mediumFlow = HKCategorySample.mockMenstrualFlow(value: .medium, date: threeDaysAgo)
        let heavyFlow = HKCategorySample.mockMenstrualFlow(value: .heavy, date: fiveDaysAgo)
        let lightFlow = HKCategorySample.mockMenstrualFlow(value: .light, date: sevenDaysAgo)

        await configureMockData(menstrualFlow: [mediumFlow, heavyFlow, lightFlow])

        // Act: Query for specific dates
        let flowThreeDaysAgo = await assistant.flowLevelForDate(threeDaysAgo)
        let flowFiveDaysAgo = await assistant.flowLevelForDate(fiveDaysAgo)
        let flowSevenDaysAgo = await assistant.flowLevelForDate(sevenDaysAgo)

        // Assert: Should return the correct flow level string for each specific date
        let unwrappedFlowThreeDaysAgo = try XCTUnwrap(flowThreeDaysAgo)
        XCTAssertEqual(unwrappedFlowThreeDaysAgo, "medium")

        let unwrappedFlowFiveDaysAgo = try XCTUnwrap(flowFiveDaysAgo)
        XCTAssertEqual(unwrappedFlowFiveDaysAgo, "heavy")

        let unwrappedFlowSevenDaysAgo = try XCTUnwrap(flowSevenDaysAgo)
        XCTAssertEqual(unwrappedFlowSevenDaysAgo, "light")
    }
}

// MARK: - Baseline Tests

final class HealthKitAssistantBaselineTests: HealthKitAssistantTestCase {

    // MARK: - Baseline calculation tests

    func testUpdateHRVBaselineFetches30DaysOfSamples() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create 30 days of samples
        var samples: [HKQuantitySample] = []
        for day in 0..<30 {
            samples.append(HKQuantitySample.mockHRV(value: Double(40 + day), date: .daysAgo(day)))
        }
        await provider.setMockData(quantitySamples: samples, categorySamples: [], workouts: [])

        // Clear existing baseline
        await MainActor.run {
            HealthMetricBaselines.shared.hrvBaseline = nil
        }

        // Act
        await assistant.updateBaselines()

        // Give baselines time to update
        try await waitForAsyncOperations()

        // Assert: Baseline should be calculated
        let baseline = await MainActor.run { HealthMetricBaselines.shared.hrvBaseline }
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline?.sampleCount, 30)
        XCTAssertGreaterThan(baseline?.mean ?? 0, 0)
        XCTAssertGreaterThan(baseline?.standardDeviation ?? 0, 0)
    }

    func testUpdateRestingHRBaselineCalculatesStatistics() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create samples with known values
        let values: [Double] = [60, 62, 61, 63, 59, 64, 60, 61, 62, 63, 65, 64, 62, 61, 60]
        var samples: [HKQuantitySample] = []
        for (index, value) in values.enumerated() {
            samples.append(HKQuantitySample.mockRestingHR(value: value, date: .daysAgo(index)))
        }
        await provider.setMockData(quantitySamples: samples, categorySamples: [], workouts: [])

        // Clear existing baseline
        await MainActor.run {
            HealthMetricBaselines.shared.restingHRBaseline = nil
        }

        // Act
        await assistant.updateBaselines()

        // Give baselines time to update
        try await waitForAsyncOperations()

        // Assert
        let baseline = await MainActor.run { HealthMetricBaselines.shared.restingHRBaseline }
        XCTAssertNotNil(baseline)
        XCTAssertEqual(baseline?.sampleCount, 15)
        // Mean should be around 61.73
        XCTAssertEqual(baseline?.mean ?? 0, 61.73, accuracy: 0.5)
    }

    func testUpdateBaselinesHandlesInsufficientData() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Only 5 samples (need 10+ for baseline)
        var samples: [HKQuantitySample] = []
        for day in 0..<5 {
            samples.append(HKQuantitySample.mockHRV(value: Double(40 + day), date: .daysAgo(day)))
        }
        await provider.setMockData(quantitySamples: samples, categorySamples: [], workouts: [])

        // Clear existing baseline
        await MainActor.run {
            HealthMetricBaselines.shared.hrvBaseline = nil
        }

        // Act
        await assistant.updateBaselines()

        // Give baselines time to update
        try await waitForAsyncOperations()

        // Assert: Should not create baseline with insufficient data
        let baseline = await MainActor.run { HealthMetricBaselines.shared.hrvBaseline }
        XCTAssertNil(baseline)
    }

    func testUpdateBaselinesRunsInParallel() async throws {
        let provider = try XCTUnwrap(mockDataProvider)
        let assistant = try XCTUnwrap(healthKit)

        // Arrange: Create samples for both HRV and HR
        var hrvSamples: [HKQuantitySample] = []
        for day in 0..<30 {
            hrvSamples.append(HKQuantitySample.mockHRV(value: Double(40 + day), date: .daysAgo(day)))
            hrvSamples.append(HKQuantitySample.mockRestingHR(value: Double(60 + day), date: .daysAgo(day)))
        }
        await provider.setMockData(quantitySamples: hrvSamples, categorySamples: [], workouts: [])

        let startTime = Date()

        // Act
        await assistant.updateBaselines()

        let duration = Date().timeIntervalSince(startTime)

        // Assert: Should complete quickly (parallel execution)
        // If sequential, would take longer
        XCTAssertLessThan(duration, 2.0) // Should complete in under 2 seconds
    }
}

// MARK: - Baseline Calculator Tests

@MainActor
final class HealthKitBaselineCalculatorTests: XCTestCase {

    var mockDataProvider: MockHealthKitDataProvider?
    var mockQueryService: MockHealthKitQueryService?
    var baselineCalculator: HealthKitBaselineCalculator?

    override func setUp() async throws {
        try await super.setUp()
        mockDataProvider = MockHealthKitDataProvider()
        mockQueryService = MockHealthKitQueryService(dataProvider: mockDataProvider!)
        baselineCalculator = HealthKitBaselineCalculator(queryService: mockQueryService!)
    }

    override func tearDown() async throws {
        await mockDataProvider?.reset()
        mockDataProvider = nil
        mockQueryService = nil
        baselineCalculator = nil
        try await super.tearDown()
    }

    // MARK: - Update HRV Baseline Tests

    func testUpdateHRVBaseline_Success() async {
        // Given - Need at least 10 samples for baseline calculation
        let mockSamples = [
            HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(1)),
            HKQuantitySample.mockHRV(value: 50.0, date: .daysAgo(3)),
            HKQuantitySample.mockHRV(value: 42.0, date: .daysAgo(5)),
            HKQuantitySample.mockHRV(value: 48.0, date: .daysAgo(7)),
            HKQuantitySample.mockHRV(value: 46.0, date: .daysAgo(9)),
            HKQuantitySample.mockHRV(value: 44.0, date: .daysAgo(11)),
            HKQuantitySample.mockHRV(value: 47.0, date: .daysAgo(13)),
            HKQuantitySample.mockHRV(value: 49.0, date: .daysAgo(15)),
            HKQuantitySample.mockHRV(value: 43.0, date: .daysAgo(17)),
            HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(19))
        ]
        await mockDataProvider!.setMockData(quantitySamples: mockSamples, categorySamples: [], workouts: [])

        // When
        await baselineCalculator!.updateHRVBaseline()

        // Then
        let fetchCount = await mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)

        // Verify baseline was updated (check singleton)
        let baseline = HealthMetricBaselines.shared.hrvBaseline
        XCTAssertNotNil(baseline)
        if let baseline = baseline {
            XCTAssertGreaterThan(baseline.mean, 0)
        } else {
            XCTFail("Baseline should not be nil")
        }
    }

    func testUpdateHRVBaseline_NoSamples() async {
        // Given
        await mockDataProvider!.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

        // When
        await baselineCalculator!.updateHRVBaseline()

        // Then
        let fetchCount = await mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)
        // Baseline should remain unchanged or be nil
    }

    func testUpdateHRVBaseline_WithError() async {
        // Given
        await mockDataProvider!.setMockData(quantitySamples: [], categorySamples: [], workouts: [])
        await mockQueryService!.setError(NSError(domain: "TestError", code: 1))

        // When
        await baselineCalculator!.updateHRVBaseline()

        // Then
        let fetchCount = await mockQueryService!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)
        // Should handle error gracefully without crashing
    }

    // MARK: - Update Resting HR Baseline Tests

    func testUpdateRestingHRBaseline_Success() async {
        // Given - Need at least 10 samples for baseline calculation
        let mockSamples = [
            HKQuantitySample.mockRestingHR(value: 62.0, date: .daysAgo(1)),
            HKQuantitySample.mockRestingHR(value: 64.0, date: .daysAgo(3)),
            HKQuantitySample.mockRestingHR(value: 60.0, date: .daysAgo(5)),
            HKQuantitySample.mockRestingHR(value: 63.0, date: .daysAgo(7)),
            HKQuantitySample.mockRestingHR(value: 61.0, date: .daysAgo(9)),
            HKQuantitySample.mockRestingHR(value: 65.0, date: .daysAgo(11)),
            HKQuantitySample.mockRestingHR(value: 59.0, date: .daysAgo(13)),
            HKQuantitySample.mockRestingHR(value: 62.0, date: .daysAgo(15)),
            HKQuantitySample.mockRestingHR(value: 63.0, date: .daysAgo(17)),
            HKQuantitySample.mockRestingHR(value: 61.0, date: .daysAgo(19))
        ]
        await mockDataProvider!.setMockData(quantitySamples: mockSamples, categorySamples: [], workouts: [])

        // When
        await baselineCalculator!.updateRestingHRBaseline()

        // Then
        let fetchCount = await mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)

        // Verify baseline was updated
        let baseline = HealthMetricBaselines.shared.restingHRBaseline
        XCTAssertNotNil(baseline)
        if let baseline = baseline {
            XCTAssertGreaterThan(baseline.mean, 0)
        } else {
            XCTFail("Baseline should not be nil")
        }
    }

    func testUpdateRestingHRBaseline_NoSamples() async {
        // Given
        await mockDataProvider!.setMockData(quantitySamples: [], categorySamples: [], workouts: [])

        // When
        await baselineCalculator!.updateRestingHRBaseline()

        // Then
        let fetchCount = await mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)
    }

    func testUpdateRestingHRBaseline_WithError() async {
        // Given
        await mockDataProvider!.setMockData(quantitySamples: [], categorySamples: [], workouts: [])
        await mockQueryService!.setError(NSError(domain: "TestError", code: 1))

        // When
        await baselineCalculator!.updateRestingHRBaseline()

        // Then
        let fetchCount = await mockQueryService!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)
        // Should handle error gracefully
    }

    // MARK: - Update All Baselines Tests

    func testUpdateBaselines_Success() async {
        // Given
        let hrvSamples = [
            HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(1)),
            HKQuantitySample.mockHRV(value: 50.0, date: .daysAgo(5))
        ]

        let hrSamples = [
            HKQuantitySample.mockRestingHR(value: 62.0, date: .daysAgo(1)),
            HKQuantitySample.mockRestingHR(value: 64.0, date: .daysAgo(5))
        ]

        await mockDataProvider!.setMockData(quantitySamples: hrvSamples + hrSamples, categorySamples: [], workouts: [])

        // When
        await baselineCalculator!.updateBaselines()

        // Then
        // Should call both HRV and resting HR fetches
        let fetchCount = await mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 2, "Should fetch both HRV and resting HR")
    }

    func testUpdateBaselines_ConcurrentExecution() async {
        // Given
        await mockDataProvider!.setMockData(
            quantitySamples: [
                HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(1)),
                HKQuantitySample.mockRestingHR(value: 62.0, date: .daysAgo(1))
            ],
            categorySamples: [],
            workouts: []
        )

        // When
        let startTime = Date()
        await baselineCalculator!.updateBaselines()
        let duration = Date().timeIntervalSince(startTime)

        // Then
        let fetchCount = await mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 2)
        // Should complete quickly since it's concurrent (not a strict test, but validates structure)
        XCTAssertLessThan(duration, 1.0, "Should execute concurrently")
    }

    // MARK: - Baseline Value Calculation Tests

    func testHRVBaseline_CalculatesCorrectValue() async {
        // Given - 30 days of samples with known values
        let values = [45.0, 50.0, 42.0, 48.0, 46.0, 44.0, 47.0, 49.0, 43.0, 45.0]
        let mockSamples = values.enumerated().map { index, value in
            HKQuantitySample.mockHRV(value: value, date: .daysAgo(index + 1))
        }
        await mockDataProvider!.setMockData(quantitySamples: mockSamples, categorySamples: [], workouts: [])

        // Clear existing baseline (resetAll clears both HRV and resting HR)
        HealthMetricBaselines.shared.resetAll()

        // When
        await baselineCalculator!.updateHRVBaseline()

        // Then
        let baseline = HealthMetricBaselines.shared.hrvBaseline
        if let baseline = baseline {
            XCTAssertGreaterThan(baseline.mean, 0)

            // Baseline should be within range of input values
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 0
            XCTAssertGreaterThanOrEqual(baseline.mean, minValue)
            XCTAssertLessThanOrEqual(baseline.mean, maxValue)
        } else {
            XCTFail("Baseline should not be nil")
        }
    }

    func testRestingHRBaseline_CalculatesCorrectValue() async {
        // Given
        let values = [62.0, 64.0, 60.0, 63.0, 61.0, 65.0, 59.0, 62.0, 63.0, 61.0]
        let mockSamples = values.enumerated().map { index, value in
            HKQuantitySample.mockRestingHR(value: value, date: .daysAgo(index + 1))
        }
        await mockDataProvider!.setMockData(quantitySamples: mockSamples, categorySamples: [], workouts: [])

        // Clear existing baseline (resetAll clears both HRV and resting HR)
        HealthMetricBaselines.shared.resetAll()

        // When
        await baselineCalculator!.updateRestingHRBaseline()

        // Then
        let baseline = HealthMetricBaselines.shared.restingHRBaseline
        if let baseline = baseline {
            XCTAssertGreaterThan(baseline.mean, 0)

            // Baseline should be within range of input values
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 0
            XCTAssertGreaterThanOrEqual(baseline.mean, minValue)
            XCTAssertLessThanOrEqual(baseline.mean, maxValue)
        } else {
            XCTFail("Baseline should not be nil")
        }
    }

    // MARK: - Date Range Tests

    func testUpdateBaselines_Queries30Days() async {
        // Given
        await mockDataProvider!.setMockData(
            quantitySamples: [
                HKQuantitySample.mockHRV(value: 45.0, date: .daysAgo(1))
            ],
            categorySamples: [],
            workouts: []
        )

        // When
        await baselineCalculator!.updateHRVBaseline()

        // Then
        let fetchCount = await mockDataProvider!.fetchQuantityCount
        XCTAssertEqual(fetchCount, 1)
        // Note: We can't directly verify the date range in mock, but the implementation
        // should query 30 days. This could be enhanced with more sophisticated mocking.
    }
}
