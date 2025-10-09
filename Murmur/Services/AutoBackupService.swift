//
//  AutoBackupService.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 07/10/2025.
//

import BackgroundTasks
import Foundation
import Security

/// Service for managing automatic daily and monthly backups with retention policy
@MainActor
final class AutoBackupService {
    static let shared = AutoBackupService()

    private let backupService = DataBackupService()
    private let fileManager = FileManager.default

    // Background task identifier
    static let backgroundTaskIdentifier = "com.aidancb.Murmur.autobackup"

    // UserDefaults keys
    private enum Keys {
        static let isEnabled = "autoBackupEnabled"
        static let lastBackupDate = "autoBackupLastDate"
    }

    // Keychain keys for auto-backup password
    private enum KeychainKeys {
        static let service = "com.aidancb.Murmur.autobackup"
        static let account = "password"
    }

    // Retention policy
    private let maxDailyBackups = 5
    private let maxMonthlyBackups = 3

    enum AutoBackupError: LocalizedError {
        case disabled
        case backupFailed(String)
        case keychainError

        var errorDescription: String? {
            switch self {
            case .disabled:
                return "Auto backup is disabled"
            case .backupFailed(let reason):
                return "Auto backup failed: \(reason)"
            case .keychainError:
                return "Failed to access secure storage"
            }
        }
    }

    struct BackupInfo: Identifiable {
        let id = UUID()
        let url: URL
        let date: Date
        let type: BackupType

        enum BackupType {
            case daily
            case monthly
        }

        var displayName: String {
            let formatter = DateFormatter()
            switch type {
            case .daily:
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return "Daily: \(formatter.string(from: date))"
            case .monthly:
                formatter.dateFormat = "MMMM yyyy"
                return "Monthly: \(formatter.string(from: date))"
            }
        }
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.isEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.isEnabled)
            if newValue {
                scheduleNextBackup()
            } else {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)
            }
        }
    }

    var lastBackupDate: Date? {
        UserDefaults.standard.object(forKey: Keys.lastBackupDate) as? Date
    }

    private init() {}

    // MARK: - Directory Management

    private var autoBackupsDirectory: URL {
        get throws {
            let documentsURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let backupsURL = documentsURL.appendingPathComponent("AutoBackups", isDirectory: true)

            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: backupsURL.path) {
                try fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)
            }

            return backupsURL
        }
    }

    // MARK: - Password Management

    private func getOrCreatePassword() throws -> String {
        // Try to retrieve existing password
        if let existingPassword = try? retrievePasswordFromKeychain() {
            return existingPassword
        }

        // Generate new secure password
        let password = generateSecurePassword()
        try savePasswordToKeychain(password)
        return password
    }

    private func generateSecurePassword() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
        return String((0..<32).compactMap { _ in characters.randomElement() })
    }

    private func savePasswordToKeychain(_ password: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw AutoBackupError.keychainError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.account,
            kSecValueData as String: passwordData
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AutoBackupError.keychainError
        }
    }

    func retrievePasswordFromKeychain() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainKeys.service,
            kSecAttrAccount as String: KeychainKeys.account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let passwordData = result as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw AutoBackupError.keychainError
        }

        return password
    }

    // MARK: - Backup Creation

    func performBackup() async throws {
        guard isEnabled else {
            throw AutoBackupError.disabled
        }

        let password = try getOrCreatePassword()
        let now = Date()
        let calendar = Calendar.current

        // Determine if we should create a monthly backup
        let shouldCreateMonthly = calendar.component(.day, from: now) == 1

        // Create daily backup
        try await createDailyBackup(date: now, password: password)

        // Create monthly backup if needed
        if shouldCreateMonthly {
            try await createMonthlyBackup(date: now, password: password)
        }

        // Prune old backups
        try pruneOldBackups()

        // Update last backup date
        UserDefaults.standard.set(now, forKey: Keys.lastBackupDate)
    }

    private func createDailyBackup(date: Date, password: String) async throws {
        let backupURL = try await backupService.createBackup(password: password)

        // Move to auto backups directory with proper naming
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let filename = "AutoBackup_daily_\(dateString).murmurbackup"

        let destinationURL = try autoBackupsDirectory.appendingPathComponent(filename)

        // Remove existing backup for this date if it exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: backupURL, to: destinationURL)
    }

    private func createMonthlyBackup(date: Date, password: String) async throws {
        let backupURL = try await backupService.createBackup(password: password)

        // Move to auto backups directory with proper naming
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let dateString = formatter.string(from: date)
        let filename = "AutoBackup_monthly_\(dateString).murmurbackup"

        let destinationURL = try autoBackupsDirectory.appendingPathComponent(filename)

        // Remove existing backup for this month if it exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: backupURL, to: destinationURL)
    }

    // MARK: - Backup Pruning

    private func pruneOldBackups() throws {
        let backupsDir = try autoBackupsDirectory
        let contents = try fileManager.contentsOfDirectory(
            at: backupsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )

        // Separate daily and monthly backups
        var dailyBackups: [(url: URL, date: Date)] = []
        var monthlyBackups: [(url: URL, date: Date)] = []

        for url in contents {
            guard url.pathExtension == "murmurbackup" else { continue }

            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let creationDate = attributes[.creationDate] as? Date else { continue }

            if url.lastPathComponent.contains("_daily_") {
                dailyBackups.append((url, creationDate))
            } else if url.lastPathComponent.contains("_monthly_") {
                monthlyBackups.append((url, creationDate))
            }
        }

        // Sort by date (newest first)
        dailyBackups.sort { $0.date > $1.date }
        monthlyBackups.sort { $0.date > $1.date }

        // Remove excess daily backups
        if dailyBackups.count > maxDailyBackups {
            for backup in dailyBackups[maxDailyBackups...] {
                try fileManager.removeItem(at: backup.url)
            }
        }

        // Remove excess monthly backups
        if monthlyBackups.count > maxMonthlyBackups {
            for backup in monthlyBackups[maxMonthlyBackups...] {
                try fileManager.removeItem(at: backup.url)
            }
        }
    }

    // MARK: - Backup Listing

    func listBackups() throws -> [BackupInfo] {
        let backupsDir = try autoBackupsDirectory
        let contents = try fileManager.contentsOfDirectory(
            at: backupsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )

        var backups: [BackupInfo] = []

        for url in contents {
            guard url.pathExtension == "murmurbackup" else { continue }

            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let creationDate = attributes[.creationDate] as? Date else { continue }

            let type: BackupInfo.BackupType = url.lastPathComponent.contains("_daily_") ? .daily : .monthly
            backups.append(BackupInfo(url: url, date: creationDate, type: type))
        }

        // Sort by date (newest first)
        return backups.sorted { $0.date > $1.date }
    }

    // MARK: - Restore

    func restoreBackup(from backupInfo: BackupInfo) async throws {
        let password = try retrievePasswordFromKeychain()
        try await backupService.restoreBackup(from: backupInfo.url, password: password)
    }

    // MARK: - Background Task Scheduling

    func scheduleNextBackup() {
        guard isEnabled else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)

        // Schedule for tomorrow at 3 AM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day? += 1
        components.hour = 3
        components.minute = 0

        if let scheduledDate = calendar.date(from: components) {
            request.earliestBeginDate = scheduledDate
        }

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Silently fail - task will be rescheduled
        }
    }

    func handleBackgroundTask(_ task: BGTask) {
        // Schedule next backup
        scheduleNextBackup()

        // Create task to perform backup
        let backupTask = Task {
            do {
                try await performBackup()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        // Set expiration handler to cancel if needed
        task.expirationHandler = {
            backupTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Manual Trigger

    func performBackupIfNeeded() async {
        guard isEnabled else { return }

        // Check if we need to backup (more than 23 hours since last backup)
        if let lastDate = lastBackupDate {
            let timeSinceLastBackup = Date().timeIntervalSince(lastDate)
            guard timeSinceLastBackup > 23 * 60 * 60 else { return }
        }

        do {
            try await performBackup()
        } catch {
            // Silently fail
        }
    }
}
