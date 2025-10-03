//
//  DataExporter.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CommonCrypto
import CoreData
import CryptoKit
import Foundation

/// Handles encrypted local-only export of the on-device Core Data store.
struct DataExporter {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func exportDatabase(passphrase: String) throws -> URL {
        let exportDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("MurmurExport", isDirectory: true)

        // Clean up any existing export directory
        defer {
            // Clean up temporary files after encryption
            cleanupTemporaryFiles(in: exportDirectory, keepingEncryptedFile: true)
        }

        try? FileManager.default.removeItem(at: exportDirectory)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        let storeURL = try persistentStoreURL()

        // Copy all SQLite files (main file, WAL, and SHM)
        try copySQLiteFiles(from: storeURL, to: exportDirectory)

        // Create a single data blob from all SQLite files
        let combinedData = try combineSQLiteFiles(in: exportDirectory, mainFile: storeURL.lastPathComponent)

        // Use PBKDF2 for key derivation (similar to DataBackupService)
        guard let passwordData = passphrase.data(using: .utf8) else {
            throw ExportError.encryptionFailed
        }

        let salt = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let key = try deriveKey(from: passwordData, salt: salt)

        // Encrypt using AES-GCM
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(combinedData, using: key, nonce: nonce)
        guard let combined = sealed.combined else {
            throw ExportError.encryptionFailed
        }

        // Combine salt + encrypted data
        var encryptedData = Data()
        encryptedData.append(salt)
        encryptedData.append(combined)

        let encryptedURL = exportDirectory.appendingPathComponent("Murmur.enc")
        try encryptedData.write(to: encryptedURL)

        return encryptedURL
    }

    private func copySQLiteFiles(from storeURL: URL, to directory: URL) throws {
        let fileManager = FileManager.default
        let storeDirectory = storeURL.deletingLastPathComponent()
        let baseName = storeURL.deletingPathExtension().lastPathComponent

        // Copy main SQLite file
        let destinationURL = directory.appendingPathComponent(storeURL.lastPathComponent)
        try fileManager.copyItem(at: storeURL, to: destinationURL)

        // Copy WAL file if exists
        let walURL = storeDirectory.appendingPathComponent("\(baseName).sqlite-wal")
        if fileManager.fileExists(atPath: walURL.path) {
            let walDestination = directory.appendingPathComponent(walURL.lastPathComponent)
            try fileManager.copyItem(at: walURL, to: walDestination)
        }

        // Copy SHM file if exists
        let shmURL = storeDirectory.appendingPathComponent("\(baseName).sqlite-shm")
        if fileManager.fileExists(atPath: shmURL.path) {
            let shmDestination = directory.appendingPathComponent(shmURL.lastPathComponent)
            try fileManager.copyItem(at: shmURL, to: shmDestination)
        }
    }

    private func combineSQLiteFiles(in directory: URL, mainFile: String) throws -> Data {
        var combinedData = Data()
        let fileManager = FileManager.default

        // Add main SQLite file
        let mainURL = directory.appendingPathComponent(mainFile)
        combinedData.append(try Data(contentsOf: mainURL))

        // Add file separator marker
        combinedData.append("--FILE--".data(using: .utf8)!)

        // Add WAL file if exists
        let walFile = mainFile.replacingOccurrences(of: ".sqlite", with: ".sqlite-wal")
        let walURL = directory.appendingPathComponent(walFile)
        if fileManager.fileExists(atPath: walURL.path) {
            combinedData.append(try Data(contentsOf: walURL))
        }
        combinedData.append("--FILE--".data(using: .utf8)!)

        // Add SHM file if exists
        let shmFile = mainFile.replacingOccurrences(of: ".sqlite", with: ".sqlite-shm")
        let shmURL = directory.appendingPathComponent(shmFile)
        if fileManager.fileExists(atPath: shmURL.path) {
            combinedData.append(try Data(contentsOf: shmURL))
        }

        return combinedData
    }

    private func cleanupTemporaryFiles(in directory: URL, keepingEncryptedFile: Bool) {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: directory.path) else { return }

        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files {
                // Keep the encrypted file if requested, delete everything else
                if keepingEncryptedFile && file.pathExtension == "enc" {
                    continue
                }
                try? fileManager.removeItem(at: file)
            }
        } catch {
            // Silent cleanup failure is acceptable
        }
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
            throw ExportError.encryptionFailed
        }

        return SymmetricKey(data: derivedKeyData)
    }

    private func persistentStoreURL() throws -> URL {
        guard let store = stack.container.persistentStoreCoordinator.persistentStores.first,
              let url = store.url else {
            throw ExportError.missingStore
        }
        return url
    }

    enum ExportError: Error {
        case encryptionFailed
        case missingStore
    }
}
