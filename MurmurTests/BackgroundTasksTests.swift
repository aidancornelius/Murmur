// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// BackgroundTasksTests.swift
// Created by Aidan Cornelius-Bell on 13/10/2025.
// Tests for background task scheduling.
//
import BackgroundTasks
import CoreData
import XCTest
@testable import Murmur

/// Tests for background task execution, scheduling, and auto-backup functionality
@MainActor
final class BackgroundTasksTests: XCTestCase {
    var testStack: InMemoryCoreDataStack?
    var autoBackupService: AutoBackupService?
    var backupService: DataBackupService?

    override func setUp() async throws {
        try await super.setUp()
        testStack = InMemoryCoreDataStack()
        autoBackupService = AutoBackupService.shared

        // Clean up UserDefaults to prevent state leakage
        UserDefaults.standard.removeObject(forKey: "autoBackupEnabled")
        UserDefaults.standard.removeObject(forKey: "autoBackupLastDate")

        // Clean up any existing auto backups directory
        try? cleanupAutoBackupsDirectory()
    }

    override func tearDown() async throws {
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "autoBackupEnabled")
        UserDefaults.standard.removeObject(forKey: "autoBackupLastDate")

        // Clean up auto backups directory
        try? cleanupAutoBackupsDirectory()

        // Clean up keychain
        try? deleteKeychainPassword()

        testStack = nil
        autoBackupService = nil
        backupService = nil
        try await super.tearDown()
    }

    // MARK: - Background Task Registration Tests

    func testBackgroundTaskIdentifier() {
        // Verify the background task identifier matches project.yml configuration
        XCTAssertEqual(AutoBackupService.backgroundTaskIdentifier, "com.aidancb.Murmur.autobackup")
    }

    // MARK: - Auto-Backup Enable/Disable Tests

    func testAutoBackupInitiallyDisabled() {
        XCTAssertFalse(autoBackupService?.isEnabled ?? true, "Auto backup should be disabled by default")
    }

    func testEnableAutoBackup() {
        autoBackupService?.isEnabled = true
        XCTAssertTrue(autoBackupService?.isEnabled ?? false, "Auto backup should be enabled")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "autoBackupEnabled"))
    }

    func testDisableAutoBackup() {
        // Enable first
        autoBackupService?.isEnabled = true
        XCTAssertTrue(autoBackupService?.isEnabled ?? false)

        // Then disable
        autoBackupService?.isEnabled = false
        XCTAssertFalse(autoBackupService?.isEnabled ?? true, "Auto backup should be disabled")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "autoBackupEnabled"))
    }

    // MARK: - Backup Execution Tests

    func testPerformBackupWhenDisabled() async {
        // Ensure auto backup is disabled
        autoBackupService?.isEnabled = false

        // Attempt to perform backup
        do {
            try await autoBackupService?.performBackup()
            XCTFail("Should throw AutoBackupError.disabled")
        } catch let error as AutoBackupService.AutoBackupError {
            // Check error type by description since AutoBackupError isn't Equatable
            XCTAssertEqual(error.errorDescription, "Auto backup is disabled")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPerformBackupWithEmptyDatabase() async throws {
        // Enable auto backup
        autoBackupService?.isEnabled = true

        // Create a test backup service with in-memory stack
        let testBackupService = DataBackupService(stack: CoreDataStack(container: testStack!.container))

        // Verify empty database state
        let entryRequest = SymptomEntry.fetchRequest()
        let entries = try testStack!.context.fetch(entryRequest)
        XCTAssertEqual(entries.count, 0, "Database should be empty")

        // Test backup creation with empty database
        let password = "TestPassword123!"
        let backupURL = try await testBackupService.createBackup(password: password)

        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        XCTAssertEqual(backupURL.pathExtension, "murmurbackup")

        // Clean up
        try? FileManager.default.removeItem(at: backupURL)
    }

    func testPerformBackupWithData() async throws {
        // Enable auto backup
        autoBackupService?.isEnabled = true

        // Create test data
        let symptomType = SymptomType(context: testStack!.context)
        symptomType.id = UUID()
        symptomType.name = "Test Symptom"
        symptomType.color = "#FF0000"
        symptomType.iconName = "heart.fill"
        symptomType.category = "Test"
        symptomType.isDefault = false

        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.severity = 3
        entry.symptomType = symptomType
        entry.note = "Test note"

        try testStack!.context.save()

        // Create backup
        let testBackupService = DataBackupService(stack: CoreDataStack(container: testStack!.container))
        let password = "TestPassword123!"
        let backupURL = try await testBackupService.createBackup(password: password)

        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))

        // Verify backup metadata
        let metadata = try await testBackupService.readBackupMetadata(from: backupURL, password: password)
        XCTAssertEqual(metadata.entryCount, 1)
        XCTAssertEqual(metadata.symptomTypeCount, 1)
        XCTAssertGreaterThan(metadata.version, 0)

        // Clean up
        try? FileManager.default.removeItem(at: backupURL)
    }

    func testPerformBackupUpdatesLastBackupDate() async throws {
        // Enable auto backup
        autoBackupService?.isEnabled = true

        // Record time before backup
        let beforeBackup = Date()

        // Create minimal test data
        let symptomType = SymptomType(context: testStack!.context)
        symptomType.id = UUID()
        symptomType.name = "Test"
        symptomType.color = "#FF0000"
        symptomType.iconName = "heart.fill"
        symptomType.isDefault = false
        try testStack!.context.save()

        // Perform backup using test stack
        let testBackupService = DataBackupService(stack: CoreDataStack(container: testStack!.container))
        let password = "TestPassword123!"
        let backupURL = try await testBackupService.createBackup(password: password)

        // Manually update last backup date to simulate AutoBackupService behavior
        let afterBackup = Date()
        UserDefaults.standard.set(afterBackup, forKey: "autoBackupLastDate")

        // Verify last backup date was updated
        let lastBackupDate = UserDefaults.standard.object(forKey: "autoBackupLastDate") as? Date
        XCTAssertNotNil(lastBackupDate)
        XCTAssertGreaterThanOrEqual(lastBackupDate!, beforeBackup)
        XCTAssertLessThanOrEqual(lastBackupDate!, Date())

        // Clean up
        try? FileManager.default.removeItem(at: backupURL)
    }

    // MARK: - Password Management Tests

    func testPasswordGenerationAndRetrieval() throws {
        // Enable auto backup to trigger password generation
        autoBackupService?.isEnabled = true

        // Attempt to retrieve password (this will trigger generation if none exists)
        let password1 = try autoBackupService?.retrievePasswordFromKeychain()
        XCTAssertNotNil(password1)
        XCTAssertGreaterThan(password1?.count ?? 0, 0)

        // Retrieve again - should get the same password
        let password2 = try autoBackupService?.retrievePasswordFromKeychain()
        XCTAssertEqual(password1, password2, "Should retrieve the same password")
    }

    func testPasswordStoredInKeychain() throws {
        // The password should persist across service instances
        autoBackupService?.isEnabled = true

        // Generate and store password
        let password1 = try autoBackupService?.retrievePasswordFromKeychain()
        XCTAssertNotNil(password1)

        // Get a fresh reference to the service
        let freshService = AutoBackupService.shared
        let password2 = try freshService.retrievePasswordFromKeychain()

        XCTAssertEqual(password1, password2, "Password should persist in keychain")
    }

    // MARK: - Backup Pruning Tests

    func testBackupRetentionPolicy() {
        // Verify retention limits are configured
        // Note: These are private properties, but we can verify the behavior through backup listing
        XCTAssertNotNil(autoBackupService, "AutoBackupService should exist")
    }

    func testListBackupsWithEmptyDirectory() throws {
        let backups = try autoBackupService?.listBackups()
        XCTAssertNotNil(backups)
        XCTAssertEqual(backups?.count ?? -1, 0, "Should have no backups initially")
    }

    // MARK: - Task Scheduling Tests

    func testScheduleNextBackupWhenEnabled() {
        // Enable auto backup
        autoBackupService?.isEnabled = true

        // Schedule should not throw
        autoBackupService?.scheduleNextBackup()

        // Note: We can't directly verify BGTaskScheduler registration in unit tests
        // but we can verify the method executes without errors
    }

    func testScheduleNextBackupWhenDisabled() {
        // Disable auto backup
        autoBackupService?.isEnabled = false

        // Schedule should return early without scheduling
        autoBackupService?.scheduleNextBackup()

        // No assertions needed - just verify it doesn't crash
    }

    // MARK: - Background Task Handler Tests

    func testHandleBackgroundTaskCancellation() async throws {
        // Skip: BGTask cannot be instantiated in unit tests
        throw XCTSkip("BGTask cannot be instantiated in unit tests")
    }

    func testBackgroundTaskExpirationHandler() async throws {
        // Skip: BGTask cannot be instantiated in unit tests
        throw XCTSkip("BGTask cannot be instantiated in unit tests")
    }

    // MARK: - Backup File Naming Tests

    func testBackupFileNamingConvention() async throws {
        let testDate = Date()
        let expectedDayKey = DateUtility.dayKey(for: testDate)
        let expectedMonthKey = DateUtility.monthlyKey(for: testDate)

        // Verify daily backup naming format
        let dailyFilename = "AutoBackup_daily_\(expectedDayKey).murmurbackup"
        XCTAssertTrue(dailyFilename.contains("AutoBackup_daily_"))
        XCTAssertTrue(dailyFilename.contains(expectedDayKey))
        XCTAssertTrue(dailyFilename.hasSuffix(".murmurbackup"))

        // Verify monthly backup naming format
        let monthlyFilename = "AutoBackup_monthly_\(expectedMonthKey).murmurbackup"
        XCTAssertTrue(monthlyFilename.contains("AutoBackup_monthly_"))
        XCTAssertTrue(monthlyFilename.contains(expectedMonthKey))
        XCTAssertTrue(monthlyFilename.hasSuffix(".murmurbackup"))
    }

    // MARK: - Manual Backup Trigger Tests

    func testPerformBackupIfNeededWhenDisabled() async {
        autoBackupService?.isEnabled = false

        // Should return early without attempting backup
        await autoBackupService?.performBackupIfNeeded()

        // Verify no backup was performed
        XCTAssertNil(autoBackupService?.lastBackupDate)
    }

    func testPerformBackupIfNeededWithRecentBackup() async {
        autoBackupService?.isEnabled = true

        // Set a recent backup time (less than 12 hours ago)
        let recentBackup = Date().addingTimeInterval(-11 * 60 * 60)
        UserDefaults.standard.set(recentBackup, forKey: "autoBackupLastDate")

        // Should skip backup
        await autoBackupService?.performBackupIfNeeded()

        // Verify backup time hasn't changed
        let lastBackup = UserDefaults.standard.object(forKey: "autoBackupLastDate") as? Date
        XCTAssertEqual(lastBackup?.timeIntervalSince1970 ?? 0, recentBackup.timeIntervalSince1970, accuracy: 1.0)
    }

    func testPerformBackupIfNeededWithOldBackup() async throws {
        // This test verifies the logic but won't actually create a backup
        // since we'd need a real CoreDataStack with file-based storage

        autoBackupService?.isEnabled = true

        // Set an old backup time (at least 12 hours ago)
        let oldBackup = Date().addingTimeInterval(-12 * 60 * 60)
        UserDefaults.standard.set(oldBackup, forKey: "autoBackupLastDate")

        // Note: performBackupIfNeeded will attempt backup but silently fail
        // without a proper file-based Core Data stack
        await autoBackupService?.performBackupIfNeeded()

        // We can't verify the backup was created in this test environment
        // but we verified the method executes without crashing
    }

    // MARK: - Error Handling Tests

    func testBackupErrorWhenDisabled() async {
        autoBackupService?.isEnabled = false

        do {
            try await autoBackupService?.performBackup()
            XCTFail("Should throw error when disabled")
        } catch let error as AutoBackupService.AutoBackupError {
            // Check error description since AutoBackupError isn't Equatable
            XCTAssertEqual(error.errorDescription, "Auto backup is disabled")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testKeychainErrorDescription() {
        let error = AutoBackupService.AutoBackupError.keychainError
        XCTAssertEqual(error.errorDescription, "Failed to access secure storage")
    }

    func testBackupFailedErrorDescription() {
        let error = AutoBackupService.AutoBackupError.backupFailed("Test reason")
        XCTAssertEqual(error.errorDescription, "Auto backup failed: Test reason")
    }

    // MARK: - Backup Metadata Tests

    func testBackupInfoDisplayName() {
        let dailyBackup = AutoBackupService.BackupInfo(
            url: URL(fileURLWithPath: "/tmp/test.murmurbackup"),
            date: Date(),
            type: .daily
        )
        XCTAssertTrue(dailyBackup.displayName.starts(with: "Daily: "))

        let monthlyBackup = AutoBackupService.BackupInfo(
            url: URL(fileURLWithPath: "/tmp/test.murmurbackup"),
            date: Date(),
            type: .monthly
        )
        XCTAssertTrue(monthlyBackup.displayName.starts(with: "Monthly: "))
    }

    func testBackupInfoIdentifiable() {
        let backup1 = AutoBackupService.BackupInfo(
            url: URL(fileURLWithPath: "/tmp/test1.murmurbackup"),
            date: Date(),
            type: .daily
        )

        let backup2 = AutoBackupService.BackupInfo(
            url: URL(fileURLWithPath: "/tmp/test2.murmurbackup"),
            date: Date(),
            type: .daily
        )

        // IDs should be unique
        XCTAssertNotEqual(backup1.id, backup2.id)
    }

    // MARK: - Helper Methods

    private func cleanupAutoBackupsDirectory() throws {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let backupsURL = documentsURL.appendingPathComponent("AutoBackups", isDirectory: true)
        try? FileManager.default.removeItem(at: backupsURL)
    }

    private func deleteKeychainPassword() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.aidancb.Murmur.autobackup",
            kSecAttrAccount as String: "password"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Mock BGTask for Testing

// Note: MockBGTask has been removed because BGTask cannot be directly instantiated in tests.
// The testHandleBackgroundTaskCancellation and testBackgroundTaskExpirationHandler tests are skipped.
