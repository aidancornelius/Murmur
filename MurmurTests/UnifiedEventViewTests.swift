//
//  UnifiedEventViewTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 12/10/2025.
//

import CoreData
import XCTest
@testable import Murmur

final class UnifiedEventViewTests: XCTestCase {
    var testStack: InMemoryCoreDataStack?

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
    }

    override func tearDown() {
        testStack = nil
        super.tearDown()
    }

    // MARK: - Sleep Suggestion Logic Tests

    func testSleepSuggestionBetween5And8AM() throws {
        // Test that sleep is suggested between 5am and 8am
        let calendar = Calendar.current

        // Test at 5am
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 5
        components.minute = 0
        let fiveAM = calendar.date(from: components)!

        XCTAssertTrue(shouldSuggestSleep(at: fiveAM))

        // Test at 7am
        components.hour = 7
        components.minute = 30
        let sevenThirtyAM = calendar.date(from: components)!

        XCTAssertTrue(shouldSuggestSleep(at: sevenThirtyAM))
    }

    func testNoSleepSuggestionAt9AM() throws {
        // Test that sleep is not suggested at 9am
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        let nineAM = calendar.date(from: components)!

        XCTAssertFalse(shouldSuggestSleep(at: nineAM))
    }

    func testSleepSuggestionAfter9PM() throws {
        // Test that sleep is suggested after 9pm
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 22
        components.minute = 0
        let tenPM = calendar.date(from: components)!

        XCTAssertTrue(shouldSuggestSleep(at: tenPM))

        // Test at midnight
        components.hour = 0
        components.minute = 0
        let midnight = calendar.date(from: components)!

        XCTAssertTrue(shouldSuggestSleep(at: midnight))
    }

    func testNoSleepSuggestionAfterRecentSleep() throws {
        // Create a recent sleep event (within 12 hours)
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date().addingTimeInterval(-3600) // 1 hour ago
        sleep.bedTime = Date().addingTimeInterval(-10 * 3600)
        sleep.wakeTime = Date().addingTimeInterval(-2 * 3600)
        sleep.quality = 3

        try testStack!.context.save()

        // Even during suggested hours, should not suggest if recent sleep exists
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 6
        components.minute = 0
        let sixAM = calendar.date(from: components)!

        XCTAssertFalse(shouldSuggestSleep(at: sixAM, context: testStack!.context))
    }

    func testSleepSuggestionWhenNoRecentSleep() throws {
        // No recent sleep events exist
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 6
        components.minute = 0
        let sixAM = calendar.date(from: components)!

        XCTAssertTrue(shouldSuggestSleep(at: sixAM, context: testStack!.context))
    }

    func testSleepSuggestionAfterOldSleep() throws {
        // Create an old sleep event (more than 12 hours ago)
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date().addingTimeInterval(-13 * 3600) // 13 hours ago
        sleep.bedTime = Date().addingTimeInterval(-24 * 3600)
        sleep.wakeTime = Date().addingTimeInterval(-16 * 3600)
        sleep.quality = 3

        try testStack!.context.save()

        // Should suggest sleep since last sleep is old
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 6
        components.minute = 0
        let sixAM = calendar.date(from: components)!

        XCTAssertTrue(shouldSuggestSleep(at: sixAM, context: testStack!.context))
    }

    // MARK: - Meal Entry Exertion Tests

    func testMealWithExertionToggleEnabled() throws {
        // Simulate saving a meal with showMealExertion = true
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "lunch"
        meal.mealDescription = "Heavy meal"

        // Simulate user toggling on exertion
        let showMealExertion = true
        if showMealExertion {
            meal.physicalExertion = NSNumber(value: 4)
            meal.cognitiveExertion = NSNumber(value: 3)
            meal.emotionalLoad = NSNumber(value: 2)
        }

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNotNil(fetched.physicalExertion)
        XCTAssertNotNil(fetched.cognitiveExertion)
        XCTAssertNotNil(fetched.emotionalLoad)
        XCTAssertEqual(fetched.physicalExertion?.intValue, 4)
        XCTAssertEqual(fetched.cognitiveExertion?.intValue, 3)
        XCTAssertEqual(fetched.emotionalLoad?.intValue, 2)
    }

    func testMealWithExertionToggleDisabled() throws {
        // Simulate saving a meal with showMealExertion = false
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "snack"
        meal.mealDescription = "Light snack"

        // Simulate user not toggling on exertion
        let showMealExertion = false
        if showMealExertion {
            meal.physicalExertion = NSNumber(value: 3)
            meal.cognitiveExertion = NSNumber(value: 3)
            meal.emotionalLoad = NSNumber(value: 3)
        }

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNil(fetched.physicalExertion)
        XCTAssertNil(fetched.cognitiveExertion)
        XCTAssertNil(fetched.emotionalLoad)
    }

    func testMealExertionCanBeToggledOn() throws {
        // Create a meal without exertion
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Toast"

        try testStack!.context.save()

        // Now simulate user toggling on exertion
        meal.physicalExertion = NSNumber(value: 2)
        meal.cognitiveExertion = NSNumber(value: 2)
        meal.emotionalLoad = NSNumber(value: 2)

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNotNil(fetched.physicalExertion)
        XCTAssertEqual(fetched.physicalExertion?.intValue, 2)
    }

    func testMealExertionCanBeToggledOff() throws {
        // Create a meal with exertion
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "dinner"
        meal.mealDescription = "Pasta"
        meal.physicalExertion = NSNumber(value: 4)
        meal.cognitiveExertion = NSNumber(value: 3)
        meal.emotionalLoad = NSNumber(value: 3)

        try testStack!.context.save()

        // Now simulate user toggling off exertion
        meal.physicalExertion = nil
        meal.cognitiveExertion = nil
        meal.emotionalLoad = nil

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNil(fetched.physicalExertion)
        XCTAssertNil(fetched.cognitiveExertion)
        XCTAssertNil(fetched.emotionalLoad)
    }

    func testMealExertionDefaultValues() throws {
        // Test that default exertion values are 3 when first toggled on
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "lunch"
        meal.mealDescription = "Sandwich"

        // Simulate initial toggle with default values
        meal.physicalExertion = NSNumber(value: 3)
        meal.cognitiveExertion = NSNumber(value: 3)
        meal.emotionalLoad = NSNumber(value: 3)

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.physicalExertion?.intValue, 3)
        XCTAssertEqual(fetched.cognitiveExertion?.intValue, 3)
        XCTAssertEqual(fetched.emotionalLoad?.intValue, 3)
    }

    // MARK: - Integration Tests

    func testFullMealFlowWithExertion() throws {
        // Simulate the full flow of creating a meal with exertion
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date()
        meal.mealType = "dinner"
        meal.mealDescription = "Large dinner with dessert"
        meal.note = "Felt very full"
        meal.physicalExertion = NSNumber(value: 5)
        meal.cognitiveExertion = NSNumber(value: 4)
        meal.emotionalLoad = NSNumber(value: 3)

        try testStack!.context.save()

        // Verify all data persists correctly
        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.mealType, "dinner")
        XCTAssertEqual(fetched.mealDescription, "Large dinner with dessert")
        XCTAssertEqual(fetched.note, "Felt very full")
        XCTAssertEqual(fetched.physicalExertion?.intValue, 5)
        XCTAssertEqual(fetched.cognitiveExertion?.intValue, 4)
        XCTAssertEqual(fetched.emotionalLoad?.intValue, 3)
        XCTAssertNotNil(fetched.createdAt)
        XCTAssertNotNil(fetched.backdatedAt)
    }

    func testBackwardsCompatibilityOldMealsDisplay() throws {
        // Test that old meals (without exertion) still display correctly
        let oldMeal = MealEvent(context: testStack!.context)
        oldMeal.id = UUID()
        oldMeal.createdAt = Date().addingTimeInterval(-86400) // 1 day ago
        oldMeal.mealType = "breakfast"
        oldMeal.mealDescription = "Old breakfast entry"
        // No exertion values

        let newMeal = MealEvent(context: testStack!.context)
        newMeal.id = UUID()
        newMeal.createdAt = Date()
        newMeal.mealType = "lunch"
        newMeal.mealDescription = "New lunch entry"
        newMeal.physicalExertion = NSNumber(value: 3)
        newMeal.cognitiveExertion = NSNumber(value: 3)
        newMeal.emotionalLoad = NSNumber(value: 3)

        try testStack!.context.save()

        let request = MealEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: false)]
        let meals = try testStack!.context.fetch(request)

        XCTAssertEqual(meals.count, 2)

        // Verify new meal has exertion
        XCTAssertNotNil(meals[0].physicalExertion)

        // Verify old meal has no exertion but still displays correctly
        XCTAssertNil(meals[1].physicalExertion)
        XCTAssertEqual(meals[1].mealDescription, "Old breakfast entry")
    }

    // MARK: - Helper Functions

    private func shouldSuggestSleep(at date: Date, context: NSManagedObjectContext? = nil) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // Check time-based suggestion
        // Suggest sleep: 9pm-5am (21:00-05:00) OR 5am-8am (05:00-08:00)
        let shouldSuggestBasedOnTime = (hour >= 5 && hour < 8) || hour >= 21 || hour < 5

        guard shouldSuggestBasedOnTime else {
            return false
        }

        // Check if there's recent sleep
        if let context = context {
            return !hasSleepInLast12Hours(context: context)
        }

        return true
    }

    private func hasSleepInLast12Hours(context: NSManagedObjectContext) -> Bool {
        let request = SleepEvent.fetchRequest()
        let twelveHoursAgo = Date().addingTimeInterval(-12 * 3600)
        request.predicate = NSPredicate(
            format: "createdAt >= %@",
            twelveHoursAgo as NSDate
        )
        request.fetchLimit = 1

        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }
}
