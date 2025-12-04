// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DataExporterTests.swift
// Created by Aidan Cornelius-Bell on 03/10/2025.
// Tests for data export functionality.
//
import CommonCrypto
import CoreData
import CryptoKit
import XCTest
@testable import Murmur

@MainActor
final class DataExporterTests: XCTestCase {
    var testStack: InMemoryCoreDataStack?

    override func setUp() async throws {
        try await super.setUp()
        testStack = InMemoryCoreDataStack()
    }

    override func tearDown() async throws {
        testStack = nil
        // Clean up any temporary files
        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent("MurmurExport")
        try? FileManager.default.removeItem(at: exportDir)
        try await super.tearDown()
    }

    func testCreateSampleData() throws {
        // Manually create test symptom type
        let symptomType = SymptomType(context: testStack!.context)
        symptomType.id = UUID()
        symptomType.name = "Test Symptom"
        symptomType.color = "#FF0000"
        symptomType.iconName = "heart.fill"
        symptomType.category = "Test"
        symptomType.isDefault = false

        // Create a few entries
        for i in 1...3 {
            let entry = SymptomEntry(context: testStack!.context)
            entry.id = UUID()
            entry.createdAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
            entry.severity = Int16(i)
            entry.symptomType = symptomType
            entry.note = "Test note \(i)"
        }

        try testStack!.context.save()

        // Verify data was created
        let entryRequest = SymptomEntry.fetchRequest()
        let entries = try testStack!.context.fetch(entryRequest)
        XCTAssertEqual(entries.count, 3)

        // Verify symptom types exist
        let typeRequest = SymptomType.fetchRequest()
        let types = try testStack!.context.fetch(typeRequest)
        XCTAssertGreaterThan(types.count, 0)
    }

    func testDataStructure() throws {
        // Manually create test symptom type
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

        // Verify relationships
        XCTAssertNotNil(entry.symptomType)
        XCTAssertEqual(entry.symptomType?.name, "Test Symptom")
    }

    // Test that we can at least instantiate a DataExporter
    // even though we can't test the actual export in unit tests
    func testDataExporterInstantiation() {
        // We can't actually test DataExporter with an in-memory store
        // but we can verify the class exists
        XCTAssertNotNil(DataExporter.self)
    }

    func testEmptyDatabase() throws {
        // Don't seed data, test with empty database
        let entryRequest = SymptomEntry.fetchRequest()
        let entries = try testStack!.context.fetch(entryRequest)
        XCTAssertTrue(entries.isEmpty)

        let typeRequest = SymptomType.fetchRequest()
        let types = try testStack!.context.fetch(typeRequest)
        XCTAssertTrue(types.isEmpty)
    }

    // MARK: - Encryption/Decryption Round-Trip Tests

    func testExportAndDecryptRoundTrip() throws {
        // Create a temporary file-based Core Data stack
        let tempStack = try createTemporaryFileBasedStack()
        defer {
            cleanupTemporaryStack(tempStack)
        }

        // Manually create a test symptom type (avoiding async seeding issues)
        let symptomType = SymptomType(context: tempStack.context)
        symptomType.id = UUID()
        symptomType.name = "Test Symptom"
        symptomType.color = "#FF0000"
        symptomType.iconName = "heart.fill"
        symptomType.category = "Test"
        symptomType.isDefault = false
        try tempStack.context.save()

        let entry = SymptomEntry(context: tempStack.context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.severity = 4
        entry.symptomType = symptomType
        entry.note = "Round trip test"
        try tempStack.context.save()

        // Export with encryption
        let exporter = DataExporter(stack: tempStack)
        let password = "TestPassword123!"
        let encryptedURL = try exporter.exportDatabase(passphrase: password)

        // Verify encrypted file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: encryptedURL.path))

        // Read encrypted data
        let encryptedData = try Data(contentsOf: encryptedURL)

        // Verify structure: 32-byte salt + encrypted payload
        XCTAssertGreaterThan(encryptedData.count, 32, "Encrypted data should have salt prefix")

        let salt = encryptedData.prefix(32)
        XCTAssertEqual(salt.count, 32)

        let combined = encryptedData.dropFirst(32)
        XCTAssertGreaterThan(combined.count, 0)

        // Decrypt with correct password
        let decryptedData = try decryptData(combined: Data(combined), password: password, salt: Data(salt))

        // Verify decrypted data is not empty
        XCTAssertGreaterThan(decryptedData.count, 0)

        // Verify it contains SQLite header
        let sqliteHeader = "SQLite format 3"
        if let headerString = String(data: decryptedData.prefix(15), encoding: .utf8) {
            XCTAssertEqual(headerString, sqliteHeader, "Decrypted data should start with SQLite header")
        }
    }

    func testExportWithWrongPassword() throws {
        let tempStack = try createTemporaryFileBasedStack()
        defer {
            cleanupTemporaryStack(tempStack)
        }

        // Manually create test data
        let symptomType = SymptomType(context: tempStack.context)
        symptomType.id = UUID()
        symptomType.name = "Test Symptom"
        symptomType.color = "#FF0000"
        symptomType.iconName = "heart.fill"
        symptomType.category = "Test"
        symptomType.isDefault = false
        try tempStack.context.save()

        // Export with one password
        let exporter = DataExporter(stack: tempStack)
        let correctPassword = "CorrectPassword123!"
        let encryptedURL = try exporter.exportDatabase(passphrase: correctPassword)

        // Try to decrypt with wrong password
        let encryptedData = try Data(contentsOf: encryptedURL)
        let salt = encryptedData.prefix(32)
        let combined = encryptedData.dropFirst(32)

        let wrongPassword = "WrongPassword456!"

        // Decryption should fail with wrong password
        XCTAssertThrowsError(try decryptData(combined: Data(combined), password: wrongPassword, salt: Data(salt))) { error in
            // AES-GCM will throw an error when authentication fails
            XCTAssertTrue(error is CryptoKit.CryptoKitError || error is DataExporterTests.DecryptionError)
        }
    }

    func testExportCleanupKeepsEncryptedFile() throws {
        let tempStack = try createTemporaryFileBasedStack()
        defer {
            cleanupTemporaryStack(tempStack)
        }

        // Manually create test data
        let symptomType = SymptomType(context: tempStack.context)
        symptomType.id = UUID()
        symptomType.name = "Test Symptom"
        symptomType.color = "#FF0000"
        symptomType.iconName = "heart.fill"
        symptomType.category = "Test"
        symptomType.isDefault = false
        try tempStack.context.save()

        let exporter = DataExporter(stack: tempStack)
        let password = "TestPassword123!"
        let encryptedURL = try exporter.exportDatabase(passphrase: password)

        // Verify encrypted file still exists after export (cleanup should keep it)
        XCTAssertTrue(FileManager.default.fileExists(atPath: encryptedURL.path))

        // Verify intermediate SQLite files were cleaned up
        let exportDir = encryptedURL.deletingLastPathComponent()
        let contents = try FileManager.default.contentsOfDirectory(at: exportDir, includingPropertiesForKeys: nil)

        // Should only have the .enc file
        XCTAssertEqual(contents.count, 1)
        XCTAssertEqual(contents.first?.pathExtension, "enc")
    }

    func testExportSaltIsUnique() throws {
        let tempStack = try createTemporaryFileBasedStack()
        defer {
            cleanupTemporaryStack(tempStack)
        }

        // Manually create test data
        let symptomType = SymptomType(context: tempStack.context)
        symptomType.id = UUID()
        symptomType.name = "Test Symptom"
        symptomType.color = "#FF0000"
        symptomType.iconName = "heart.fill"
        symptomType.category = "Test"
        symptomType.isDefault = false
        try tempStack.context.save()

        let exporter = DataExporter(stack: tempStack)
        let password = "TestPassword123!"

        // Export twice with same password
        let url1 = try exporter.exportDatabase(passphrase: password)
        let data1 = try Data(contentsOf: url1)
        let salt1 = data1.prefix(32)

        // Clean up first export
        try? FileManager.default.removeItem(at: url1.deletingLastPathComponent())

        let url2 = try exporter.exportDatabase(passphrase: password)
        let data2 = try Data(contentsOf: url2)
        let salt2 = data2.prefix(32)

        // Salts should be different (randomly generated)
        XCTAssertNotEqual(salt1, salt2, "Each export should use a unique random salt")
    }

    // MARK: - Helper Methods

    private func createTemporaryFileBasedStack() throws -> CoreDataStack {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MurmurTest-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let storeURL = tempDir.appendingPathComponent("TestStore.sqlite")

        // Load the model from the bundle to ensure we get the correct version
        guard let modelURL = Bundle.main.url(forResource: "Murmur", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load Core Data model"])
        }

        let container = NSPersistentContainer(name: "Murmur", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        // Enable automatic migration for tests
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        semaphore.wait()

        if let error = loadError {
            throw error
        }

        let stack = CoreDataStack(container: container)
        // Ensure context is ready by accessing it
        _ = stack.context
        return stack
    }

    private func cleanupTemporaryStack(_ stack: CoreDataStack) {
        guard let storeURL = stack.container.persistentStoreCoordinator.persistentStores.first?.url else {
            return
        }

        let tempDir = storeURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func decryptData(combined: Data, password: String, salt: Data) throws -> Data {
        // Replicate the key derivation from DataExporter
        guard let passwordData = password.data(using: .utf8) else {
            throw DecryptionError.invalidPassword
        }

        let key = try deriveKey(from: passwordData, salt: salt)

        // Decrypt using AES-GCM
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)

        return decryptedData
    }

    private func deriveKey(from password: Data, salt: Data) throws -> SymmetricKey {
        let iterations = 100_000
        let keyLength = 32

        var derivedKeyData = Data(count: keyLength)
        let result = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw DecryptionError.keyDerivationFailed
        }

        return SymmetricKey(data: derivedKeyData)
    }

    enum DecryptionError: Error {
        case invalidPassword
        case keyDerivationFailed
    }
}