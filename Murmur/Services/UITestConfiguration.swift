//
//  UITestConfiguration.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import Foundation
import CoreData
import os.log

#if targetEnvironment(simulator)
import HealthKitTestData
#endif

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

    // MARK: - HealthKit Seeding Arguments

    static var shouldSeedHealthKitNormal: Bool {
        CommandLine.arguments.contains("-SeedHealthKitNormal")
    }

    static var shouldSeedHealthKitLowerStress: Bool {
        CommandLine.arguments.contains("-SeedHealthKitLowerStress")
    }

    static var shouldSeedHealthKitHigherStress: Bool {
        CommandLine.arguments.contains("-SeedHealthKitHigherStress")
    }

    static var shouldSeedHealthKitEdgeCases: Bool {
        CommandLine.arguments.contains("-SeedHealthKitEdgeCases")
    }

    static var shouldEnableLiveHealthData: Bool {
        CommandLine.arguments.contains("-EnableLiveHealthData")
    }

    static var healthKitHistoryDays: Int {
        // Look for -HealthKitHistoryDays N pattern
        if let index = CommandLine.arguments.firstIndex(of: "-HealthKitHistoryDays"),
           index + 1 < CommandLine.arguments.count,
           let days = Int(CommandLine.arguments[index + 1]) {
            return days
        }
        return 7 // Default to 7 days
    }

    static var healthKitSeed: Int {
        // Look for -HealthKitSeed N pattern
        if let index = CommandLine.arguments.firstIndex(of: "-HealthKitSeed"),
           index + 1 < CommandLine.arguments.count,
           let seed = Int(CommandLine.arguments[index + 1]) {
            return seed
        }
        return 42 // Default to deterministic seed
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

    // MARK: - Time Override

    static var overrideTime: Date? {
        // Look for -OverrideTime HH:MM pattern
        if let index = CommandLine.arguments.firstIndex(of: "-OverrideTime"),
           index + 1 < CommandLine.arguments.count {
            let timeString = CommandLine.arguments[index + 1]
            let components = timeString.split(separator: ":")
            guard components.count == 2,
                  let hour = Int(components[0]),
                  let minute = Int(components[1]) else {
                return nil
            }

            // Create a date for today at the specified time
            let calendar = Calendar.current
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.second = 0

            return calendar.date(from: dateComponents)
        }
        return nil
    }

    // MARK: - Configuration

    /// Configure the app for UI testing based on launch arguments
    /// - Parameter context: The Core Data managed object context
    static func configure(context: NSManagedObjectContext) async {
        guard isUITesting else {
            logger.debug("Not in UI test mode, skipping configuration")
            return
        }

        logger.info("Configuring app for UI testing")

        // Seed HealthKit data FIRST, before any other configuration
        #if targetEnvironment(simulator)
        await configureHealthKitSeeding()

        // If we seeded HealthKit data, also generate Core Data sample entries for analysis views
        // Only do this once to avoid duplicates
        if (shouldSeedHealthKitNormal || shouldSeedHealthKitLowerStress ||
           shouldSeedHealthKitHigherStress || shouldSeedHealthKitEdgeCases) {
            let hasGeneratedSampleData = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasGeneratedSampleData)
            logger.info("HealthKit test mode: hasGeneratedSampleData = \(hasGeneratedSampleData)")

            if !hasGeneratedSampleData {
                logger.info("Seeding Core Data sample entries to complement HealthKit data")
                await context.perform {
                    SampleDataSeeder.seedIfNeeded(in: context, forceSeed: true)
                    // Generate sample data matching the history days
                    if healthKitHistoryDays >= 30 {
                        SampleDataSeeder.generateLongHistory(in: context)
                    } else {
                        SampleDataSeeder.generateSampleEntries(in: context)
                    }
                }
                UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasGeneratedSampleData)
                logger.info("Core Data sample entries seeded successfully")
            } else {
                logger.info("Core Data sample entries already seeded, checking entry count...")
                await context.perform {
                    let entryRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
                    let activityRequest: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
                    let entryCount = (try? context.count(for: entryRequest)) ?? 0
                    let activityCount = (try? context.count(for: activityRequest)) ?? 0
                    logger.info("Found \(entryCount) symptom entries and \(activityCount) activities in database")
                }
            }
        }
        #endif

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

    // MARK: - HealthKit Configuration

    #if targetEnvironment(simulator)
    private static func configureHealthKitSeeding() async {
        guard shouldSeedHealthKitNormal || shouldSeedHealthKitLowerStress ||
              shouldSeedHealthKitHigherStress || shouldSeedHealthKitEdgeCases else {
            logger.debug("No HealthKit seeding flags detected, skipping HealthKit configuration")
            return
        }

        // Check if we've already seeded HealthKit data to avoid clearing it on subsequent launches
        let hasSeededKey = UserDefaultsKeys.hasSeededHealthKitData
        if UserDefaults.standard.bool(forKey: hasSeededKey) {
            logger.info("HealthKit data already seeded, skipping re-seed to preserve data")
            return
        }

        logger.info("Configuring HealthKit data seeding for UI tests")

        // Determine which preset to use
        let preset: GenerationPreset
        if shouldSeedHealthKitNormal {
            preset = .normal
            logger.info("Using normal health data preset")
        } else if shouldSeedHealthKitLowerStress {
            preset = .lowerStress
            logger.info("Using lower stress preset")
        } else if shouldSeedHealthKitHigherStress {
            preset = .higherStress
            logger.info("Using higher stress preset")
        } else {
            preset = .edgeCases
            logger.info("Using edge cases preset")
        }

        do {
            // Seed historical data with explicit seed for determinism
            let seed = healthKitSeed
            try await HealthKitDataSeeder.seedDefaultData(
                preset: preset,
                daysOfHistory: healthKitHistoryDays,
                seed: seed
            )
            logger.info("Successfully seeded \(healthKitHistoryDays) days of HealthKit data with seed: \(seed)")

            // Mark as seeded so we don't clear it on next launch
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasSeededHealthKitData)

            // Start live data stream if requested
            if shouldEnableLiveHealthData {
                _ = try await HealthKitDataSeeder.startLiveDataStream(preset: preset)
                logger.info("Started live HealthKit data streaming")
            }
        } catch {
            logger.error("Failed to seed HealthKit data: \(error.localizedDescription)")
        }
    }
    #endif

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
        // Also clear the HealthKit seeded flag to allow re-seeding
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hasSeededHealthKitData)
        logger.debug("Cleared UserDefaults")
    }
}
