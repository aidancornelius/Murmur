// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// MurmurAppDelegate.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Application delegate handling lifecycle events and background tasks.
//
import UIKit
import UserNotifications
import AppIntents
import BackgroundTasks

@MainActor
final class MurmurAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, ObservableObject {
    let healthKitAssistant: HealthKitAssistant
    let calendarAssistant: CalendarAssistant
    let sleepImportService: SleepImportService
    @Published private(set) var manualCycleTracker: ManualCycleTracker?

    // Resource manager for coordinated lifecycle management
    let resourceManager = ResourceManager()

    /// Error from Core Data stack initialization, if any
    @Published private(set) var coreDataError: Error?

    override init() {
        // Conditionally initialize services based on UI test flags
        self.healthKitAssistant = UITestConfiguration.shouldDisableHealthKit ? HealthKitAssistant() : HealthKitAssistant()
        self.calendarAssistant = UITestConfiguration.shouldDisableCalendar ? CalendarAssistant() : CalendarAssistant()
        self.sleepImportService = SleepImportService()
        super.init()

        // Connect sleep import service to HealthKit
        sleepImportService.setHealthKit(healthKitAssistant)

        // Register non-Core Data services with resource manager
        Task {
            try? await resourceManager.register(healthKitAssistant)
            try? await resourceManager.register(calendarAssistant)
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register custom value transformers for Core Data
        PlacemarkTransformer.register()

        // Start Core Data asynchronously, then initialize dependent services
        Task { @MainActor in
            // Start Core Data stack and capture any initialization errors
            do {
                try await CoreDataStack.shared.start()
                try await resourceManager.register(CoreDataStack.shared)

                // Initialize manual cycle tracker after Core Data is ready
                let context = CoreDataStack.shared.context
                self.manualCycleTracker = ManualCycleTracker(context: context)
                self.healthKitAssistant.manualCycleTracker = self.manualCycleTracker

                // Register manual cycle tracker with resource manager
                if let tracker = self.manualCycleTracker {
                    try? await resourceManager.register(tracker)
                }
            } catch {
                self.coreDataError = error
            }
        }

        // Configure notification delegate (unless disabled for UI tests)
        if !UITestConfiguration.shouldDisableNotifications {
            UNUserNotificationCenter.current().delegate = self
        }

        // Register app shortcuts for Siri and lock screen (unless in UI test mode)
        if !UITestConfiguration.isUITesting {
            if #available(iOS 16.0, *) {
                MurmurAppShortcuts.updateAppShortcutParameters()
            }
        }

        // Register background task for auto backups (unless in UI test mode)
        if !UITestConfiguration.isUITesting {
            registerBackgroundTasks()

            // Ensure backup is scheduled if enabled
            Task { @MainActor in
                if AutoBackupService.shared.isEnabled {
                    AutoBackupService.shared.scheduleNextBackup()
                    await AutoBackupService.shared.performBackupIfNeeded()
                }
            }
        }

        // Configure UIKit appearance for forms
        configureFormAppearance()

        return true
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AutoBackupService.backgroundTaskIdentifier,
            using: DispatchQueue.global()
        ) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                AutoBackupService.shared.handleBackgroundTask(appRefreshTask)
            }
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Attempt backup if needed when entering background
        Task { @MainActor in
            await AutoBackupService.shared.performBackupIfNeeded()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Clean up all managed resources before termination
        Task {
            await resourceManager.cleanupAll()
        }
    }

    private func configureFormAppearance() {
        // Clear default form backgrounds
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear

        // Configure text field appearances
        UITextField.appearance().backgroundColor = .clear
        UITextField.appearance().textColor = .label

        // Configure section header/footer
        UITableViewHeaderFooterView.appearance().tintColor = .clear
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound, .banner, .list])
    }
}
