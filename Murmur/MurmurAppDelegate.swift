import UIKit
import UserNotifications
import AppIntents

final class MurmurAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let healthKitAssistant = HealthKitAssistant()
    let calendarAssistant = CalendarAssistant()
    private(set) var manualCycleTracker: ManualCycleTracker?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register custom value transformers for Core Data
        PlacemarkTransformer.register()

        // Initialize manual cycle tracker with Core Data context
        let context = CoreDataStack.shared.context
        manualCycleTracker = ManualCycleTracker(context: context)
        healthKitAssistant.manualCycleTracker = manualCycleTracker

        UNUserNotificationCenter.current().delegate = self

        // Register app shortcuts for Siri and lock screen
        if #available(iOS 16.0, *) {
            Task {
                try? await MurmurAppShortcuts.updateAppShortcutParameters()
            }
        }

        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound, .banner, .list])
    }
}
