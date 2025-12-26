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
///
/// Important: Call `start()` before using the stack. The persistent stores are not loaded until `start()` is called.
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

    /// Error from model loading during init (nil if model loaded successfully).
    /// Store loading errors are thrown from start() instead.
    private let modelLoadError: CoreDataError?

    let container: NSPersistentContainer

    private init() {
        let logger = Logger(subsystem: "app.murmur", category: "CoreData")

        guard let modelURL = Bundle.main.url(forResource: "Murmur", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            logger.critical("Core Data model not found in bundle")
            self.modelLoadError = .modelNotFound
            self.container = NSPersistentContainer(name: "Murmur")
            return
        }

        let container = NSPersistentContainer(name: "Murmur", managedObjectModel: model)
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(FileProtectionType.complete as NSObject, forKey: NSPersistentStoreFileProtectionKey)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        self.container = container
        self.modelLoadError = nil
        // Note: Persistent stores are loaded in start() to avoid blocking the main thread
    }

    /// Internal initializer for testing purposes.
    /// The provided container is assumed to already have its stores loaded.
    internal init(container: NSPersistentContainer) {
        self.container = container
        self.modelLoadError = nil
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
        logger.info("CoreDataStack.start() called")

        // Check for model loading errors from init
        if let error = modelLoadError {
            logger.error("Model load error from init: \(error.localizedDescription)")
            throw error
        }

        logger.info("Loading persistent stores...")

        // Load persistent stores asynchronously using continuation
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { [logger] _, error in
                if let error = error as NSError? {
                    logger.critical("Failed to load persistent store: \(error.localizedDescription)")
                    continuation.resume(throwing: CoreDataError.storeLoadFailed(error))
                } else {
                    logger.info("Persistent stores loaded successfully")
                    continuation.resume()
                }
            }
        }

        logger.info("CoreDataStack.start() completed")

        // Configure view context after stores are loaded
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        container.viewContext.automaticallyMergesChangesFromParent = true
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
