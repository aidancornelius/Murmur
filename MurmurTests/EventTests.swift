//
//  EventTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 05/10/2025.
//

import CoreData
import XCTest
@testable import Murmur

final class EventTests: XCTestCase {
    var testStack: InMemoryCoreDataStack!

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
    }

    override func tearDown() {
        testStack = nil
        super.tearDown()
    }

    // MARK: - ActivityEvent Tests

    func testCreateActivityEvent() throws {
        let activity = ActivityEvent(context: testStack.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Morning walk"
        activity.note = "Felt good"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 2
        activity.emotionalLoad = 1
        activity.durationMinutes = NSNumber(value: 30)

        try testStack.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack.context))
        XCTAssertEqual(fetched.name, "Morning walk")
        XCTAssertEqual(fetched.note, "Felt good")
        XCTAssertEqual(fetched.physicalExertion, 3)
        XCTAssertEqual(fetched.cognitiveExertion, 2)
        XCTAssertEqual(fetched.emotionalLoad, 1)
        XCTAssertEqual(fetched.durationMinutes?.intValue, 30)
    }

    func testActivityEventWithBackdatedAt() throws {
        let backdatedTime = Date().addingTimeInterval(-3600) // 1 hour ago

        let activity = ActivityEvent(context: testStack.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = backdatedTime
        activity.name = "Lunch meeting"
        activity.physicalExertion = 1
        activity.cognitiveExertion = 4
        activity.emotionalLoad = 3

        try testStack.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack.context))
        XCTAssertNotNil(fetched.backdatedAt)
        XCTAssertEqual(fetched.backdatedAt, backdatedTime)
    }

    func testActivityEventWithCalendarID() throws {
        let activity = ActivityEvent(context: testStack.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Team standup"
        activity.calendarEventID = "calendar-event-123"
        activity.physicalExertion = 1
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 2

        try testStack.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack.context))
        XCTAssertEqual(fetched.calendarEventID, "calendar-event-123")
    }

    // MARK: - SleepEvent Tests

    func testCreateSleepEvent() throws {
        let bedTime = Date().addingTimeInterval(-8 * 3600) // 8 hours ago
        let wakeTime = Date()

        let sleep = SleepEvent(context: testStack.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = bedTime
        sleep.wakeTime = wakeTime
        sleep.quality = 4
        sleep.note = "Slept well"

        try testStack.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack.context))
        XCTAssertEqual(fetched.bedTime, bedTime)
        XCTAssertEqual(fetched.wakeTime, wakeTime)
        XCTAssertEqual(fetched.quality, 4)
        XCTAssertEqual(fetched.note, "Slept well")
    }

    func testSleepEventQualityRange() throws {
        // Test minimum quality
        let sleepMin = SleepEvent(context: testStack.context)
        sleepMin.id = UUID()
        sleepMin.createdAt = Date()
        sleepMin.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleepMin.wakeTime = Date()
        sleepMin.quality = 1

        // Test maximum quality
        let sleepMax = SleepEvent(context: testStack.context)
        sleepMax.id = UUID()
        sleepMax.createdAt = Date()
        sleepMax.bedTime = Date().addingTimeInterval(-7 * 3600)
        sleepMax.wakeTime = Date()
        sleepMax.quality = 5

        try testStack.context.save()

        let request = SleepEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepEvent.quality, ascending: true)]
        let fetched = try testStack.context.fetch(request)

        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched.first?.quality, 1)
        XCTAssertEqual(fetched.last?.quality, 5)
    }

    func testSleepEventWithHealthKitData() throws {
        let sleep = SleepEvent(context: testStack.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 3
        sleep.hkSleepHours = NSNumber(value: 7.5)
        sleep.hkHRV = NSNumber(value: 45.2)
        sleep.hkRestingHR = NSNumber(value: 58.0)

        try testStack.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack.context))
        XCTAssertEqual(fetched.hkSleepHours?.doubleValue, 7.5)
        XCTAssertEqual(fetched.hkHRV?.doubleValue, 45.2)
        XCTAssertEqual(fetched.hkRestingHR?.doubleValue, 58.0)
    }

    func testSleepEventWithSymptoms() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        // Fetch some symptom types
        let symptomRequest = SymptomType.fetchRequest()
        symptomRequest.fetchLimit = 3
        let symptoms = try testStack.context.fetch(symptomRequest)
        XCTAssertGreaterThanOrEqual(symptoms.count, 3)

        let sleep = SleepEvent(context: testStack.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 2
        sleep.note = "Restless night with symptoms"

        // Add symptoms
        for symptom in symptoms {
            sleep.addToSymptoms(symptom)
        }

        try testStack.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack.context))
        XCTAssertEqual(fetched.symptoms?.count, 3)

        // Verify bidirectional relationship
        let firstSymptom = symptoms.first!
        XCTAssertTrue((firstSymptom.sleepEvents?.contains(fetched)) ?? false)
    }

    func testSleepEventMaxFiveSymptoms() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        let symptomRequest = SymptomType.fetchRequest()
        symptomRequest.fetchLimit = 5
        let symptoms = try testStack.context.fetch(symptomRequest)

        let sleep = SleepEvent(context: testStack.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 3

        // Add exactly 5 symptoms (max allowed in UI)
        for symptom in symptoms.prefix(5) {
            sleep.addToSymptoms(symptom)
        }

        try testStack.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack.context))
        XCTAssertEqual(fetched.symptoms?.count, 5)
    }

    func testSleepEventRemoveSymptom() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        let symptom = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))

        let sleep = SleepEvent(context: testStack.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 3
        sleep.addToSymptoms(symptom)

        try testStack.context.save()

        XCTAssertEqual(sleep.symptoms?.count, 1)

        // Remove symptom
        sleep.removeFromSymptoms(symptom)
        try testStack.context.save()

        XCTAssertEqual(sleep.symptoms?.count, 0)
    }

    func testSleepEventBackdatedAt() throws {
        let bedTime = Date().addingTimeInterval(-10 * 3600) // 10 hours ago

        let sleep = SleepEvent(context: testStack.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.backdatedAt = bedTime
        sleep.bedTime = bedTime
        sleep.wakeTime = Date().addingTimeInterval(-2 * 3600)
        sleep.quality = 3

        try testStack.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack.context))
        XCTAssertEqual(fetched.backdatedAt, bedTime)
    }

    // MARK: - MealEvent Tests

    func testCreateMealEvent() throws {
        let meal = MealEvent(context: testStack.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date().addingTimeInterval(-1800) // 30 minutes ago
        meal.mealType = "lunch"
        meal.mealDescription = "Chicken salad with quinoa"
        meal.note = "Felt satisfied"

        try testStack.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack.context))
        XCTAssertEqual(fetched.mealType, "lunch")
        XCTAssertEqual(fetched.mealDescription, "Chicken salad with quinoa")
        XCTAssertEqual(fetched.note, "Felt satisfied")
    }

    func testMealEventTypes() throws {
        let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

        for (index, type) in mealTypes.enumerated() {
            let meal = MealEvent(context: testStack.context)
            meal.id = UUID()
            meal.createdAt = Date()
            meal.mealType = type
            meal.mealDescription = "Test \(type)"
        }

        try testStack.context.save()

        let request = MealEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: true)]
        let meals = try testStack.context.fetch(request)

        XCTAssertEqual(meals.count, 4)
        XCTAssertEqual(meals[0].mealType, "breakfast")
        XCTAssertEqual(meals[1].mealType, "lunch")
        XCTAssertEqual(meals[2].mealType, "dinner")
        XCTAssertEqual(meals[3].mealType, "snack")
    }

    func testMealEventWithBackdatedTime() throws {
        let mealTime = Date().addingTimeInterval(-3600) // 1 hour ago

        let meal = MealEvent(context: testStack.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = mealTime
        meal.mealType = "breakfast"
        meal.mealDescription = "Oatmeal with berries"

        try testStack.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack.context))
        XCTAssertEqual(fetched.backdatedAt, mealTime)
        XCTAssertNotEqual(fetched.backdatedAt, fetched.createdAt)
    }

    func testMealEventWithoutNote() throws {
        let meal = MealEvent(context: testStack.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "snack"
        meal.mealDescription = "Apple"
        // Note is intentionally nil

        try testStack.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack.context))
        XCTAssertNil(fetched.note)
        XCTAssertEqual(fetched.mealDescription, "Apple")
    }

    // MARK: - Integration Tests

    func testMultipleEventTypesCoexist() throws {
        // Create one of each event type
        let activity = ActivityEvent(context: testStack.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Gym workout"
        activity.physicalExertion = 4
        activity.cognitiveExertion = 2
        activity.emotionalLoad = 2

        let sleep = SleepEvent(context: testStack.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 4

        let meal = MealEvent(context: testStack.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Scrambled eggs"

        try testStack.context.save()

        // Verify each type exists independently
        let activities = try testStack.context.fetch(ActivityEvent.fetchRequest())
        let sleeps = try testStack.context.fetch(SleepEvent.fetchRequest())
        let meals = try testStack.context.fetch(MealEvent.fetchRequest())

        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(sleeps.count, 1)
        XCTAssertEqual(meals.count, 1)
    }

    func testEventsSortByCreatedAt() throws {
        let now = Date()

        let activity1 = ActivityEvent(context: testStack.context)
        activity1.id = UUID()
        activity1.createdAt = now.addingTimeInterval(-3600)
        activity1.name = "Morning activity"
        activity1.physicalExertion = 3
        activity1.cognitiveExertion = 3
        activity1.emotionalLoad = 3

        let sleep = SleepEvent(context: testStack.context)
        sleep.id = UUID()
        sleep.createdAt = now.addingTimeInterval(-7200)
        sleep.bedTime = now.addingTimeInterval(-10 * 3600)
        sleep.wakeTime = now.addingTimeInterval(-2 * 3600)
        sleep.quality = 3

        let meal = MealEvent(context: testStack.context)
        meal.id = UUID()
        meal.createdAt = now
        meal.mealType = "lunch"
        meal.mealDescription = "Sandwich"

        try testStack.context.save()

        // Fetch activities sorted by createdAt
        let activityRequest = ActivityEvent.fetchRequest()
        activityRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ActivityEvent.createdAt, ascending: false)]
        let activities = try testStack.context.fetch(activityRequest)

        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities.first?.name, "Morning activity")
    }

    func testDeleteSleepEventMaintainsSymptoms() throws {
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)

        let symptom = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))

        let sleep = SleepEvent(context: testStack.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 3
        sleep.addToSymptoms(symptom)

        try testStack.context.save()

        // Delete sleep event
        testStack.context.delete(sleep)
        try testStack.context.save()

        // Symptom should still exist (nullify deletion rule)
        let fetchedSymptom = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        XCTAssertEqual(fetchedSymptom.id, symptom.id)
    }

    func testEventCreatedAtNotNil() throws {
        let activity = ActivityEvent(context: testStack.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        let sleep = SleepEvent(context: testStack.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date()
        sleep.wakeTime = Date()
        sleep.quality = 3

        let meal = MealEvent(context: testStack.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Test"

        try testStack.context.save()

        let fetchedActivity = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack.context))
        let fetchedSleep = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack.context))
        let fetchedMeal = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack.context))

        XCTAssertNotNil(fetchedActivity.createdAt)
        XCTAssertNotNil(fetchedSleep.createdAt)
        XCTAssertNotNil(fetchedMeal.createdAt)
    }
}
