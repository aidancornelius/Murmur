import Foundation
import UserNotifications

struct NotificationScheduler {
    static func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        let granted = try await center.requestAuthorization(options: options)
        guard granted else { throw SchedulerError.authorizationDenied }
    }

    static func schedule(reminder: Reminder) async throws {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Time to check in"
        content.body = "Tap to record how you're feeling."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let date = DateComponents(hour: Int(reminder.hour), minute: Int(reminder.minute))
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: reminder.id?.uuidString ?? UUID().uuidString, content: content, trigger: trigger)
        try await center.add(request)
    }

    static func remove(reminder: Reminder) {
        guard let id = reminder.id else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    enum SchedulerError: Error {
        case authorizationDenied
    }
}
