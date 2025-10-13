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

    // MARK: - Activity Event Tests

    func testSaveBasicActivity() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()
        activity.name = "Running"
        activity.physicalExertion = 5
        activity.cognitiveExertion = 2
        activity.emotionalLoad = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.name, "Running")
        XCTAssertEqual(fetched.physicalExertion, 5)
        XCTAssertEqual(fetched.cognitiveExertion, 2)
        XCTAssertEqual(fetched.emotionalLoad, 3)
        XCTAssertNotNil(fetched.id)
        XCTAssertNotNil(fetched.createdAt)
        XCTAssertNotNil(fetched.backdatedAt)
    }

    func testActivityWithDuration() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()
        activity.name = "Cycling"
        activity.durationMinutes = NSNumber(value: 45)
        activity.physicalExertion = 4
        activity.cognitiveExertion = 2
        activity.emotionalLoad = 2

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.durationMinutes?.intValue, 45)
        XCTAssertEqual(fetched.name, "Cycling")
    }

    func testActivityWithNote() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()
        activity.name = "Yoga"
        activity.note = "Morning session, felt good"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 2

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.note, "Morning session, felt good")
    }

    func testActivityWithCalendarEvent() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()
        activity.name = "Team meeting"
        activity.calendarEventID = "test-calendar-id-123"
        activity.physicalExertion = 1
        activity.cognitiveExertion = 4
        activity.emotionalLoad = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.calendarEventID, "test-calendar-id-123")
    }

    func testActivityWithBackdatedTimestamp() throws {
        let yesterday = Date().addingTimeInterval(-86400)
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = yesterday
        activity.name = "Swimming"
        activity.physicalExertion = 5
        activity.cognitiveExertion = 2
        activity.emotionalLoad = 2

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNotEqual(fetched.createdAt, fetched.backdatedAt)
        XCTAssertTrue(fetched.backdatedAt! < fetched.createdAt!)
    }

    func testMultipleActivitiesCanExist() throws {
        let activity1 = ActivityEvent(context: testStack!.context)
        activity1.id = UUID()
        activity1.createdAt = Date()
        activity1.backdatedAt = Date()
        activity1.name = "Walking"
        activity1.physicalExertion = 2

        let activity2 = ActivityEvent(context: testStack!.context)
        activity2.id = UUID()
        activity2.createdAt = Date()
        activity2.backdatedAt = Date()
        activity2.name = "Reading"
        activity2.cognitiveExertion = 4

        try testStack!.context.save()

        let request = ActivityEvent.fetchRequest()
        let activities = try testStack!.context.fetch(request)
        XCTAssertEqual(activities.count, 2)
    }

    // MARK: - Sleep Event Tests

    func testSaveBasicSleep() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.backdatedAt = sleep.bedTime
        sleep.quality = 4

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.quality, 4)
        XCTAssertNotNil(fetched.bedTime)
        XCTAssertNotNil(fetched.wakeTime)
        XCTAssertNotNil(fetched.id)
    }

    func testSleepWithNote() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.backdatedAt = sleep.bedTime
        sleep.quality = 3
        sleep.note = "Woke up several times during the night"

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.note, "Woke up several times during the night")
    }

    func testSleepWithHealthKitData() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.backdatedAt = sleep.bedTime
        sleep.quality = 4
        sleep.hkSleepHours = NSNumber(value: 7.5)
        sleep.hkHRV = NSNumber(value: 45.2)
        sleep.hkRestingHR = NSNumber(value: 58)

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.hkSleepHours?.doubleValue ?? 0, 7.5, accuracy: 0.01)
        XCTAssertEqual(fetched.hkHRV?.doubleValue ?? 0, 45.2, accuracy: 0.01)
        XCTAssertEqual(fetched.hkRestingHR?.intValue, 58)
    }

    func testSleepDurationCalculation() throws {
        let bedTime = Date().addingTimeInterval(-8 * 3600)
        let wakeTime = Date()

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = bedTime
        sleep.wakeTime = wakeTime
        sleep.backdatedAt = bedTime
        sleep.quality = 4

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        let duration = fetched.wakeTime!.timeIntervalSince(fetched.bedTime!)
        let hours = duration / 3600
        XCTAssertEqual(hours, 8.0, accuracy: 0.1)
    }

    func testSleepQualityRange() throws {
        // Test quality values 1-5
        for quality in 1...5 {
            let sleep = SleepEvent(context: testStack!.context)
            sleep.id = UUID()
            sleep.createdAt = Date()
            sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
            sleep.wakeTime = Date()
            sleep.backdatedAt = sleep.bedTime
            sleep.quality = Int16(quality)

            try testStack!.context.save()
            testStack!.context.delete(sleep)
        }
    }

    func testSleepBackdatedToBedTime() throws {
        let bedTime = Date().addingTimeInterval(-10 * 3600)
        let wakeTime = Date().addingTimeInterval(-2 * 3600)

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = bedTime
        sleep.wakeTime = wakeTime
        sleep.backdatedAt = bedTime
        sleep.quality = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.backdatedAt, fetched.bedTime)
    }

    // MARK: - Meal Type Tests

    func testMealTypeBreakfast() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Oatmeal with berries"

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.mealType, "breakfast")
    }

    func testMealTypeLunch() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date()
        meal.mealType = "lunch"
        meal.mealDescription = "Chicken salad"

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.mealType, "lunch")
    }

    func testMealTypeDinner() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date()
        meal.mealType = "dinner"
        meal.mealDescription = "Grilled fish with vegetables"

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.mealType, "dinner")
    }

    func testMealTypeSnack() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date()
        meal.mealType = "snack"
        meal.mealDescription = "Apple and nuts"

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.mealType, "snack")
    }

    func testMealWithTimestamp() throws {
        let lunchTime = Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date())!
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = lunchTime
        meal.mealType = "lunch"
        meal.mealDescription = "Sandwich"

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        let hour = Calendar.current.component(.hour, from: fetched.backdatedAt!)
        XCTAssertEqual(hour, 12)
    }

    // MARK: - Data Validation Tests

    func testActivityRequiresName() throws {
        // ActivityEvent validation requires a name
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()
        // Intentionally not setting name
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        // This should throw an error due to Core Data validation
        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSCocoaErrorDomain)
            XCTAssertEqual(nsError.code, 1570) // Core Data validation error
            XCTAssertTrue(nsError.localizedDescription.contains("name"), "Error should mention 'name' field")
        }
    }

    func testSleepRequiresBedAndWakeTimes() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.backdatedAt = sleep.bedTime
        sleep.quality = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNotNil(fetched.bedTime)
        XCTAssertNotNil(fetched.wakeTime)
    }

    func testMealRequiresDescription() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Toast"

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNotNil(fetched.mealDescription)
        XCTAssertFalse(fetched.mealDescription!.isEmpty)
    }

    func testDurationMustBePositive() throws {
        // Test that duration values are sensible
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()
        activity.name = "Walking"
        activity.durationMinutes = NSNumber(value: 30)
        activity.physicalExertion = 2

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertGreaterThan(fetched.durationMinutes!.intValue, 0)
    }

    func testExertionRangeValidation() throws {
        // Exertion values should be 1-5
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 5
        activity.cognitiveExertion = 1
        activity.emotionalLoad = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertGreaterThanOrEqual(fetched.physicalExertion, 1)
        XCTAssertLessThanOrEqual(fetched.physicalExertion, 5)
        XCTAssertGreaterThanOrEqual(fetched.cognitiveExertion, 1)
        XCTAssertLessThanOrEqual(fetched.cognitiveExertion, 5)
        XCTAssertGreaterThanOrEqual(fetched.emotionalLoad, 1)
        XCTAssertLessThanOrEqual(fetched.emotionalLoad, 5)
    }

    // MARK: - Edge Cases

    func testEmptyNoteNotSaved() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()
        activity.name = "Running"
        activity.note = "   "  // Whitespace only
        activity.physicalExertion = 4

        // Simulate the view's logic for trimming empty notes
        if activity.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            activity.note = nil
        }

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNil(fetched.note)
    }

    func testWakeTimeBeforeBedTimeThrowsError() throws {
        // Test that validation prevents wake time before bed time
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date()
        sleep.wakeTime = Date().addingTimeInterval(-8 * 3600)
        sleep.backdatedAt = sleep.bedTime
        sleep.quality = 2

        // This should throw an error due to validation
        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "SleepEvent")
            XCTAssertEqual(nsError.code, 5004)
            XCTAssertEqual(nsError.localizedDescription, "Wake time must be after bed time")
        }
    }

    func testLongActivityDescription() throws {
        let longDescription = String(repeating: "A very long activity description ", count: 100)
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()
        activity.name = longDescription
        activity.physicalExertion = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.name, longDescription)
    }

    func testMealDescriptionFallbackToType() throws {
        // Simulate view logic: if description is empty, fall back to meal type
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date()
        meal.mealType = "breakfast"

        // Simulate the fallback logic from saveMeal()
        let trimmedInput = ""
        if !trimmedInput.isEmpty {
            meal.mealDescription = trimmedInput
        } else {
            meal.mealDescription = meal.mealType?.capitalized
        }

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.mealDescription, "Breakfast")
    }

    func testMultipleSleepsInOneDay() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Night sleep (last night into this morning)
        let nightSleep = SleepEvent(context: testStack!.context)
        nightSleep.id = UUID()
        nightSleep.createdAt = today.addingTimeInterval(-16 * 3600) // Yesterday 8am
        nightSleep.bedTime = today.addingTimeInterval(-26 * 3600) // Yesterday 10pm
        nightSleep.wakeTime = today.addingTimeInterval(-18 * 3600) // Yesterday 6am
        nightSleep.backdatedAt = nightSleep.bedTime
        nightSleep.quality = 4

        // Afternoon nap
        let napSleep = SleepEvent(context: testStack!.context)
        napSleep.id = UUID()
        napSleep.createdAt = today.addingTimeInterval(-9 * 3600) // Yesterday 3pm
        napSleep.bedTime = today.addingTimeInterval(-10 * 3600) // Yesterday 2pm
        napSleep.wakeTime = today.addingTimeInterval(-9 * 3600) // Yesterday 3pm
        napSleep.backdatedAt = napSleep.bedTime
        napSleep.quality = 3

        try testStack!.context.save()

        let request = SleepEvent.fetchRequest()
        let sleeps = try testStack!.context.fetch(request)
        XCTAssertEqual(sleeps.count, 2)
    }

    func testFutureTimestamp() throws {
        // Test that future timestamps can be set (though UI might warn)
        let tomorrow = Date().addingTimeInterval(86400)
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = tomorrow
        activity.name = "Future planning"
        activity.physicalExertion = 2

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertGreaterThan(fetched.backdatedAt!, Date())
    }

    // MARK: - Time Chip Functionality Tests

    func testTimeChipNowValue() {
        let now = Date()
        let timeChipDate = getTimeChipDate(for: .now)
        let difference = abs(timeChipDate.timeIntervalSince(now))
        XCTAssertLessThan(difference, 1.0)  // Within 1 second
    }

    func testTimeChipThirtyMinAgo() {
        let thirtyMinAgo = Date().addingTimeInterval(-30 * 60)
        let timeChipDate = getTimeChipDate(for: .thirtyMin)
        let difference = abs(timeChipDate.timeIntervalSince(thirtyMinAgo))
        XCTAssertLessThan(difference, 60.0)  // Within 1 minute
    }

    func testTimeChipOneHourAgo() {
        let oneHourAgo = Date().addingTimeInterval(-60 * 60)
        let timeChipDate = getTimeChipDate(for: .oneHour)
        let difference = abs(timeChipDate.timeIntervalSince(oneHourAgo))
        XCTAssertLessThan(difference, 60.0)
    }

    func testTimeChipTwoHoursAgo() {
        let twoHoursAgo = Date().addingTimeInterval(-2 * 60 * 60)
        let timeChipDate = getTimeChipDate(for: .twoHours)
        let difference = abs(timeChipDate.timeIntervalSince(twoHoursAgo))
        XCTAssertLessThan(difference, 60.0)
    }

    func testTimeChipMorning() {
        let timeChipDate = getTimeChipDate(for: .morning)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timeChipDate)
        XCTAssertEqual(hour, 8)
    }

    func testTimeChipYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let timeChipDate = getTimeChipDate(for: .yesterday)
        let calendar = Calendar.current
        let chipDay = calendar.component(.day, from: timeChipDate)
        let expectedDay = calendar.component(.day, from: yesterday)
        XCTAssertEqual(chipDay, expectedDay)
    }

    // MARK: - Duration Chip Tests

    func testDurationChipFifteenMinutes() {
        XCTAssertEqual(getDurationChipMinutes(for: .fifteen), 15)
    }

    func testDurationChipThirtyMinutes() {
        XCTAssertEqual(getDurationChipMinutes(for: .thirty), 30)
    }

    func testDurationChipFortyFiveMinutes() {
        XCTAssertEqual(getDurationChipMinutes(for: .fortyfive), 45)
    }

    func testDurationChipSixtyMinutes() {
        XCTAssertEqual(getDurationChipMinutes(for: .sixty), 60)
    }

    func testDurationChipNinetyMinutes() {
        XCTAssertEqual(getDurationChipMinutes(for: .ninety), 90)
    }

    func testDurationChipTwoHours() {
        XCTAssertEqual(getDurationChipMinutes(for: .twoHours), 120)
    }

    // MARK: - Combined Note Tests

    func testSleepCombinesInputAndNote() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.backdatedAt = sleep.bedTime
        sleep.quality = 3

        // Simulate the view's logic for combining input and note
        let trimmedInput = "Restless sleep"
        let trimmedNote = "Multiple wake-ups"

        if !trimmedInput.isEmpty && !trimmedNote.isEmpty {
            sleep.note = "\(trimmedInput)\n\n\(trimmedNote)"
        }

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.note, "Restless sleep\n\nMultiple wake-ups")
    }

    func testSleepWithOnlyInputNote() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.backdatedAt = sleep.bedTime
        sleep.quality = 4

        let trimmedInput = "Great sleep"
        let trimmedNote = ""

        if !trimmedInput.isEmpty && !trimmedNote.isEmpty {
            sleep.note = "\(trimmedInput)\n\n\(trimmedNote)"
        } else if !trimmedInput.isEmpty {
            sleep.note = trimmedInput
        }

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.note, "Great sleep")
    }

    func testSleepWithOnlyNoteField() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.backdatedAt = sleep.bedTime
        sleep.quality = 3

        let trimmedInput = ""
        let trimmedNote = "Woke up at 3am"

        if !trimmedInput.isEmpty && !trimmedNote.isEmpty {
            sleep.note = "\(trimmedInput)\n\n\(trimmedNote)"
        } else if !trimmedNote.isEmpty {
            sleep.note = trimmedNote
        }

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.note, "Woke up at 3am")
    }

    // MARK: - Default Value Tests

    func testDefaultSleepTimesLogic() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Default bed time: yesterday 10pm
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let defaultBedTime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: yesterday)!

        // Default wake time: today 7am
        let defaultWakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today)!

        let bedHour = calendar.component(.hour, from: defaultBedTime)
        let wakeHour = calendar.component(.hour, from: defaultWakeTime)

        XCTAssertEqual(bedHour, 22)
        XCTAssertEqual(wakeHour, 7)
    }

    func testDefaultExertionValues() throws {
        // Default values should be 3 (middle of 1-5 scale)
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.physicalExertion, 3)
        XCTAssertEqual(fetched.cognitiveExertion, 3)
        XCTAssertEqual(fetched.emotionalLoad, 3)
    }

    func testDefaultSleepQuality() throws {
        // Default sleep quality should be 3
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.backdatedAt = sleep.bedTime
        sleep.quality = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.quality, 3)
    }

    func testDefaultMealType() throws {
        // Default meal type should be "breakfast"
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Default breakfast"

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.mealType, "breakfast")
    }

    // MARK: - Activity Name Fallback Tests

    func testActivityNameFromParsedData() throws {
        // Simulate using parsed cleaned text as name
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()

        let parsedText = "Running in the park"
        activity.name = parsedText
        activity.physicalExertion = 4

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.name, "Running in the park")
    }

    func testActivityNameFallback() throws {
        // When no parsed data and no input, fall back to "Activity"
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = Date()
        activity.name = "Activity"  // Fallback value
        activity.physicalExertion = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.name, "Activity")
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

    // Helper to simulate TimeChip enum behaviour
    private enum TimeChipTest: String {
        case now, thirtyMin, oneHour, twoHours, morning, yesterday
    }

    private func getTimeChipDate(for chip: TimeChipTest) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch chip {
        case .now:
            return now
        case .thirtyMin:
            return now.addingTimeInterval(-30 * 60)
        case .oneHour:
            return now.addingTimeInterval(-60 * 60)
        case .twoHours:
            return now.addingTimeInterval(-2 * 60 * 60)
        case .morning:
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = 8
            components.minute = 0
            return calendar.date(from: components) ?? now
        case .yesterday:
            return calendar.date(byAdding: .day, value: -1, to: now) ?? now
        }
    }

    private enum DurationChipTest: String {
        case fifteen, thirty, fortyfive, sixty, ninety, twoHours
    }

    private func getDurationChipMinutes(for chip: DurationChipTest) -> Int {
        switch chip {
        case .fifteen: return 15
        case .thirty: return 30
        case .fortyfive: return 45
        case .sixty: return 60
        case .ninety: return 90
        case .twoHours: return 120
        }
    }
}
