// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// CoreDataStack.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Core Data stack with on-device encryption and background contexts.
//
import CoreData
import os.log

/// Core Data stack configured for on-device encryption and background contexts.
///
/// This class provides thread-safe access to Core Data via NSPersistentContainer.
/// The viewContext is main-thread only and should be accessed via the @MainActor context property.
/// Background contexts should be created via newBackgroundContext() which provides private queue contexts.
final class CoreDataStack: Sendable {
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

    /// Error state if Core Data stack failed to initialise (immutable after init).
    let initializationError: CoreDataError?

    let container: NSPersistentContainer

    private init() {
        let logger = Logger(subsystem: "app.murmur", category: "CoreData")

        guard let modelURL = Bundle.main.url(forResource: "Murmur", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            logger.critical("Core Data model not found in bundle")
            self.initializationError = .modelNotFound
            self.container = NSPersistentContainer(name: "Murmur")
            return
        }

        let container = NSPersistentContainer(name: "Murmur", managedObjectModel: model)
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(FileProtectionType.complete as NSObject, forKey: NSPersistentStoreFileProtectionKey)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        // Track initialization error using a synchronization mechanism
        var storeError: CoreDataError?
        let semaphore = DispatchSemaphore(value: 0)

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                storeError = .storeLoadFailed(error)
                logger.critical("Failed to load persistent store: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        // Wait for store loading to complete during init
        semaphore.wait()

        self.container = container
        self.initializationError = storeError

        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    /// Internal initializer for testing purposes
    internal init(container: NSPersistentContainer) {
        self.container = container
        self.initializationError = nil
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    /// Returns the main-thread view context.
    /// This property must only be accessed from the main actor.
    @MainActor
    var context: NSManagedObjectContext { container.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }

    /// Saves the main view context (must be called from main actor).
    @MainActor
    func save() throws {
        let context = container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
}

// MARK: - ResourceManageable conformance

extension CoreDataStack: ResourceManageable {
    func start() async throws {
        // Container is initialised in init, nothing more to do
        if let error = initializationError {
            throw error
        }
    }

    nonisolated func cleanup() {
        // Save any pending changes before app termination
        // Must be called on main thread to access viewContext safely
        Task { @MainActor in
            let context = container.viewContext
            if context.hasChanges {
                do {
                    try context.save()
                    logger.info("Saved pending Core Data changes on cleanup")
                } catch {
                    logger.error("Failed to save Core Data on cleanup: \(error.localizedDescription)")
                }
            }
        }

        // Note: Don't destroy container - it's a singleton that may be needed during shutdown
    }
}
