//
//  NotificationSchedulerTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 03/10/2025.
//

import CoreData
import XCTest
import UserNotifications
@testable import Murmur

final class NotificationSchedulerTests: XCTestCase {
    var testStack: InMemoryCoreDataStack!
    var scheduler: NotificationScheduler!

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
        scheduler = NotificationScheduler()
    }

    override func tearDown() {
        scheduler = nil
        testStack = nil
        super.tearDown()
    }

    func testCreateReminder() throws {
        let reminder = Reminder(context: testStack.context)
        reminder.id = UUID()
        reminder.hour = 9
        reminder.minute = 30
        reminder.isEnabled = true
        reminder.repeatsOn = NSArray(array: ["Monday", "Tuesday", "Wednesday"])

        try testStack.context.save()

        // Verify reminder was created
        let request = Reminder.fetchRequest()
        let reminders = try testStack.context.fetch(request)

        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders.first?.hour, 9)
        XCTAssertEqual(reminders.first?.minute, 30)
        XCTAssertTrue(reminders.first?.isEnabled ?? false)
    }

    func testMultipleReminders() throws {
        // Create multiple reminders with different times
        for i in 0..<5 {
            let reminder = Reminder(context: testStack.context)
            reminder.id = UUID()
            reminder.hour = Int16(8 + i)
            reminder.minute = Int16(i * 10)
            reminder.isEnabled = i % 2 == 0
            reminder.repeatsOn = NSArray(array: ["Monday"])
        }

        try testStack.context.save()

        // Verify all reminders are created
        let request = Reminder.fetchRequest()
        let reminders = try testStack.context.fetch(request)
        XCTAssertEqual(reminders.count, 5)

        // Check enabled count
        let enabledReminders = reminders.filter { $0.isEnabled }
        XCTAssertEqual(enabledReminders.count, 3)
    }

    func testDisabledReminder() throws {
        let reminder = Reminder(context: testStack.context)
        reminder.id = UUID()
        reminder.hour = 7
        reminder.minute = 0
        reminder.isEnabled = false // Disabled

        try testStack.context.save()

        XCTAssertFalse(reminder.isEnabled)
    }

    func testReminderWithRepeatingDays() throws {
        let reminder = Reminder(context: testStack.context)
        reminder.id = UUID()
        reminder.hour = 20
        reminder.minute = 0
        reminder.isEnabled = true

        let repeatDays = ["Monday", "Wednesday", "Friday", "Sunday"]
        reminder.repeatsOn = NSArray(array: repeatDays)

        try testStack.context.save()

        // Verify repeat days
        if let storedDays = reminder.repeatsOn as? [String] {
            XCTAssertEqual(storedDays.count, 4)
            XCTAssertTrue(storedDays.contains("Monday"))
            XCTAssertTrue(storedDays.contains("Friday"))
        } else {
            XCTFail("Repeat days not stored correctly")
        }
    }

    func testReminderTimeComponents() throws {
        let reminder = Reminder(context: testStack.context)
        reminder.id = UUID()
        reminder.hour = 23  // 11 PM
        reminder.minute = 59
        reminder.isEnabled = true

        try testStack.context.save()

        XCTAssertEqual(reminder.hour, 23)
        XCTAssertEqual(reminder.minute, 59)
    }

    func testFetchEnabledReminders() throws {
        // Create mix of enabled and disabled reminders
        for i in 0..<10 {
            let reminder = Reminder(context: testStack.context)
            reminder.id = UUID()
            reminder.hour = Int16(i)
            reminder.minute = 0
            reminder.isEnabled = i < 5 // First 5 are enabled
        }

        try testStack.context.save()

        // Fetch only enabled reminders
        let request = Reminder.fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == %@", NSNumber(value: true))
        let enabledReminders = try testStack.context.fetch(request)

        XCTAssertEqual(enabledReminders.count, 5)
    }
}