// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// MealEventIntegrationTests.swift
// Created by Aidan Cornelius-Bell on 12/10/2025.
// Integration tests for meal event handling.
//
import CoreData
import XCTest
@testable import Murmur

final class MealEventIntegrationTests: XCTestCase {
    var testStack: InMemoryCoreDataStack?

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
    }

    override func tearDown() {
        testStack = nil
        super.tearDown()
    }

    // MARK: - Full Flow Integration Tests

    func testCreateMealWithExertionFullFlow() throws {
        // Simulate the complete flow from UI to Core Data

        // Step 1: User selects meal type
        let mealType = "lunch"

        // Step 2: User enters meal description
        let mealDescription = "Large burger with fries and soft drink"

        // Step 3: User adds note
        let note = "Felt very full afterwards"

        // Step 4: User toggles on energy impact
        let showMealExertion = true

        // Step 5: User adjusts exertion sliders
        let physicalExertion = 5
        let cognitiveExertion = 4
        let emotionalLoad = 3

        // Step 6: User saves the meal
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date()
        meal.mealType = mealType
        meal.mealDescription = mealDescription
        meal.note = note.isEmpty ? nil : note

        if showMealExertion {
            meal.physicalExertion = NSNumber(value: physicalExertion)
            meal.cognitiveExertion = NSNumber(value: cognitiveExertion)
            meal.emotionalLoad = NSNumber(value: emotionalLoad)
        }

        try testStack!.context.save()

        // Step 7: Verify the saved meal
        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))

        XCTAssertEqual(fetched.mealType, mealType)
        XCTAssertEqual(fetched.mealDescription, mealDescription)
        XCTAssertEqual(fetched.note, note)
        XCTAssertEqual(fetched.physicalExertion?.intValue, physicalExertion)
        XCTAssertEqual(fetched.cognitiveExertion?.intValue, cognitiveExertion)
        XCTAssertEqual(fetched.emotionalLoad?.intValue, emotionalLoad)
    }

    func testCreateMealWithoutExertionFullFlow() throws {
        // Simulate the complete flow without exertion

        let mealType = "snack"
        let mealDescription = "Apple and water"
        let showMealExertion = false

        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = Date()
        meal.mealType = mealType
        meal.mealDescription = mealDescription

        if showMealExertion {
            meal.physicalExertion = NSNumber(value: 3)
            meal.cognitiveExertion = NSNumber(value: 3)
            meal.emotionalLoad = NSNumber(value: 3)
        }

        try testStack!.context.save()

        let fetched = try XCTUnwrap(fetchFirstObject(MealEvent.fetchRequest(), in: testStack!.context))

        XCTAssertEqual(fetched.mealType, mealType)
        XCTAssertEqual(fetched.mealDescription, mealDescription)
        XCTAssertNil(fetched.physicalExertion)
        XCTAssertNil(fetched.cognitiveExertion)
        XCTAssertNil(fetched.emotionalLoad)
    }

    func testRetrieveAndDisplayMealWithExertion() throws {
        // Test retrieving a meal with exertion and displaying it

        // Create a meal
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Coffee and croissant"
        meal.physicalExertion = NSNumber(value: 3)
        meal.cognitiveExertion = NSNumber(value: 5)
        meal.emotionalLoad = NSNumber(value: 2)

        try testStack!.context.save()

        // Retrieve the meal
        let request = MealEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: false)]
        let meals = try testStack!.context.fetch(request)

        XCTAssertEqual(meals.count, 1)
        let retrievedMeal = meals[0]

        // Verify display data
        XCTAssertEqual(retrievedMeal.mealDescription, "Coffee and croissant")

        // Verify exertion is available for display
        let hasExertion = retrievedMeal.physicalExertion != nil &&
                         retrievedMeal.cognitiveExertion != nil &&
                         retrievedMeal.emotionalLoad != nil

        XCTAssertTrue(hasExertion)
        XCTAssertEqual(retrievedMeal.physicalExertion?.intValue, 3)
        XCTAssertEqual(retrievedMeal.cognitiveExertion?.intValue, 5)
        XCTAssertEqual(retrievedMeal.emotionalLoad?.intValue, 2)
    }

    func testRetrieveAndDisplayMealWithoutExertion() throws {
        // Test retrieving a meal without exertion and displaying it

        // Create a meal
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "snack"
        meal.mealDescription = "Granola bar"

        try testStack!.context.save()

        // Retrieve the meal
        let request = MealEvent.fetchRequest()
        let meals = try testStack!.context.fetch(request)

        XCTAssertEqual(meals.count, 1)
        let retrievedMeal = meals[0]

        // Verify display data
        XCTAssertEqual(retrievedMeal.mealDescription, "Granola bar")

        // Verify exertion is not available
        let hasExertion = retrievedMeal.physicalExertion != nil &&
                         retrievedMeal.cognitiveExertion != nil &&
                         retrievedMeal.emotionalLoad != nil

        XCTAssertFalse(hasExertion)
    }

    func testBackwardsCompatibilityOldMealsStillWork() throws {
        // Test that meals created before exertion feature still work

        // Create an "old" meal (simulating version 3 data)
        let oldMeal = MealEvent(context: testStack!.context)
        oldMeal.id = UUID()
        oldMeal.createdAt = Date().addingTimeInterval(-7 * 24 * 3600) // 1 week ago
        oldMeal.mealType = "dinner"
        oldMeal.mealDescription = "Old dinner entry from before exertion feature"
        oldMeal.note = "This was created before exertion tracking"
        // No exertion values

        // Create a "new" meal (simulating version 4 data)
        let newMeal = MealEvent(context: testStack!.context)
        newMeal.id = UUID()
        newMeal.createdAt = Date()
        newMeal.mealType = "lunch"
        newMeal.mealDescription = "New lunch entry with exertion"
        newMeal.physicalExertion = NSNumber(value: 4)
        newMeal.cognitiveExertion = NSNumber(value: 3)
        newMeal.emotionalLoad = NSNumber(value: 3)

        try testStack!.context.save()

        // Retrieve both meals
        let request = MealEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: false)]
        let meals = try testStack!.context.fetch(request)

        XCTAssertEqual(meals.count, 2)

        // Verify new meal
        XCTAssertEqual(meals[0].mealDescription, "New lunch entry with exertion")
        XCTAssertNotNil(meals[0].physicalExertion)

        // Verify old meal still works
        XCTAssertEqual(meals[1].mealDescription, "Old dinner entry from before exertion feature")
        XCTAssertNil(meals[1].physicalExertion)
        XCTAssertNil(meals[1].cognitiveExertion)
        XCTAssertNil(meals[1].emotionalLoad)

        // Both meals should be fully functional
        XCTAssertNotNil(meals[0].id)
        XCTAssertNotNil(meals[1].id)
        XCTAssertNotNil(meals[0].createdAt)
        XCTAssertNotNil(meals[1].createdAt)
    }

    func testEditExistingMealToAddExertion() throws {
        // Test editing an existing meal to add exertion values

        // Create meal without exertion
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "breakfast"
        meal.mealDescription = "Toast"

        try testStack!.context.save()

        let mealID = meal.objectID

        // User decides to add exertion to this meal
        let mealToEdit = try testStack!.context.existingObject(with: mealID) as? MealEvent
        XCTAssertNotNil(mealToEdit)

        mealToEdit?.physicalExertion = NSNumber(value: 2)
        mealToEdit?.cognitiveExertion = NSNumber(value: 2)
        mealToEdit?.emotionalLoad = NSNumber(value: 2)

        try testStack!.context.save()

        // Verify exertion was added
        let updated = try testStack!.context.existingObject(with: mealID) as? MealEvent
        XCTAssertNotNil(updated?.physicalExertion)
        XCTAssertEqual(updated?.physicalExertion?.intValue, 2)
    }

    func testEditExistingMealToRemoveExertion() throws {
        // Test editing an existing meal to remove exertion values

        // Create meal with exertion
        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.mealType = "lunch"
        meal.mealDescription = "Sandwich"
        meal.physicalExertion = NSNumber(value: 4)
        meal.cognitiveExertion = NSNumber(value: 3)
        meal.emotionalLoad = NSNumber(value: 3)

        try testStack!.context.save()

        let mealID = meal.objectID

        // User decides to remove exertion from this meal
        let mealToEdit = try testStack!.context.existingObject(with: mealID) as? MealEvent
        XCTAssertNotNil(mealToEdit)

        mealToEdit?.physicalExertion = nil
        mealToEdit?.cognitiveExertion = nil
        mealToEdit?.emotionalLoad = nil

        try testStack!.context.save()

        // Verify exertion was removed
        let updated = try testStack!.context.existingObject(with: mealID) as? MealEvent
        XCTAssertNil(updated?.physicalExertion)
        XCTAssertNil(updated?.cognitiveExertion)
        XCTAssertNil(updated?.emotionalLoad)
    }

    func testMealWithExertionInTimeline() throws {
        // Test that meals with exertion appear correctly in timeline queries

        // Create multiple meals
        for i in 0..<5 {
            let meal = MealEvent(context: testStack!.context)
            meal.id = UUID()
            meal.createdAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
            meal.mealType = i % 2 == 0 ? "breakfast" : "lunch"
            meal.mealDescription = "Meal \(i)"

            // Alternate between with and without exertion
            if i % 2 == 0 {
                meal.physicalExertion = NSNumber(value: i + 1)
                meal.cognitiveExertion = NSNumber(value: i + 1)
                meal.emotionalLoad = NSNumber(value: i + 1)
            }
        }

        try testStack!.context.save()

        // Query all meals as they would appear in timeline
        let request = MealEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: false)]
        let meals = try testStack!.context.fetch(request)

        XCTAssertEqual(meals.count, 5)

        // Verify alternating pattern
        XCTAssertNotNil(meals[0].physicalExertion) // Meal 0 - has exertion
        XCTAssertNil(meals[1].physicalExertion)    // Meal 1 - no exertion
        XCTAssertNotNil(meals[2].physicalExertion) // Meal 2 - has exertion
        XCTAssertNil(meals[3].physicalExertion)    // Meal 3 - no exertion
        XCTAssertNotNil(meals[4].physicalExertion) // Meal 4 - has exertion
    }

    func testQueryMealsWithExertion() throws {
        // Test querying meals that have exertion values

        // Create mixed meals
        let meal1 = MealEvent(context: testStack!.context)
        meal1.id = UUID()
        meal1.createdAt = Date()
        meal1.mealType = "breakfast"
        meal1.mealDescription = "With exertion"
        meal1.physicalExertion = NSNumber(value: 3)

        let meal2 = MealEvent(context: testStack!.context)
        meal2.id = UUID()
        meal2.createdAt = Date().addingTimeInterval(-3600)
        meal2.mealType = "snack"
        meal2.mealDescription = "Without exertion"

        let meal3 = MealEvent(context: testStack!.context)
        meal3.id = UUID()
        meal3.createdAt = Date().addingTimeInterval(-7200)
        meal3.mealType = "lunch"
        meal3.mealDescription = "With exertion"
        meal3.physicalExertion = NSNumber(value: 4)

        try testStack!.context.save()

        // Query meals with exertion
        let request = MealEvent.fetchRequest()
        request.predicate = NSPredicate(format: "physicalExertion != nil")
        let mealsWithExertion = try testStack!.context.fetch(request)

        XCTAssertEqual(mealsWithExertion.count, 2)
        XCTAssertTrue(mealsWithExertion.allSatisfy { $0.physicalExertion != nil })
    }

    func testQueryMealsWithoutExertion() throws {
        // Test querying meals that don't have exertion values

        // Create mixed meals
        let meal1 = MealEvent(context: testStack!.context)
        meal1.id = UUID()
        meal1.createdAt = Date()
        meal1.mealType = "breakfast"
        meal1.mealDescription = "With exertion"
        meal1.physicalExertion = NSNumber(value: 3)

        let meal2 = MealEvent(context: testStack!.context)
        meal2.id = UUID()
        meal2.createdAt = Date().addingTimeInterval(-3600)
        meal2.mealType = "snack"
        meal2.mealDescription = "Without exertion"

        try testStack!.context.save()

        // Query meals without exertion
        let request = MealEvent.fetchRequest()
        request.predicate = NSPredicate(format: "physicalExertion == nil")
        let mealsWithoutExertion = try testStack!.context.fetch(request)

        XCTAssertEqual(mealsWithoutExertion.count, 1)
        XCTAssertTrue(mealsWithoutExertion.allSatisfy { $0.physicalExertion == nil })
    }

    // MARK: - Error Handling

    func testMealValidationStillWorksWithExertion() throws {
        // Test that validation errors are still caught with exertion

        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        // Missing required fields
        meal.physicalExertion = NSNumber(value: 3)

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            // Should fail validation due to missing mealType/mealDescription
            XCTAssertNotNil(error)
        }
    }

    func testMealValidationStillWorksWithoutExertion() throws {
        // Test that validation errors are still caught without exertion

        let meal = MealEvent(context: testStack!.context)
        meal.id = UUID()
        meal.createdAt = Date()
        // Missing required fields, no exertion

        XCTAssertThrowsError(try testStack!.context.save()) { error in
            // Should fail validation due to missing mealType/mealDescription
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Performance

    func testBulkMealCreationWithMixedExertion() throws {
        // Test creating many meals with mixed exertion data

        let startTime = Date()

        for i in 0..<100 {
            let meal = MealEvent(context: testStack!.context)
            meal.id = UUID()
            meal.createdAt = Date().addingTimeInterval(TimeInterval(-i * 60))
            meal.mealType = ["breakfast", "lunch", "dinner", "snack"][i % 4]
            meal.mealDescription = "Meal \(i)"

            // Add exertion to every other meal
            if i % 2 == 0 {
                meal.physicalExertion = NSNumber(value: (i % 5) + 1)
                meal.cognitiveExertion = NSNumber(value: (i % 5) + 1)
                meal.emotionalLoad = NSNumber(value: (i % 5) + 1)
            }
        }

        try testStack!.context.save()

        let duration = Date().timeIntervalSince(startTime)

        // Verify all meals were created
        let request = MealEvent.fetchRequest()
        let meals = try testStack!.context.fetch(request)
        XCTAssertEqual(meals.count, 100)

        // Performance should be reasonable (under 5 seconds for 100 meals)
        XCTAssertLessThan(duration, 5.0)
    }
}
