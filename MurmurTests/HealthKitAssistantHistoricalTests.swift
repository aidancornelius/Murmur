//
//  HealthKitAssistantHistoricalTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import HealthKit
import XCTest
@testable import Murmur

/// Placeholder test suite for HealthKitAssistant historical data queries
/// These tests cover the "ForDate" methods that retrieve health metrics for specific historical dates
@MainActor
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
