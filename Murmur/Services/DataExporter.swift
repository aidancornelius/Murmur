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
        try? FileManager.default.removeItem(at: exportDirectory)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        let storeURL = try persistentStoreURL()
        let destinationURL = exportDirectory.appendingPathComponent(storeURL.lastPathComponent)
        try FileManager.default.copyItem(at: storeURL, to: destinationURL)

        let data = try Data(contentsOf: destinationURL)
        let key = SymmetricKey(data: SHA256.hash(data: Data(passphrase.utf8)))
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw ExportError.encryptionFailed
        }
        let encryptedURL = exportDirectory.appendingPathComponent("Murmur.enc")
        try combined.write(to: encryptedURL)
        return encryptedURL
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
