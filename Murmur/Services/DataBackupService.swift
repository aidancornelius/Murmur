import CoreData
import CryptoKit
import Foundation

/// Service for backing up and restoring all app data with encryption
@MainActor
final class DataBackupService {
    private let stack: CoreDataStack

    enum BackupError: LocalizedError {
        case exportFailed(String)
        case importFailed(String)
        case encryptionFailed
        case decryptionFailed
        case invalidData
        case invalidPassword

        var errorDescription: String? {
            switch self {
            case .exportFailed(let reason):
                return "Backup failed: \(reason)"
            case .importFailed(let reason):
                return "Restore failed: \(reason)"
            case .encryptionFailed:
                return "Failed to encrypt backup"
            case .decryptionFailed:
                return "Failed to decrypt backup"
            case .invalidData:
                return "Backup file is corrupted or invalid"
            case .invalidPassword:
                return "Incorrect password"
            }
        }
    }

    struct BackupData: Codable {
        let version: Int
        let createdAt: Date
        let entries: [EntryBackup]
        let symptomTypes: [SymptomTypeBackup]

        init(version: Int = 1, createdAt: Date, entries: [EntryBackup], symptomTypes: [SymptomTypeBackup]) {
            self.version = version
            self.createdAt = createdAt
            self.entries = entries
            self.symptomTypes = symptomTypes
        }

        struct EntryBackup: Codable {
            let id: UUID
            let createdAt: Date
            let backdatedAt: Date?
            let severity: Int16
            let note: String?
            let symptomTypeID: UUID
            // Health data
            let hkHRV: Double?
            let hkRestingHR: Double?
            let hkSleepHours: Double?
            let hkWorkoutMinutes: Double?
            let hkCycleDay: Int?
            let hkFlowLevel: String?
            // Location data (simplified)
            let locationLocality: String?
            let locationArea: String?
        }

        struct SymptomTypeBackup: Codable {
            let id: UUID
            let name: String
            let color: String
            let iconName: String
            let category: String?
            let isDefault: Bool
            let isStarred: Bool
            let starOrder: Int16
        }
    }

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: - Backup

    func createBackup(password: String) async throws -> URL {
        let backupData = try await fetchBackupData()
        let jsonData = try JSONEncoder().encode(backupData)

        // Encrypt the data
        let encryptedData = try encrypt(data: jsonData, password: password)

        // Save to file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "Murmur_Backup_\(timestamp).murmurbackup"

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
        try encryptedData.write(to: tempURL)

        return tempURL
    }

    private func fetchBackupData() async throws -> BackupData {
        let context = stack.container.viewContext

        // Fetch all entries
        let entryRequest = SymptomEntry.fetchRequest()
        entryRequest.relationshipKeyPathsForPrefetching = ["symptomType"]
        let entries = try context.fetch(entryRequest)

        // Fetch all symptom types
        let typeRequest = SymptomType.fetchRequest()
        let types = try context.fetch(typeRequest)

        let entryBackups = entries.compactMap { entry -> BackupData.EntryBackup? in
            guard let id = entry.id,
                  let createdAt = entry.createdAt,
                  let symptomTypeID = entry.symptomType?.id else {
                return nil
            }

            return BackupData.EntryBackup(
                id: id,
                createdAt: createdAt,
                backdatedAt: entry.backdatedAt,
                severity: entry.severity,
                note: entry.note,
                symptomTypeID: symptomTypeID,
                hkHRV: entry.hkHRV?.doubleValue,
                hkRestingHR: entry.hkRestingHR?.doubleValue,
                hkSleepHours: entry.hkSleepHours?.doubleValue,
                hkWorkoutMinutes: entry.hkWorkoutMinutes?.doubleValue,
                hkCycleDay: entry.hkCycleDay?.intValue,
                hkFlowLevel: entry.hkFlowLevel,
                locationLocality: entry.locationPlacemark?.locality,
                locationArea: entry.locationPlacemark?.administrativeArea
            )
        }

        let typeBackups = types.compactMap { type -> BackupData.SymptomTypeBackup? in
            guard let id = type.id,
                  let name = type.name else {
                return nil
            }

            return BackupData.SymptomTypeBackup(
                id: id,
                name: name,
                color: type.color ?? "#808080",
                iconName: type.iconName ?? "questionmark.circle",
                category: type.category,
                isDefault: type.isDefault,
                isStarred: type.isStarred,
                starOrder: type.starOrder
            )
        }

        return BackupData(
            createdAt: Date(),
            entries: entryBackups,
            symptomTypes: typeBackups
        )
    }

    // MARK: - Restore

    func restoreBackup(from url: URL, password: String) async throws {
        let encryptedData = try Data(contentsOf: url)

        // Decrypt the data
        let jsonData = try decrypt(data: encryptedData, password: password)

        // Decode backup
        let backupData = try JSONDecoder().decode(BackupData.self, from: jsonData)

        // Restore to Core Data
        try await restoreToDatabase(backupData: backupData)
    }

    private func restoreToDatabase(backupData: BackupData) async throws {
        let context = stack.newBackgroundContext()

        try await context.perform {
            // Delete all existing data
            let entryDeleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SymptomEntry")
            let entryDelete = NSBatchDeleteRequest(fetchRequest: entryDeleteRequest)
            try context.execute(entryDelete)

            let typeDeleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SymptomType")
            let typeDelete = NSBatchDeleteRequest(fetchRequest: typeDeleteRequest)
            try context.execute(typeDelete)

            // Create symptom types
            var typeMap: [UUID: SymptomType] = [:]
            for typeBackup in backupData.symptomTypes {
                let type = SymptomType(context: context)
                type.id = typeBackup.id
                type.name = typeBackup.name
                type.color = typeBackup.color
                type.iconName = typeBackup.iconName
                type.category = typeBackup.category
                type.isDefault = typeBackup.isDefault
                type.isStarred = typeBackup.isStarred
                type.starOrder = typeBackup.starOrder
                typeMap[typeBackup.id] = type
            }

            // Create entries
            for entryBackup in backupData.entries {
                guard let symptomType = typeMap[entryBackup.symptomTypeID] else {
                    continue
                }

                let entry = SymptomEntry(context: context)
                entry.id = entryBackup.id
                entry.createdAt = entryBackup.createdAt
                entry.backdatedAt = entryBackup.backdatedAt
                entry.severity = entryBackup.severity
                entry.note = entryBackup.note
                entry.symptomType = symptomType
                entry.hkHRV = entryBackup.hkHRV.map { NSNumber(value: $0) }
                entry.hkRestingHR = entryBackup.hkRestingHR.map { NSNumber(value: $0) }
                entry.hkSleepHours = entryBackup.hkSleepHours.map { NSNumber(value: $0) }
                entry.hkWorkoutMinutes = entryBackup.hkWorkoutMinutes.map { NSNumber(value: $0) }
                entry.hkCycleDay = entryBackup.hkCycleDay.map { NSNumber(value: $0) }
                entry.hkFlowLevel = entryBackup.hkFlowLevel
                // Note: Location placemark restoration would need CLPlacemark reconstruction
            }

            try context.save()
        }
    }

    // MARK: - Encryption

    private func encrypt(data: Data, password: String) throws -> Data {
        // Derive key from password using PBKDF2
        guard let passwordData = password.data(using: .utf8) else {
            throw BackupError.encryptionFailed
        }

        let salt = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let key = try deriveKey(from: passwordData, salt: salt)

        // Encrypt using AES-GCM
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        guard let combined = sealedBox.combined else {
            throw BackupError.encryptionFailed
        }

        // Combine salt + encrypted data
        var result = Data()
        result.append(salt)
        result.append(combined)

        return result
    }

    private func decrypt(data: Data, password: String) throws -> Data {
        guard data.count > 32 else {
            throw BackupError.invalidData
        }

        // Extract salt and encrypted data
        let salt = data.prefix(32)
        let encryptedData = data.suffix(from: 32)

        // Derive key
        guard let passwordData = password.data(using: .utf8) else {
            throw BackupError.decryptionFailed
        }

        let key = try deriveKey(from: passwordData, salt: salt)

        // Decrypt
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            throw BackupError.invalidPassword
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
            throw BackupError.encryptionFailed
        }

        return SymmetricKey(data: derivedKeyData)
    }
}

// Required for PBKDF2
import CommonCrypto
