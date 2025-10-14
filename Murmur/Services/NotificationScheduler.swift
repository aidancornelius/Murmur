//
//  NotificationScheduler.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import Foundation
import UserNotifications

struct NotificationScheduler {
    private static let weekdayLookup: [String: Int] = [
        "sunday": 1,
        "monday": 2,
        "tuesday": 3,
        "wednesday": 4,
        "thursday": 5,
        "friday": 6,
        "saturday": 7
    ]

    static func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        let granted = try await center.requestAuthorization(options: options)
        guard granted else { throw SchedulerError.authorizationDenied }
    }

    static func schedule(reminder: Reminder) async throws {
        let center = UNUserNotificationCenter.current()

        // Check if we're running in a test environment
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        // Check authorization status and request if needed (skip in tests)
        if !isRunningTests {
            let settings = await center.notificationSettings()

            if settings.authorizationStatus == .notDetermined {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                guard granted else {
                    throw SchedulerError.authorizationDenied
                }
            } else if settings.authorizationStatus == .denied {
                throw SchedulerError.authorizationDenied
            }
        }

        let content = UNMutableNotificationContent()
        content.title = "Murmur: check in reminder"
        content.body = "Tap to record your symptoms, events and sleep."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        guard let identifier = reminder.id?.uuidString else {
            throw SchedulerError.missingIdentifier
        }

        let repeats = (reminder.repeatsOn as? [String]) ?? []
        let identifiersToRemove: [String]
        if repeats.isEmpty {
            identifiersToRemove = [identifier]
        } else {
            identifiersToRemove = repeats.map { "\(identifier)-\($0)" }
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove + [identifier])

        let baseComponents = DateComponents(hour: Int(reminder.hour), minute: Int(reminder.minute))

        if repeats.isEmpty {
            let trigger = UNCalendarNotificationTrigger(dateMatching: baseComponents, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try await center.add(request)
        } else {
            for day in repeats {
                guard let weekday = weekdayLookup[day.lowercased()] else { continue }
                var components = baseComponents
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(identifier: "\(identifier)-\(day)", content: content, trigger: trigger)
                try await center.add(request)
            }
        }
    }

    static func remove(reminder: Reminder) async {
        guard let id = reminder.id else { return }
        let center = UNUserNotificationCenter.current()

        // Get all pending requests and filter by ID prefix
        let allRequests = await center.pendingNotificationRequests()
        let identifiersToRemove = allRequests
            .filter { $0.identifier.starts(with: id.uuidString) }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
    }

    enum SchedulerError: Error {
        case authorizationDenied
        case missingIdentifier
    }
}
