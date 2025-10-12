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
    var testStack: InMemoryCoreDataStack?

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
    }

    override func tearDown() {
        // Clean up any test reminders from notification center
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        testStack = nil
        super.tearDown()
    }

    // MARK: - Core Data Reminder Tests

    func testCreateReminder() throws {
        let reminder = Reminder(context: testStack!.context)
        reminder.id = UUID()
        reminder.hour = 9
        reminder.minute = 30
        reminder.isEnabled = true
        reminder.repeatsOn = NSArray(array: ["Monday", "Tuesday", "Wednesday"])

        try testStack!.context.save()

        let request = Reminder.fetchRequest()
        let reminders = try testStack!.context.fetch(request)

        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders.first?.hour, 9)
        XCTAssertEqual(reminders.first?.minute, 30)
        XCTAssertTrue(reminders.first?.isEnabled ?? false)
    }

    // MARK: - NotificationScheduler API Tests

    func testScheduleReminderWithNoRepeatingDays() async throws {
        let reminder = Reminder(context: testStack!.context)
        reminder.id = UUID()
        reminder.hour = 10
        reminder.minute = 30
        reminder.isEnabled = true
        reminder.repeatsOn = NSArray(array: [])

        try testStack!.context.save()

        // Schedule the reminder
        try await NotificationScheduler.schedule(reminder: reminder)

        // Verify notification was scheduled
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()

        let matchingRequest = pendingRequests.first { $0.identifier == reminder.id?.uuidString }
        XCTAssertNotNil(matchingRequest, "Notification request should be scheduled")
        XCTAssertEqual(matchingRequest?.content.title, "Murmur: check in reminder")
        XCTAssertEqual(matchingRequest?.content.body, "Tap to record your symptoms, events and sleep.")

        // Verify trigger
        if let trigger = matchingRequest?.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.hour, 10)
            XCTAssertEqual(trigger.dateComponents.minute, 30)
            XCTAssertTrue(trigger.repeats)
        } else {
            XCTFail("Trigger should be UNCalendarNotificationTrigger")
        }
    }

    func testScheduleReminderWithRepeatingDays() async throws {
        let reminder = Reminder(context: testStack!.context)
        reminder.id = UUID()
        reminder.hour = 9
        reminder.minute = 0
        reminder.isEnabled = true
        reminder.repeatsOn = NSArray(array: ["Monday", "Wednesday", "Friday"])

        try testStack!.context.save()

        try await NotificationScheduler.schedule(reminder: reminder)

        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()

        // Should have 3 notifications (one per day)
        let reminderId = try XCTUnwrap(reminder.id?.uuidString)
        let mondayRequest = pendingRequests.first { $0.identifier == "\(reminderId)-Monday" }
        let wednesdayRequest = pendingRequests.first { $0.identifier == "\(reminderId)-Wednesday" }
        let fridayRequest = pendingRequests.first { $0.identifier == "\(reminderId)-Friday" }

        XCTAssertNotNil(mondayRequest)
        XCTAssertNotNil(wednesdayRequest)
        XCTAssertNotNil(fridayRequest)

        // Verify Monday trigger has weekday = 2
        if let trigger = mondayRequest?.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.weekday, 2) // Monday
            XCTAssertEqual(trigger.dateComponents.hour, 9)
            XCTAssertEqual(trigger.dateComponents.minute, 0)
        } else {
            XCTFail("Monday trigger should be UNCalendarNotificationTrigger")
        }

        // Verify Wednesday trigger has weekday = 4
        if let trigger = wednesdayRequest?.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.weekday, 4) // Wednesday
        } else {
            XCTFail("Wednesday trigger should be UNCalendarNotificationTrigger")
        }

        // Verify Friday trigger has weekday = 6
        if let trigger = fridayRequest?.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.weekday, 6) // Friday
        } else {
            XCTFail("Friday trigger should be UNCalendarNotificationTrigger")
        }
    }

    func testScheduleReminderReplacesExisting() async throws {
        let reminder = Reminder(context: testStack!.context)
        reminder.id = UUID()
        reminder.hour = 8
        reminder.minute = 0
        reminder.isEnabled = true
        reminder.repeatsOn = NSArray(array: [])

        try testStack!.context.save()

        // Schedule first time
        try await NotificationScheduler.schedule(reminder: reminder)

        let center = UNUserNotificationCenter.current()
        var pendingRequests = await center.pendingNotificationRequests()
        XCTAssertEqual(pendingRequests.count, 1)

        // Update time and reschedule
        reminder.hour = 14
        reminder.minute = 30
        try await NotificationScheduler.schedule(reminder: reminder)

        pendingRequests = await center.pendingNotificationRequests()

        // Should still only have 1 notification (old one removed)
        XCTAssertEqual(pendingRequests.count, 1)

        // Verify new time
        let matchingRequest = pendingRequests.first { $0.identifier == reminder.id?.uuidString }
        if let trigger = matchingRequest?.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.hour, 14)
            XCTAssertEqual(trigger.dateComponents.minute, 30)
        }
    }

    func testRemoveReminder() async throws {
        let reminder = Reminder(context: testStack!.context)
        reminder.id = UUID()
        reminder.hour = 7
        reminder.minute = 0
        reminder.isEnabled = true
        reminder.repeatsOn = NSArray(array: ["Monday", "Wednesday"])

        try testStack!.context.save()

        // Schedule it
        try await NotificationScheduler.schedule(reminder: reminder)

        let center = UNUserNotificationCenter.current()
        var pendingRequests = await center.pendingNotificationRequests()
        XCTAssertEqual(pendingRequests.count, 2) // Monday and Wednesday

        // Remove it
        await NotificationScheduler.remove(reminder: reminder)

        pendingRequests = await center.pendingNotificationRequests()
        let reminderId = reminder.id?.uuidString ?? ""

        // Should have no notifications with this reminder's ID
        let remainingForReminder = pendingRequests.filter { req in
            req.identifier.contains(reminderId)
        }
        XCTAssertTrue(remainingForReminder.isEmpty)
    }

    func testScheduleWithMissingIdentifier() async throws {
        let reminder = Reminder(context: testStack!.context)
        reminder.id = nil // No ID
        reminder.hour = 10
        reminder.minute = 0

        do {
            try await NotificationScheduler.schedule(reminder: reminder)
            XCTFail("Should throw missingIdentifier error")
        } catch NotificationScheduler.SchedulerError.missingIdentifier {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWeekdayMappingAllDays() async throws {
        let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let expectedWeekdayNumbers = [1, 2, 3, 4, 5, 6, 7]

        for (index, day) in weekdays.enumerated() {
            let reminder = Reminder(context: testStack!.context)
            reminder.id = UUID()
            reminder.hour = 12
            reminder.minute = 0
            reminder.repeatsOn = NSArray(array: [day])

            try await NotificationScheduler.schedule(reminder: reminder)

            let center = UNUserNotificationCenter.current()
            let pendingRequests = await center.pendingNotificationRequests()

            let reminderId = try XCTUnwrap(reminder.id?.uuidString)
            let request = pendingRequests.first { $0.identifier == "\(reminderId)-\(day)" }

            if let trigger = request?.trigger as? UNCalendarNotificationTrigger {
                XCTAssertEqual(trigger.dateComponents.weekday, expectedWeekdayNumbers[index],
                             "\(day) should map to weekday \(expectedWeekdayNumbers[index])")
            } else {
                XCTFail("\(day) notification not scheduled correctly")
            }

            // Clean up for next iteration
            await NotificationScheduler.remove(reminder: reminder)
        }
    }

    func testScheduleWithCaseInsensitiveDays() async throws {
        let reminder = Reminder(context: testStack!.context)
        reminder.id = UUID()
        reminder.hour = 15
        reminder.minute = 30
        reminder.repeatsOn = NSArray(array: ["MONDAY", "wednesday", "FriDAY"])

        try await NotificationScheduler.schedule(reminder: reminder)

        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()

        let reminderId = try XCTUnwrap(reminder.id?.uuidString)

        // All should be scheduled regardless of case
        XCTAssertNotNil(pendingRequests.first { $0.identifier == "\(reminderId)-MONDAY" })
        XCTAssertNotNil(pendingRequests.first { $0.identifier == "\(reminderId)-wednesday" })
        XCTAssertNotNil(pendingRequests.first { $0.identifier == "\(reminderId)-FriDAY" })
    }

    func testNotificationContent() async throws {
        let reminder = Reminder(context: testStack!.context)
        reminder.id = UUID()
        reminder.hour = 11
        reminder.minute = 0
        reminder.repeatsOn = NSArray(array: [])

        try await NotificationScheduler.schedule(reminder: reminder)

        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()

        let request = pendingRequests.first { $0.identifier == reminder.id?.uuidString }
        XCTAssertNotNil(request)

        let content = try XCTUnwrap(request?.content)
        XCTAssertEqual(content.title, "Murmur: check in reminder")
        XCTAssertEqual(content.body, "Tap to record your symptoms, events and sleep.")
        XCTAssertEqual(content.sound, .default)
        XCTAssertEqual(content.interruptionLevel, .timeSensitive)
    }
}