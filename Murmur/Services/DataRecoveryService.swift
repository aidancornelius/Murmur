// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DataRecoveryService.swift
// Detects empty database with available backup for recovery prompts.
//
import CoreData
import Foundation

/// Service that detects when the database is unexpectedly empty but backups exist
@MainActor
final class DataRecoveryService {
    static let shared = DataRecoveryService()

    private let autoBackupService = AutoBackupService.shared
    private let backupService = DataBackupService()

    struct RecoveryInfo {
        let backup: AutoBackupService.BackupInfo
        let metadata: DataBackupService.BackupMetadata
    }

    private init() {}

    /// Checks if recovery should be offered to the user.
    /// Returns recovery info if:
    /// - Database has no symptom entries
    /// - User hasn't deliberately reset their data
    /// - A backup exists with entries
    /// - User hasn't dismissed the recovery prompt recently (within 24 hours)
    func checkForRecoveryOpportunity(context: NSManagedObjectContext) async -> RecoveryInfo? {
        // Skip if user deliberately reset their data
        if UserDefaults.standard.bool(forKey: UserDefaultsKeys.deliberateDataReset) {
            return nil
        }

        // Skip if user dismissed recovery prompt recently (within 24 hours)
        if let lastDismissed = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastRecoveryPromptDismissed) as? Date {
            if Date().timeIntervalSince(lastDismissed) < 24 * 60 * 60 {
                return nil
            }
        }

        // Check if database has entries
        let hasEntries = await checkDatabaseHasEntries(context: context)
        if hasEntries {
            // Clear the deliberate reset flag since we have data now
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.deliberateDataReset)
            return nil
        }

        // Check for backups with data
        return await findRecoverableBackup()
    }

    private func checkDatabaseHasEntries(context: NSManagedObjectContext) async -> Bool {
        await context.perform {
            // Check for any symptom entries
            let entryRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
            entryRequest.fetchLimit = 1
            let entryCount = (try? context.count(for: entryRequest)) ?? 0

            // Check for any activities
            let activityRequest: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
            activityRequest.fetchLimit = 1
            let activityCount = (try? context.count(for: activityRequest)) ?? 0

            // Check for any sleep events
            let sleepRequest: NSFetchRequest<SleepEvent> = SleepEvent.fetchRequest()
            sleepRequest.fetchLimit = 1
            let sleepCount = (try? context.count(for: sleepRequest)) ?? 0

            // Check for any meal events
            let mealRequest: NSFetchRequest<MealEvent> = MealEvent.fetchRequest()
            mealRequest.fetchLimit = 1
            let mealCount = (try? context.count(for: mealRequest)) ?? 0

            return entryCount > 0 || activityCount > 0 || sleepCount > 0 || mealCount > 0
        }
    }

    private func findRecoverableBackup() async -> RecoveryInfo? {
        // Get auto backups
        guard let backups = try? autoBackupService.listBackups(),
              let latestBackup = backups.first else {
            return nil
        }

        // Try to read backup metadata to see if it has entries
        guard let password = try? autoBackupService.retrievePasswordFromKeychain() else {
            return nil
        }

        guard let metadata = try? await backupService.readBackupMetadata(
            from: latestBackup.url,
            password: password
        ) else {
            return nil
        }

        // Only offer recovery if backup has meaningful data
        let totalItems = metadata.entryCount + metadata.activityCount +
                         metadata.sleepEventCount + metadata.mealEventCount
        if totalItems > 0 {
            return RecoveryInfo(backup: latestBackup, metadata: metadata)
        }

        return nil
    }

    /// Call this when user dismisses the recovery prompt without restoring
    func dismissRecoveryPrompt() {
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.lastRecoveryPromptDismissed)
    }

    /// Call this after a successful restore to clear the deliberate reset flag
    func clearDeliberateResetFlag() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.deliberateDataReset)
    }
}
