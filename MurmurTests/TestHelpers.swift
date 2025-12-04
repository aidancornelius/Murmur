// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// TestHelpers.swift
// Created by Aidan Cornelius-Bell on 03/10/2025.
// Shared helper utilities for unit tests.
//
import CoreData
import XCTest
@testable import Murmur

// MARK: - Shared Test Helpers

func fetchFirstObject<T: NSManagedObject>(_ request: NSFetchRequest<T>, in context: NSManagedObjectContext) -> T? {
    request.fetchLimit = 1
    return try? context.fetch(request).first
}

// MARK: - In-Memory Core Data Stack

final class InMemoryCoreDataStack {
    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }

    init() {
        container = NSPersistentContainer(name: "Murmur")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
    }
}