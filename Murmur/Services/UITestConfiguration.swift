//
//  UITestConfiguration.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import Foundation
import CoreData
import os.log

/// Handles launch arguments for UI testing
struct UITestConfiguration {
    private static let logger = Logger(subsystem: "app.murmur", category: "UITestConfiguration")

    // MARK: - Test Mode Detection

    static var isUITesting: Bool {
        CommandLine.arguments.contains("-UITestMode")
    }

    // MARK: - Data Seeding Arguments

    static var shouldSeedSampleData: Bool {
        CommandLine.arguments.contains("-SeedSampleData")
    }

    static var shouldSeedLargeDataSet: Bool {
        CommandLine.arguments.contains("-SeedLargeDataSet")
    }

    static var shouldUseEmptyState: Bool {
        CommandLine.arguments.contains("-EmptyState")
    }

    static var shouldSimulateFreshInstall: Bool {
        CommandLine.arguments.contains("-FreshInstall")
    }

    static var shouldSeedMinimumData: Bool {
        CommandLine.arguments.contains("-MinimumData")
    }

    static var shouldSeedMultipleSymptoms: Bool {
        CommandLine.arguments.contains("-MultipleSymptoms")
    }

    static var shouldSeedLongHistory: Bool {
        CommandLine.arguments.contains("-LongHistory")
    }

    static var shouldSeedRecentOnly: Bool {
        CommandLine.arguments.contains("-RecentOnly")
    }

    // MARK: - Feature Flags

    static var shouldDisableHealthKit: Bool {
        CommandLine.arguments.contains("-DisableHealthKit")
    }

    static var shouldDisableLocation: Bool {
        CommandLine.arguments.contains("-DisableLocation")
    }

    static var shouldDisableCalendar: Bool {
        CommandLine.arguments.contains("-DisableCalendar")
    }

    static var shouldDisableNotifications: Bool {
        CommandLine.arguments.contains("-DisableNotifications")
    }

    static var shouldSkipOnboarding: Bool {
        CommandLine.arguments.contains("-SkipOnboarding")
    }

    static var shouldShowOnboarding: Bool {
        CommandLine.arguments.contains("-ShowOnboarding")
    }

    // MARK: - Debugging & Simulation

    static var shouldEnableDebugLogging: Bool {
        CommandLine.arguments.contains("-EnableDebugLogging")
    }

    static var shouldEnablePerformanceMonitoring: Bool {
        CommandLine.arguments.contains("-EnablePerformanceMonitoring")
    }

    static var shouldSimulateLowStorage: Bool {
        CommandLine.arguments.contains("-LowStorage")
    }

    static var shouldSimulateOfflineMode: Bool {
        CommandLine.arguments.contains("-OfflineMode")
    }

    static var shouldSimulateUpdate: Bool {
        CommandLine.arguments.contains("-SimulateUpdate")
    }

    // MARK: - Configuration

    /// Configure the app for UI testing based on launch arguments
    /// - Parameter context: The Core Data managed object context
    static func configure(context: NSManagedObjectContext) {
        guard isUITesting else {
            logger.debug("Not in UI test mode, skipping configuration")
            return
        }

        logger.info("Configuring app for UI testing")

        // Always skip onboarding in UI test mode unless explicitly told to show it
        if !shouldShowOnboarding {
            logger.info("Skipping onboarding for UI tests")
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        }

        // Handle fresh install (clears everything)
        if shouldSimulateFreshInstall {
            logger.info("Simulating fresh install")
            clearAllData(context: context)
            clearUserDefaults()
            SampleDataSeeder.seedIfNeeded(in: context, forceSeed: true)
            return
        }

        // Handle empty state (clears data but keeps symptom types)
        if shouldUseEmptyState {
            logger.info("Clearing data for empty state")
            clearAllData(context: context, preserveSymptomTypes: true)
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
            return
        }

        // Handle data seeding (priority order)
        #if targetEnvironment(simulator)
        if shouldSeedLargeDataSet {
            logger.info("Seeding large data set")
            clearAllData(context: context, preserveSymptomTypes: true)
            SampleDataSeeder.seedIfNeeded(in: context, forceSeed: true)
            SampleDataSeeder.generateLargeDataSet(in: context)
        } else if shouldSeedLongHistory {
            logger.info("Seeding long history")
            clearAllData(context: context, preserveSymptomTypes: true)
            SampleDataSeeder.seedIfNeeded(in: context, forceSeed: true)
            SampleDataSeeder.generateLongHistory(in: context)
        } else if shouldSeedSampleData {
            logger.info("Seeding sample data")
            UserDefaults.standard.set(false, forKey: UserDefaultsKeys.hasGeneratedSampleData)
            SampleDataSeeder.seedIfNeeded(in: context, forceSeed: true)
            SampleDataSeeder.generateSampleEntries(in: context)
        } else if shouldSeedMinimumData {
            logger.info("Seeding minimum data")
            clearAllData(context: context, preserveSymptomTypes: true)
            SampleDataSeeder.seedIfNeeded(in: context, forceSeed: true)
            SampleDataSeeder.generateMinimumData(in: context)
        } else if shouldSeedRecentOnly {
            logger.info("Seeding recent data only")
            clearAllData(context: context, preserveSymptomTypes: true)
            SampleDataSeeder.seedIfNeeded(in: context, forceSeed: true)
            SampleDataSeeder.generateRecentData(in: context)
        }
        #else
        // Data generation methods only available in simulator - just seed default types
        SampleDataSeeder.seedIfNeeded(in: context, forceSeed: true)
        logger.warning("Sample data generation is only available in simulator builds")
        #endif

        logger.info("UI test configuration complete")
    }

    // MARK: - Helper Methods

    private static func clearAllData(context: NSManagedObjectContext, preserveSymptomTypes: Bool = false) {
        context.performAndWait {
            // Clear symptom entries
            let entryRequest: NSFetchRequest<NSFetchRequestResult> = SymptomEntry.fetchRequest()
            let deleteEntries = NSBatchDeleteRequest(fetchRequest: entryRequest)
            _ = try? context.execute(deleteEntries)

            // Clear activity events
            let activityRequest: NSFetchRequest<NSFetchRequestResult> = ActivityEvent.fetchRequest()
            let deleteActivities = NSBatchDeleteRequest(fetchRequest: activityRequest)
            _ = try? context.execute(deleteActivities)

            // Clear sleep events
            let sleepRequest: NSFetchRequest<NSFetchRequestResult> = SleepEvent.fetchRequest()
            let deleteSleep = NSBatchDeleteRequest(fetchRequest: sleepRequest)
            _ = try? context.execute(deleteSleep)

            // Clear meal events
            let mealRequest: NSFetchRequest<NSFetchRequestResult> = MealEvent.fetchRequest()
            let deleteMeals = NSBatchDeleteRequest(fetchRequest: mealRequest)
            _ = try? context.execute(deleteMeals)

            // Clear symptom types if not preserving
            if !preserveSymptomTypes {
                let typeRequest: NSFetchRequest<NSFetchRequestResult> = SymptomType.fetchRequest()
                let deleteTypes = NSBatchDeleteRequest(fetchRequest: typeRequest)
                _ = try? context.execute(deleteTypes)
            }

            // Reset context
            context.reset()
            try? context.save()

            logger.debug("Cleared all data (preserveSymptomTypes: \(preserveSymptomTypes))")
        }
    }

    private static func clearUserDefaults() {
        guard let domain = Bundle.main.bundleIdentifier else {
            logger.error("Failed to get bundle identifier for clearing UserDefaults")
            return
        }
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        logger.debug("Cleared UserDefaults")
    }
}
