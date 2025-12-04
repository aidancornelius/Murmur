// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// LoadCalculatorTests.swift
// Created by Aidan Cornelius-Bell on 12/10/2025.
// Tests for load score calculation algorithm.
//
import XCTest
import CoreData
@testable import Murmur

@MainActor
final class LoadCalculatorTests: XCTestCase {

    var context: NSManagedObjectContext!
    var calculator: LoadCalculator!
    var testDate: Date!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "Murmur")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        let expectation = self.expectation(description: "Core Data stack loaded")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 5.0)

        context = container.viewContext
        calculator = LoadCalculator.shared
        testDate = Calendar.current.startOfDay(for: Date())
    }

    override func tearDown() async throws {
        context = nil
        calculator = nil
        testDate = nil
        try await super.tearDown()
    }

    // MARK: - Activity Tests

    func testActivityLoadContribution() async throws {
        // Create test activity
        let activity = ActivityEvent(context: context)
        activity.id = UUID()
        activity.createdAt = testDate
        activity.name = "Running"
        activity.physicalExertion = 4
        activity.cognitiveExertion = 2
        activity.emotionalLoad = 2
        activity.durationMinutes = NSNumber(value: 60) // 1 hour

        // Calculate expected load
        // Average exertion: (4 + 2 + 2) / 3 = 2.67
        // Duration weight: 60/60 = 1.0
        // Activity weight: 1.0
        // Load: 2.67 * 1.0 * 1.0 * 6.0 = 16
        let expectedLoad = 16.0

        XCTAssertEqual(activity.loadContribution, expectedLoad, accuracy: 0.1)
    }

    func testActivityWithHighExertion() async throws {
        let activity = ActivityEvent(context: context)
        activity.id = UUID()
        activity.createdAt = testDate
        activity.name = "Intense Workout"
        activity.physicalExertion = 5
        activity.cognitiveExertion = 5
        activity.emotionalLoad = 5
        activity.durationMinutes = NSNumber(value: 120) // 2 hours

        // Average exertion: 5.0
        // Duration weight: 2.0 (capped)
        // Load: 5.0 * 2.0 * 1.0 * 6.0 = 60
        XCTAssertEqual(activity.loadContribution, 60.0, accuracy: 0.1)
        XCTAssertTrue(activity.isHighExertion)
    }

    // MARK: - Meal Tests

    func testMealWithExertionData() async throws {
        let meal = MealEvent(context: context)
        meal.id = UUID()
        meal.createdAt = testDate
        meal.mealType = "Lunch"
        meal.mealDescription = "Heavy meal"
        meal.physicalExertion = NSNumber(value: 3)
        meal.cognitiveExertion = NSNumber(value: 2)
        meal.emotionalLoad = NSNumber(value: 2)

        // Average exertion: (3 + 2 + 2) / 3 = 2.33
        // Duration weight: 0.5 (fixed for meals)
        // Meal weight: 0.5
        // Load: 2.33 * 0.5 * 0.5 * 6.0 = 3.5
        XCTAssertEqual(meal.loadContribution, 3.5, accuracy: 0.1)
        XCTAssertTrue(meal.hasExertionData)
    }

    func testMealWithoutExertionData() async throws {
        let meal = MealEvent(context: context)
        meal.id = UUID()
        meal.createdAt = testDate
        meal.mealType = "Snack"
        meal.mealDescription = "Light snack"
        // No exertion data set

        XCTAssertEqual(meal.loadContribution, 0.0)
        XCTAssertFalse(meal.hasExertionData)
        XCTAssertFalse(meal.isHighExertion)
    }

    // MARK: - Sleep Tests

    func testMainSleepWithGoodQuality() async throws {
        let sleep = SleepEvent(context: context)
        sleep.id = UUID()
        sleep.createdAt = testDate
        sleep.bedTime = Calendar.current.date(byAdding: .hour, value: -8, to: testDate)!
        sleep.wakeTime = testDate
        sleep.quality = 4 // Good quality

        XCTAssertTrue(sleep.isMainRecoveryPeriod)
        XCTAssertEqual(sleep.recoveryModifier, 1.2) // 20% faster recovery
        XCTAssertEqual(sleep.loadContribution, 0.0) // Good sleep adds no load
        XCTAssertTrue(sleep.isGoodQuality)
    }

    func testMainSleepWithPoorQuality() async throws {
        let sleep = SleepEvent(context: context)
        sleep.id = UUID()
        sleep.createdAt = testDate
        sleep.bedTime = Calendar.current.date(byAdding: .hour, value: -7, to: testDate)!
        sleep.wakeTime = testDate
        sleep.quality = 1 // Very poor quality

        XCTAssertTrue(sleep.isMainRecoveryPeriod)
        XCTAssertEqual(sleep.recoveryModifier, 0.5) // 50% slower recovery
        XCTAssertEqual(sleep.loadContribution, 10.0) // Poor sleep adds 10 load
        XCTAssertTrue(sleep.isPoorQuality)
    }

    func testNapWithGoodQuality() async throws {
        let nap = SleepEvent(context: context)
        nap.id = UUID()
        nap.createdAt = testDate
        nap.bedTime = Calendar.current.date(byAdding: .hour, value: -2, to: testDate)!
        nap.wakeTime = testDate
        nap.quality = 5 // Excellent quality

        XCTAssertFalse(nap.isMainRecoveryPeriod)
        XCTAssertEqual(nap.recoveryModifier, 1.1) // Minor positive impact
        XCTAssertEqual(nap.loadContribution, 0.0)
        XCTAssertEqual(nap.sleepTypeDescription, "Nap")
    }

    // MARK: - Integrated Load Calculation Tests

    func testCombinedLoadCalculation() async throws {
        // Create test data
        let activity = ActivityEvent(context: context)
        activity.id = UUID()
        activity.createdAt = testDate
        activity.name = "Exercise"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 2
        activity.emotionalLoad = 2
        activity.durationMinutes = NSNumber(value: 60)

        let meal = MealEvent(context: context)
        meal.id = UUID()
        meal.createdAt = testDate
        meal.mealType = "Lunch"
        meal.mealDescription = "Regular meal"
        meal.physicalExertion = NSNumber(value: 2)
        meal.cognitiveExertion = NSNumber(value: 2)
        meal.emotionalLoad = NSNumber(value: 2)

        let sleep = SleepEvent(context: context)
        sleep.id = UUID()
        sleep.createdAt = testDate
        sleep.bedTime = Calendar.current.date(byAdding: .hour, value: -8, to: testDate)!
        sleep.wakeTime = testDate
        sleep.quality = 3 // Normal quality

        let contributors: [LoadContributor] = [activity, meal, sleep]

        // Calculate load
        let config = LoadConfiguration(
            thresholds: LoadThresholds(safe: 25, caution: 50, high: 75, critical: 100),
            symptomMultiplier: 1.0,
            decayRate: 0.7
        )

        let score = calculator.calculate(
            for: testDate,
            contributors: contributors,
            symptoms: [],
            previousLoad: 0.0,
            configuration: config
        )

        // Activity load: ~14
        // Meal load: ~3
        // Sleep load: 0
        // Total should be around 17
        XCTAssertGreaterThan(score.rawLoad, 10.0)
        XCTAssertLessThan(score.rawLoad, 25.0)
        XCTAssertEqual(score.riskLevel, .safe)
    }

    func testPoorSleepImpactOnRecovery() async throws {
        let poorSleep = SleepEvent(context: context)
        poorSleep.id = UUID()
        poorSleep.createdAt = testDate
        poorSleep.bedTime = Calendar.current.date(byAdding: .hour, value: -7, to: testDate)!
        poorSleep.wakeTime = testDate
        poorSleep.quality = 1 // Very poor

        let activity = ActivityEvent(context: context)
        activity.id = UUID()
        activity.createdAt = testDate
        activity.name = "Morning run"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 1
        activity.emotionalLoad = 1
        activity.durationMinutes = NSNumber(value: 30)

        let contributors: [LoadContributor] = [poorSleep, activity]

        let config = LoadConfiguration(
            thresholds: LoadThresholds(safe: 25, caution: 50, high: 75, critical: 100),
            symptomMultiplier: 1.0,
            decayRate: 0.7
        )

        // Calculate with previous load to test recovery impact
        let score = calculator.calculate(
            for: testDate,
            contributors: contributors,
            symptoms: [],
            previousLoad: 30.0, // Previous day had load
            configuration: config
        )

        // Poor sleep should slow recovery
        // Previous load: 30 * 0.7 * 0.5 (poor sleep modifier) = 10.5
        // Plus poor sleep load (10) and activity load (~5)
        // Total should be around 25.5
        XCTAssertGreaterThan(score.decayedLoad, 20.0)
        XCTAssertLessThan(score.decayedLoad, 35.0)
    }

    // MARK: - Load Breakdown Tests

    func testLoadBreakdownAnalysis() async throws {
        let activity = ActivityEvent(context: context)
        activity.id = UUID()
        activity.createdAt = testDate
        activity.name = "Workout"
        activity.physicalExertion = 4
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3
        activity.durationMinutes = NSNumber(value: 45)

        let meal = MealEvent(context: context)
        meal.id = UUID()
        meal.createdAt = testDate
        meal.mealType = "Dinner"
        meal.mealDescription = "Large meal"
        meal.physicalExertion = NSNumber(value: 4)
        meal.cognitiveExertion = NSNumber(value: 2)
        meal.emotionalLoad = NSNumber(value: 3)

        let sleep = SleepEvent(context: context)
        sleep.id = UUID()
        sleep.createdAt = testDate
        sleep.bedTime = Calendar.current.date(byAdding: .hour, value: -5, to: testDate)!
        sleep.wakeTime = testDate
        sleep.quality = 2 // Poor quality

        let contributors: [LoadContributor] = [activity, meal, sleep]

        let breakdown = calculator.analyseContributions(
            contributors: contributors,
            symptoms: []
        )

        XCTAssertGreaterThan(breakdown.activityLoad, 0)
        XCTAssertGreaterThan(breakdown.mealLoad, 0)
        XCTAssertGreaterThan(breakdown.sleepLoad, 0) // Poor sleep adds load
        XCTAssertEqual(breakdown.symptomLoad, 0) // No symptoms

        // Verify percentages add up to 100
        let totalPercentage = breakdown.activityPercentage +
                            breakdown.mealPercentage +
                            breakdown.sleepPercentage +
                            breakdown.symptomPercentage
        XCTAssertEqual(totalPercentage, 100.0, accuracy: 0.1)
    }

    // MARK: - Backward Compatibility Tests

    func testLegacyCompatibilityMethod() async throws {
        let activity = ActivityEvent(context: context)
        activity.id = UUID()
        activity.createdAt = testDate
        activity.name = "Test Activity"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3
        activity.durationMinutes = NSNumber(value: 60)

        let meal = MealEvent(context: context)
        meal.id = UUID()
        meal.createdAt = testDate
        meal.mealType = "Lunch"
        meal.mealDescription = "Test meal"
        meal.physicalExertion = NSNumber(value: 2)
        meal.cognitiveExertion = NSNumber(value: 2)
        meal.emotionalLoad = NSNumber(value: 2)

        let sleep = SleepEvent(context: context)
        sleep.id = UUID()
        sleep.createdAt = testDate
        sleep.bedTime = Calendar.current.date(byAdding: .hour, value: -8, to: testDate)!
        sleep.wakeTime = testDate
        sleep.quality = 4

        // Test legacy method
        let score = calculator.calculate(
            for: testDate,
            activities: [activity],
            meals: [meal],
            sleep: [sleep],
            symptoms: [],
            previousLoad: 0.0
        )

        XCTAssertGreaterThan(score.rawLoad, 0)
        XCTAssertEqual(score.riskLevel, .safe)
    }

    // MARK: - Range Calculation Tests

    func testRangeCalculation() async throws {
        let startDate = Calendar.current.date(byAdding: .day, value: -2, to: testDate)!

        // Create activities for different days
        let activity1 = ActivityEvent(context: context)
        activity1.id = UUID()
        activity1.createdAt = startDate
        activity1.name = "Day 1 Activity"
        activity1.physicalExertion = 3
        activity1.cognitiveExertion = 2
        activity1.emotionalLoad = 2
        activity1.durationMinutes = NSNumber(value: 30)

        let activity2 = ActivityEvent(context: context)
        activity2.id = UUID()
        activity2.createdAt = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!
        activity2.name = "Day 2 Activity"
        activity2.physicalExertion = 4
        activity2.cognitiveExertion = 3
        activity2.emotionalLoad = 3
        activity2.durationMinutes = NSNumber(value: 60)

        let contributors: [LoadContributor] = [activity1, activity2]
        let groupedContributors = calculator.groupContributorsByDate(contributors)

        let scores = calculator.calculateRange(
            from: startDate,
            to: testDate,
            contributorsByDate: groupedContributors,
            symptomsByDate: [:]
        )

        XCTAssertEqual(scores.count, 3) // 3 days
        XCTAssertGreaterThan(scores[1].decayedLoad, scores[0].rawLoad) // Day 2 includes decayed Day 1
    }
}