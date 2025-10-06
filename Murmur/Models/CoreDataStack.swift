//
//  CoreDataStack.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CoreData
import os.log

/// Core Data stack configured for on-device encryption and background contexts.
final class CoreDataStack {
    enum CoreDataError: Error {
        case modelNotFound
        case storeLoadFailed(Error)

        var localizedDescription: String {
            switch self {
            case .modelNotFound:
                return "Unable to load Core Data model from bundle"
            case .storeLoadFailed(let error):
                return "Failed to load persistent store: \(error.localizedDescription)"
            }
        }
    }

    static let shared = CoreDataStack()
    private let logger = Logger(subsystem: "app.murmur", category: "CoreData")

    /// Error state if Core Data stack failed to initialise.
    private(set) var initializationError: CoreDataError?

    let container: NSPersistentContainer

    private init() {
        guard let modelURL = Bundle.main.url(forResource: "Murmur", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            let error = CoreDataError.modelNotFound
            self.initializationError = error
            logger.critical("Core Data model not found in bundle")
            // Return empty container as fallback - app will handle error state
            self.container = NSPersistentContainer(name: "Murmur")
            return
        }
        let container = NSPersistentContainer(name: "Murmur", managedObjectModel: model)
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(FileProtectionType.complete as NSObject, forKey: NSPersistentStoreFileProtectionKey)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        // Initialize container before using self in closures
        self.container = container

        container.loadPersistentStores { [weak self] _, error in
            if let error = error as NSError? {
                let coreDataError = CoreDataError.storeLoadFailed(error)
                self?.initializationError = coreDataError
                self?.logger.critical("Failed to load persistent store: \(error.localizedDescription)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    /// Internal initializer for testing purposes
    internal init(container: NSPersistentContainer) {
        self.container = container
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var context: NSManagedObjectContext { container.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func save() throws {
        let context = container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
}
