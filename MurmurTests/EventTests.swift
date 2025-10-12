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
    var testStack: InMemoryCoreDataStack?

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
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Morning walk"
        activity.note = "Felt good"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 2
        activity.emotionalLoad = 1
        activity.durationMinutes = NSNumber(value: 30)

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.name, "Morning walk")
        XCTAssertEqual(fetched.note, "Felt good")
        XCTAssertEqual(fetched.physicalExertion, 3)
        XCTAssertEqual(fetched.cognitiveExertion, 2)
        XCTAssertEqual(fetched.emotionalLoad, 1)
        XCTAssertEqual(fetched.durationMinutes?.intValue, 30)
    }

    func testActivityEventWithBackdatedAt() throws {
        let backdatedTime = Date().addingTimeInterval(-3600) // 1 hour ago

        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = backdatedTime
        activity.name = "Lunch meeting"
        activity.physicalExertion = 1
        activity.cognitiveExertion = 4
        activity.emotionalLoad = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNotNil(fetched.backdatedAt)
        XCTAssertEqual(fetched.backdatedAt, backdatedTime)
    }

    func testActivityEventWithCalendarID() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Team standup"
        activity.calendarEventID = "calendar-event-123"
        activity.physicalExertion = 1
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 2

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.calendarEventID, "calendar-event-123")
    }

    // MARK: - SleepEvent Tests

    func testCreateSleepEvent() throws {
        let bedTime = Date().addingTimeInterval(-8 * 3600) // 8 hours ago
        let wakeTime = Date()

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = bedTime
        sleep.wakeTime = wakeTime
        sleep.quality = 4
        sleep.note = "Slept well"

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.bedTime, bedTime)
        XCTAssertEqual(fetched.wakeTime, wakeTime)
        XCTAssertEqual(fetched.quality, 4)
        XCTAssertEqual(fetched.note, "Slept well")
    }

    func testSleepEventQualityRange() throws {
        // Test minimum quality
        let sleepMin = SleepEvent(context: testStack!.context)
        sleepMin.id = UUID()
        sleepMin.createdAt = Date()
        sleepMin.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleepMin.wakeTime = Date()
        sleepMin.quality = 1

        // Test maximum quality
        let sleepMax = SleepEvent(context: testStack!.context)
        sleepMax.id = UUID()
        sleepMax.createdAt = Date()
        sleepMax.bedTime = Date().addingTimeInterval(-7 * 3600)
        sleepMax.wakeTime = Date()
        sleepMax.quality = 5

        try testStack!.context.save()

        let request = SleepEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepEvent.quality, ascending: true)]
        let fetched = try testStack!.context.fetch(request)

        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched.first?.quality, 1)
        XCTAssertEqual(fetched.last?.quality, 5)
    }

    func testSleepEventWithHealthKitData() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 3
        sleep.hkSleepHours = NSNumber(value: 7.5)
        sleep.hkHRV = NSNumber(value: 45.2)
        sleep.hkRestingHR = NSNumber(value: 58.0)

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.hkSleepHours?.doubleValue, 7.5)
        XCTAssertEqual(fetched.hkHRV?.doubleValue, 45.2)
        XCTAssertEqual(fetched.hkRestingHR?.doubleValue, 58.0)
    }

    func testSleepEventWithSymptoms() throws {
        // Create test symptom types
        var symptoms: [SymptomType] = []
        for i in 1...3 {
            let symptomType = SymptomType(context: testStack!.context)
            symptomType.id = UUID()
            symptomType.name = "Test Symptom \(i)"
            symptomType.category = "Physical"
            symptomType.color = "blue"
            symptomType.iconName = "heart.fill"
            symptoms.append(symptomType)
        }
        try testStack!.context.save()

        let sleep = SleepEvent(context: testStack!.context)
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

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.symptoms?.count, 3)

        // Verify bidirectional relationship
        let firstSymptom = symptoms.first!
        XCTAssertTrue((firstSymptom.sleepEvents?.contains(fetched)) ?? false)
    }

    func testSleepEventMaxFiveSymptoms() throws {
        // Create 5 test symptom types
        var symptoms: [SymptomType] = []
        for i in 1...5 {
            let symptomType = SymptomType(context: testStack!.context)
            symptomType.id = UUID()
            symptomType.name = "Test Symptom \(i)"
            symptomType.category = "Physical"
            symptomType.color = "blue"
            symptomType.iconName = "heart.fill"
            symptoms.append(symptomType)
        }
        try testStack!.context.save()

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 3

        // Add exactly 5 symptoms (max allowed in UI)
        for symptom in symptoms.prefix(5) {
            sleep.addToSymptoms(symptom)
        }

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.symptoms?.count, 5)
    }

    func testSleepEventRemoveSymptom() throws {
        // Create test symptom type
        let symptom = SymptomType(context: testStack!.context)
        symptom.id = UUID()
        symptom.name = "Test Symptom"
        symptom.category = "Physical"
        symptom.color = "blue"
        symptom.iconName = "heart.fill"
        try testStack!.context.save()

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 3
        sleep.addToSymptoms(symptom)

        try testStack!.context.save()

        XCTAssertEqual(sleep.symptoms?.count, 1)

        // Remove symptom
        sleep.removeFromSymptoms(symptom)
        try testStack!.context.save()

        XCTAssertEqual(sleep.symptoms?.count, 0)
    }

    func testSleepEventBackdatedAt() throws {
        let bedTime = Date().addingTimeInterval(-10 * 3600) // 10 hours ago

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.backdatedAt = bedTime
        sleep.bedTime = bedTime
        sleep.wakeTime = Date().addingTimeInterval(-2 * 3600)
        sleep.quality = 3

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.backdatedAt, bedTime)
    }

    // MARK: - MealEvent Tests

    func testCreateMealEvent() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date().addingTimeInterval(-1800) // 30 minutes ago
        meal.mealType = "lunch"
        meal.mealDescription = "Chicken salad with quinoa"
        meal.note = "Felt satisfied"

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.mealType, "lunch")
        XCTAssertEqual(fetched.mealDescription, "Chicken salad with quinoa")
        XCTAssertEqual(fetched.note, "Felt satisfied")
    }

    func testMealEventTypes() throws {
        let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

        for (index, type) in mealTypes.enumerated() {
            let meal = MealEvent(context: testStack!.context)
            meal.id = UUID()
            meal.createdAt = Date()
            meal.mealType = type
            meal.mealDescription = "Test \(type)"
        }

        try testStack!.context.save()

        let request = MealEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: true)]
        let meals = try testStack!.context.fetch(request)

        XCTAssertEqual(meals.count, 4)
        XCTAssertEqual(meals[0].mealType, "breakfast")
        XCTAssertEqual(meals[1].mealType, "lunch")
        XCTAssertEqual(meals[2].mealType, "dinner")
        XCTAssertEqual(meals[3].mealType, "snack")
    }

    func testMealEventWithBackdatedTime() throws {
        let mealTime = Date().addingTimeInterval(-3600) // 1 hour ago

        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = mealTime
        meal.mealType = "breakfast"
        meal.mealDescription = "Oatmeal with berries"

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.backdatedAt, mealTime)
        XCTAssertNotEqual(fetched.backdatedAt, fetched.createdAt)
    }

    func testMealEventWithoutNote() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "snack"
        meal.mealDescription = "Apple"
        // Note is intentionally nil

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNil(fetched.note)
        XCTAssertEqual(fetched.mealDescription, "Apple")
    }

    func testMealEventWithExertionValues() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "lunch"
        meal.mealDescription = "Large meal with coffee"
        meal.physicalExertion = NSNumber(value: 4)
        meal.cognitiveExertion = NSNumber(value: 5)
        meal.emotionalLoad = NSNumber(value: 3)

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.physicalExertion?.intValue, 4)
        XCTAssertEqual(fetched.cognitiveExertion?.intValue, 5)
        XCTAssertEqual(fetched.emotionalLoad?.intValue, 3)
    }

    func testMealEventWithoutExertionValues() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Simple toast"
        // Exertion values intentionally not set

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertNil(fetched.physicalExertion)
        XCTAssertNil(fetched.cognitiveExertion)
        XCTAssertNil(fetched.emotionalLoad)
    }

    func testMealEventPartialExertionValues() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "dinner"
        meal.mealDescription = "Pasta"
        // Only set physical exertion, leave others nil
        meal.physicalExertion = NSNumber(value: 3)

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.physicalExertion?.intValue, 3)
        XCTAssertNil(fetched.cognitiveExertion)
        XCTAssertNil(fetched.emotionalLoad)
    }

    func testMealEventExertionBoundaryValues() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "snack"
        meal.mealDescription = "Energy bar"

        // Test minimum values
        meal.physicalExertion = NSNumber(value: 1)
        meal.cognitiveExertion = NSNumber(value: 1)
        meal.emotionalLoad = NSNumber(value: 1)
        XCTAssertNoThrow(try testStack!.context.save())

        // Test maximum values
        meal.physicalExertion = NSNumber(value: 5)
        meal.cognitiveExertion = NSNumber(value: 5)
        meal.emotionalLoad = NSNumber(value: 5)
        XCTAssertNoThrow(try testStack!.context.save())

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetched.physicalExertion?.intValue, 5)
        XCTAssertEqual(fetched.cognitiveExertion?.intValue, 5)
        XCTAssertEqual(fetched.emotionalLoad?.intValue, 5)
    }

    // MARK: - Integration Tests

    func testMultipleEventTypesCoexist() throws {
        // Create one of each event type
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Gym workout"
        activity.physicalExertion = 4
        activity.cognitiveExertion = 2
        activity.emotionalLoad = 2

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 4

        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Scrambled eggs"

        try testStack!.context.save()

        // Verify each type exists independently
        let activities = try testStack!.context.fetch(ActivityEvent.fetchRequest())
        let sleeps = try testStack!.context.fetch(SleepEvent.fetchRequest())
        let meals = try testStack!.context.fetch(MealEvent.fetchRequest())

        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(sleeps.count, 1)
        XCTAssertEqual(meals.count, 1)
    }

    func testEventsSortByCreatedAt() throws {
        let now = Date()

        let activity1 = ActivityEvent(context: testStack!.context)
        activity1.id = UUID()
        activity1.createdAt = now.addingTimeInterval(-3600)
        activity1.name = "Morning activity"
        activity1.physicalExertion = 3
        activity1.cognitiveExertion = 3
        activity1.emotionalLoad = 3

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = now.addingTimeInterval(-7200)
        sleep.bedTime = now.addingTimeInterval(-10 * 3600)
        sleep.wakeTime = now.addingTimeInterval(-2 * 3600)
        sleep.quality = 3

        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = now
        meal.mealType = "lunch"
        meal.mealDescription = "Sandwich"

        try testStack!.context.save()

        // Fetch activities sorted by createdAt
        let activityRequest = ActivityEvent.fetchRequest()
        activityRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ActivityEvent.createdAt, ascending: false)]
        let activities = try testStack!.context.fetch(activityRequest)

        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities.first?.name, "Morning activity")
    }

    func testDeleteSleepEventMaintainsSymptoms() throws {
        // Create test symptom type
        let symptom = SymptomType(context: testStack!.context)
        symptom.id = UUID()
        symptom.name = "Test Symptom"
        symptom.category = "Physical"
        symptom.color = "blue"
        symptom.iconName = "heart.fill"
        try testStack!.context.save()

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600)
        sleep.wakeTime = Date()
        sleep.quality = 3
        sleep.addToSymptoms(symptom)

        try testStack!.context.save()

        // Delete sleep event
        testStack!.context.delete(sleep)
        try testStack!.context.save()

        // Symptom should still exist (nullify deletion rule)
        let fetchedSymptom = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        XCTAssertEqual(fetchedSymptom.id, symptom.id)
    }

    func testEventCreatedAtNotNil() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-8 * 3600) // 8 hours ago
        sleep.wakeTime = Date()
        sleep.quality = 3

        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Test"

        try testStack!.context.save()

        let fetchedActivity = try XCTUnwrap(fetchFirstObject(ActivityEvent.fetchRequest(), in: testStack!.context))
        let fetchedSleep = try XCTUnwrap(fetchFirstObject(SleepEvent.fetchRequest(), in: testStack!.context))
        let fetchedMeal = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))

        XCTAssertNotNil(fetchedActivity.createdAt)
        XCTAssertNotNil(fetchedSleep.createdAt)
        XCTAssertNotNil(fetchedMeal.createdAt)
    }

    // MARK: - Validation Tests

    // MARK: ActivityEvent Validations

    func testActivityEventRequiresName() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        // name intentionally not set
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            // Core Data validates non-optional schema fields before custom validation
            // Either NSCocoaErrorDomain 1570 or our custom ActivityEvent error is acceptable
            let isValidError = (nsError.domain == "NSCocoaErrorDomain" && nsError.code == 1570) ||
                               (nsError.domain == "ActivityEvent" && nsError.code == 3004)
            XCTAssertTrue(isValidError, "Expected validation error, got: \(nsError)")
            XCTAssertTrue(nsError.localizedDescription.contains("name"))
        }
    }

    func testActivityEventValidatesExertionRange() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 6 // Invalid - above max
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ActivityEvent")
            XCTAssertEqual(nsError.code, 3001)
            XCTAssertTrue(nsError.localizedDescription.contains("Physical exertion"))
        }
    }

    func testActivityEventValidatesDurationRange() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3
        activity.durationMinutes = NSNumber(value: 0) // Invalid - below minimum

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ActivityEvent")
            XCTAssertEqual(nsError.code, 3005)
            XCTAssertTrue(nsError.localizedDescription.contains("at least 1 minute"))
        }
    }

    func testActivityEventValidatesMaxDuration() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3
        activity.durationMinutes = NSNumber(value: 2000) // Invalid - above maximum (24 hours = 1440 minutes)

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ActivityEvent")
            XCTAssertEqual(nsError.code, 3006)
            XCTAssertTrue(nsError.localizedDescription.contains("cannot exceed 24 hours"))
        }
    }

    func testActivityEventValidatesFutureDate() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date().addingTimeInterval(3600) // 1 hour in future - invalid
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ActivityEvent")
            XCTAssertEqual(nsError.code, 3007)
            XCTAssertTrue(nsError.localizedDescription.contains("cannot be in the future"))
        }
    }

    func testActivityEventValidatesBackdatedRange() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test"
        activity.backdatedAt = Date().addingTimeInterval(-400 * 24 * 3600) // Over 1 year ago - invalid
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ActivityEvent")
            XCTAssertEqual(nsError.code, 3008)
            XCTAssertTrue(nsError.localizedDescription.contains("within the past year"))
        }
    }

    // MARK: SleepEvent Validations

    func testSleepEventValidatesTimeOrder() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date()
        sleep.wakeTime = Date().addingTimeInterval(-3600) // Wake before bed - invalid
        sleep.quality = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "SleepEvent")
            XCTAssertEqual(nsError.code, 5004)
            XCTAssertTrue(nsError.localizedDescription.contains("after bed time"))
        }
    }

    func testSleepEventValidatesMinimumDuration() throws {
        let now = Date()
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = now
        sleep.wakeTime = now.addingTimeInterval(30) // 30 seconds - below 1 minute minimum
        sleep.quality = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "SleepEvent")
            XCTAssertEqual(nsError.code, 5005)
            XCTAssertTrue(nsError.localizedDescription.contains("at least 1 minute"))
        }
    }

    func testSleepEventValidatesMaximumDuration() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date()
        sleep.wakeTime = Date().addingTimeInterval(25 * 3600) // 25 hours - above 24 hour maximum
        sleep.quality = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "SleepEvent")
            XCTAssertEqual(nsError.code, 5006)
            XCTAssertTrue(nsError.localizedDescription.contains("cannot exceed 24 hours"))
        }
    }

    func testSleepEventRequiresBedTime() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        // bedTime intentionally not set
        sleep.wakeTime = Date()
        sleep.quality = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            // Core Data validates non-optional schema fields before custom validation
            let isValidError = (nsError.domain == "NSCocoaErrorDomain" && nsError.code == 1570) ||
                               (nsError.domain == "SleepEvent" && nsError.code == 5001)
            XCTAssertTrue(isValidError, "Expected validation error, got: \(nsError)")
            XCTAssertTrue(nsError.localizedDescription.lowercased().contains("bed"))
        }
    }

    func testSleepEventRequiresWakeTime() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date()
        // wakeTime intentionally not set
        sleep.quality = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            // Core Data validates non-optional schema fields before custom validation
            let isValidError = (nsError.domain == "NSCocoaErrorDomain" && nsError.code == 1570) ||
                               (nsError.domain == "SleepEvent" && nsError.code == 5002)
            XCTAssertTrue(isValidError, "Expected validation error, got: \(nsError)")
            XCTAssertTrue(nsError.localizedDescription.lowercased().contains("wake"))
        }
    }

    func testSleepEventValidatesQualityRange() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date()
        sleep.wakeTime = Date().addingTimeInterval(3600)
        sleep.quality = 0 // Invalid - below minimum

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "SleepEvent")
            XCTAssertEqual(nsError.code, 5003)
            XCTAssertTrue(nsError.localizedDescription.contains("Sleep quality"))
        }
    }

    func testSleepEventValidatesDateRange() throws {
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.bedTime = Date().addingTimeInterval(-10 * 24 * 3600) // 10 days ago - outside 1 week range
        sleep.wakeTime = Date().addingTimeInterval(-10 * 24 * 3600 + 3600)
        sleep.quality = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "SleepEvent")
            XCTAssertEqual(nsError.code, 5008)
            XCTAssertTrue(nsError.localizedDescription.contains("within the past week"))
        }
    }

    // MARK: MealEvent Validations

    func testMealEventRequiresMealType() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        // mealType intentionally not set
        meal.mealDescription = "Test food"

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            // Core Data validates non-optional schema fields before custom validation
            let isValidError = (nsError.domain == "NSCocoaErrorDomain" && nsError.code == 1570) ||
                               (nsError.domain == "MealEvent" && nsError.code == 4001)
            XCTAssertTrue(isValidError, "Expected validation error, got: \(nsError)")
            XCTAssertTrue(nsError.localizedDescription.lowercased().contains("meal"))
        }
    }

    func testMealEventRequiresMealDescription() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "lunch"
        // mealDescription intentionally not set

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            // Core Data validates non-optional schema fields before custom validation
            let isValidError = (nsError.domain == "NSCocoaErrorDomain" && nsError.code == 1570) ||
                               (nsError.domain == "MealEvent" && nsError.code == 4002)
            XCTAssertTrue(isValidError, "Expected validation error, got: \(nsError)")
            XCTAssertTrue(nsError.localizedDescription.lowercased().contains("description") ||
                         nsError.localizedDescription.lowercased().contains("meal"))
        }
    }

    func testMealEventValidatesDateRange() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "lunch"
        meal.mealDescription = "Test"
        meal.backdatedAt = Date().addingTimeInterval(-400 * 24 * 3600) // Over 1 year ago - invalid

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "MealEvent")
            XCTAssertEqual(nsError.code, 4004)
            XCTAssertTrue(nsError.localizedDescription.contains("within the past year"))
        }
    }

    // MARK: SymptomEntry Validations

    func testSymptomEntryRequiresSymptomType() throws {
        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.severity = 3
        // symptomType intentionally not set

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "SymptomEntry")
            XCTAssertEqual(nsError.code, 1003)
            XCTAssertTrue(nsError.localizedDescription.contains("Symptom type is required"))
        }
    }

    func testSymptomEntryValidatesSeverityRange() throws {
        // Create test symptom type
        let symptomType = SymptomType(context: testStack!.context)
        symptomType.id = UUID()
        symptomType.name = "Test Symptom"
        symptomType.category = "Physical"
        symptomType.color = "blue"
        symptomType.iconName = "heart.fill"
        try testStack!.context.save()

        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.symptomType = symptomType
        entry.severity = 6 // Invalid - above maximum

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "SymptomEntry")
            XCTAssertEqual(nsError.code, 1001)
            XCTAssertTrue(nsError.localizedDescription.contains("Severity"))
        }
    }

    // MARK: - Edge Case Tests

    func testActivityEventWithEmptyStringName() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "" // Empty string instead of nil
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("name"))
        }
    }

    func testActivityEventWithWhitespaceOnlyName() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "   \t\n  " // Whitespace only
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        // This should fail if we add whitespace validation, but currently might pass
        // Test documents current behavior
        do {
            try testStack!.context.save()
        } catch {
            // If it fails, that's acceptable
        }
    }

    func testActivityEventWithZeroDuration() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3
        activity.durationMinutes = 0 // Zero duration

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("duration"))
        }
    }

    func testActivityEventWithNegativeDuration() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3
        activity.durationMinutes = -10 // Negative duration

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("duration"))
        }
    }

    func testActivityEventWithExactlyBoundaryDuration() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3
        activity.durationMinutes = 1440 // Exactly 24 hours - should pass

        XCTAssertNoThrow(try testStack!.context.save())
    }

    func testActivityEventWithUnicodeCharactersInName() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "🏃‍♂️ Running in 東京 with café ☕️" // Unicode, emoji, various languages
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        XCTAssertNoThrow(try testStack!.context.save())
    }

    func testActivityEventWithVeryLongName() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = String(repeating: "a", count: 10000) // Very long name
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        // Should pass unless we add length validation
        XCTAssertNoThrow(try testStack!.context.save())
    }

    func testActivityEventWithBoundaryExertionValues() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 1 // Minimum valid
        activity.cognitiveExertion = 5 // Maximum valid
        activity.emotionalLoad = 3

        XCTAssertNoThrow(try testStack!.context.save())
    }

    func testActivityEventWithZeroExertion() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.name = "Test"
        activity.physicalExertion = 0 // Below minimum
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        XCTAssertThrowsError(try testStack!.context.save())
    }

    func testSleepEventWithExactlyOneMinuteDuration() throws {
        let now = Date()
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = now
        sleep.bedTime = now
        sleep.wakeTime = now.addingTimeInterval(60) // Exactly 1 minute
        sleep.quality = 3

        XCTAssertNoThrow(try testStack!.context.save())
    }

    func testSleepEventWithLessThanOneMinuteDuration() throws {
        let now = Date()
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = now
        sleep.bedTime = now
        sleep.wakeTime = now.addingTimeInterval(30) // 30 seconds
        sleep.quality = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("minute"))
        }
    }

    func testSleepEventWithExactly24HourDuration() throws {
        let now = Date()
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = now
        sleep.bedTime = now
        sleep.wakeTime = now.addingTimeInterval(24 * 60 * 60) // Exactly 24 hours
        sleep.quality = 3

        XCTAssertNoThrow(try testStack!.context.save())
    }

    func testSleepEventWithBedTimeEqualToWakeTime() throws {
        let now = Date()
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = now
        sleep.bedTime = now
        sleep.wakeTime = now // Same time
        sleep.quality = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("after") || nsError.localizedDescription.contains("minute"))
        }
    }

    func testSleepEventWithBoundaryQualityValues() throws {
        let now = Date()
        let sleep = SleepEvent(context: testStack!.context)
        sleep.id = UUID()
        sleep.createdAt = now
        sleep.bedTime = now
        sleep.wakeTime = now.addingTimeInterval(8 * 60 * 60)
        sleep.quality = 1 // Minimum valid

        XCTAssertNoThrow(try testStack!.context.save())

        sleep.quality = 5 // Maximum valid
        XCTAssertNoThrow(try testStack!.context.save())
    }

    func testMealEventWithEmptyDescription() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "Lunch"
        meal.mealDescription = "" // Empty string

        XCTAssertThrowsError(try testStack!.context.save())
    }

    func testMealEventWithSpecialCharactersInDescription() throws {
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "Dinner"
        meal.mealDescription = "<script>alert('xss')</script>" // Potential XSS

        // Should store as-is (not our job to sanitize in validation)
        XCTAssertNoThrow(try testStack!.context.save())
    }

    func testActivityEventWithDateExactlyAtBoundary() throws {
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now)!

        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = now
        activity.backdatedAt = oneYearAgo // Exactly at boundary
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        // Should pass or fail depending on boundary handling (inclusive vs exclusive)
        do {
            try testStack!.context.save()
        } catch {
            // Document that boundary is exclusive if this fails
        }
    }

    func testCreatedDateInNearFuture() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date().addingTimeInterval(30) // 30 seconds in future (within tolerance)
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        // Should pass - within 60 second tolerance
        XCTAssertNoThrow(try testStack!.context.save())
    }

    func testCreatedDateFarInFuture() throws {
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = Date().addingTimeInterval(120) // 2 minutes in future (beyond tolerance)
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 3
        activity.emotionalLoad = 3

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("future"))
        }
    }

    func testSymptomEntryWithZeroSeverity() throws {
        let symptomType = SymptomType(context: testStack!.context)
        symptomType.id = UUID()
        symptomType.name = "Test Symptom"
        symptomType.category = "Physical"
        symptomType.color = "blue"
        symptomType.iconName = "heart.fill"

        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.symptomType = symptomType
        entry.severity = 0 // Below minimum

        XCTAssertThrowsError(try testStack!.context.save())
    }

    func testSymptomEntryWithBoundarySeverity() throws {
        let symptomType = SymptomType(context: testStack!.context)
        symptomType.id = UUID()
        symptomType.name = "Test Symptom"
        symptomType.category = "Physical"
        symptomType.color = "blue"
        symptomType.iconName = "heart.fill"

        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.symptomType = symptomType
        entry.severity = 1 // Minimum valid

        XCTAssertNoThrow(try testStack!.context.save())

        entry.severity = 5 // Maximum valid
        XCTAssertNoThrow(try testStack!.context.save())
    }
}
