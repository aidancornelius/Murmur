//
//  ResourceManager.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import Foundation
import os.log

// MARK: - Resource management protocol

/// Protocol for resources that require lifecycle management (initialisation and cleanup).
///
/// Conforming types can be registered with ``ResourceManager`` to ensure
/// proper initialisation and cleanup of resources like network connections,
/// file handles, observers, or HealthKit queries.
///
/// ## Usage
/// ```swift
/// class MyService: ResourceManageable {
///     func start() async throws {
///         // Initialise resources
///     }
///
///     func cleanup() {
///         // Release resources
///     }
/// }
/// ```
public protocol ResourceManageable: AnyObject {
    /// Initialises or starts the resource.
    ///
    /// This method is called when the resource is registered or when explicitly
    /// starting managed resources. Implementations should be idempotent where possible.
    ///
    /// - Throws: Any error that occurs during initialisation
    func start() async throws

    /// Releases or cleans up the resource.
    ///
    /// This method is called when resources need to be released, typically during
    /// app termination, scene phase changes, or when explicitly cleaning up.
    /// Implementations must be safe to call multiple times.
    func cleanup()
}

// MARK: - Resource handle

/// A lightweight wrapper that conforms to ``ResourceManageable`` using closures.
///
/// Use ``ResourceHandle`` to quickly create manageable resources without
/// creating dedicated types. This is particularly useful for simple cleanup
/// tasks or when working with existing APIs.
///
/// ## Example
/// ```swift
/// let observer = NotificationCenter.default.addObserver(...)
/// let handle = ResourceHandle(
///     onStart: {
///         print("Resource started")
///     },
///     onCleanup: {
///         NotificationCenter.default.removeObserver(observer)
///     }
/// )
/// ```
public final class ResourceHandle: ResourceManageable {
    private let startClosure: (() async throws -> Void)?
    private let cleanupClosure: () -> Void
    private var hasStarted = false
    private var hasCleaned = false

    /// Creates a resource handle with optional start and cleanup closures.
    ///
    /// - Parameters:
    ///   - onStart: Optional closure called during ``start()``. Defaults to nil.
    ///   - onCleanup: Closure called during ``cleanup()``. Required.
    public init(
        onStart: (() async throws -> Void)? = nil,
        onCleanup: @escaping () -> Void
    ) {
        self.startClosure = onStart
        self.cleanupClosure = onCleanup
    }

    public func start() async throws {
        guard !hasStarted else { return }
        try await startClosure?()
        hasStarted = true
    }

    public func cleanup() {
        guard !hasCleaned else { return }
        cleanupClosure()
        hasCleaned = true
    }

    deinit {
        cleanup()
    }
}

// MARK: - Resource manager

/// Thread-safe manager for coordinating lifecycle of multiple resources.
///
/// ``ResourceManager`` provides centralised management of ``ResourceManageable``
/// instances, ensuring proper initialisation and cleanup. It's particularly useful
/// for managing app-level resources that need coordinated lifecycle management.
///
/// ## Key features
/// - Thread-safe resource registration and cleanup using Swift's actor model
/// - Weak references to prevent retain cycles
/// - Scoped cleanup for managing groups of related resources
/// - Comprehensive error handling and logging
///
/// ## Usage
/// ```swift
/// let manager = ResourceManager()
///
/// // Register resources
/// await manager.register(myService)
/// await manager.register(myObserver, scope: "notifications")
///
/// // Clean up specific scope
/// await manager.cleanup(scope: "notifications")
///
/// // Clean up all resources
/// await manager.cleanupAll()
/// ```
public actor ResourceManager {
    private struct WeakResource {
        weak var resource: ResourceManageable?
        let scope: String?
        let identifier: String
    }

    private var resources: [WeakResource] = []
    private let logger = Logger(subsystem: "app.murmur", category: "ResourceManager")

    /// Creates a new resource manager.
    public init() {}

    /// Registers a resource for lifecycle management.
    ///
    /// The resource is stored using a weak reference to prevent retain cycles.
    /// If the resource is deallocated elsewhere, it will be automatically removed
    /// from management.
    ///
    /// - Parameters:
    ///   - resource: The resource to manage
    ///   - scope: Optional scope identifier for grouped cleanup. Defaults to nil.
    ///   - autoStart: Whether to automatically call ``ResourceManageable/start()`` on registration. Defaults to false.
    ///
    /// - Throws: Any error from calling ``ResourceManageable/start()`` if `autoStart` is true
    public func register(
        _ resource: ResourceManageable,
        scope: String? = nil,
        autoStart: Bool = false
    ) async throws {
        // Generate unique identifier for this resource
        let identifier = "\(type(of: resource))-\(ObjectIdentifier(resource).hashValue)"

        // Remove any existing registration for this resource
        resources.removeAll { weakResource in
            weakResource.resource == nil || ObjectIdentifier(weakResource.resource!) == ObjectIdentifier(resource)
        }

        // Add new registration
        let weakResource = WeakResource(
            resource: resource,
            scope: scope,
            identifier: identifier
        )
        resources.append(weakResource)

        logger.debug("Registered resource: \(identifier)\(scope.map { " (scope: \($0))" } ?? "")")

        if autoStart {
            do {
                try await resource.start()
                logger.debug("Auto-started resource: \(identifier)")
            } catch {
                logger.error("Failed to auto-start resource \(identifier): \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// Cleans up resources within a specific scope.
    ///
    /// Only resources registered with the matching scope identifier will be cleaned up.
    /// Resources are removed from management after cleanup.
    ///
    /// - Parameter scope: The scope identifier to clean up
    public func cleanup(scope: String) async {
        logger.info("Cleaning up resources in scope: \(scope)")

        let scopedResources = resources.filter { $0.scope == scope }

        for weakResource in scopedResources {
            guard let resource = weakResource.resource else { continue }

            resource.cleanup()
            logger.debug("Cleaned up resource: \(weakResource.identifier)")
        }

        // Remove cleaned resources
        resources.removeAll { $0.scope == scope }

        logger.info("Completed cleanup of scope: \(scope) (\(scopedResources.count) resources)")
    }

    /// Cleans up all registered resources.
    ///
    /// Resources are cleaned up in reverse registration order (LIFO) to handle
    /// dependencies gracefully. All resources are removed from management after cleanup.
    public func cleanupAll() async {
        logger.info("Cleaning up all resources (\(self.resources.count) registered)")

        let aliveResources = self.resources.compactMap { weakResource -> (ResourceManageable, String)? in
            guard let resource = weakResource.resource else { return nil }
            return (resource, weakResource.identifier)
        }

        // Clean up in reverse order (LIFO)
        for (resource, identifier) in aliveResources.reversed() {
            resource.cleanup()
            logger.debug("Cleaned up resource: \(identifier)")
        }

        resources.removeAll()
        logger.info("Completed cleanup of all resources")
    }

    /// Removes resources that have been deallocated.
    ///
    /// This is called automatically during other operations, but can be called
    /// explicitly to free up memory.
    public func pruneDeadReferences() async {
        let countBefore = resources.count
        resources.removeAll { $0.resource == nil }
        let countAfter = resources.count

        if countBefore != countAfter {
            logger.debug("Pruned \(countBefore - countAfter) dead resource references")
        }
    }

    /// Returns the number of currently managed resources.
    ///
    /// This count includes only resources that haven't been deallocated.
    public var managedResourceCount: Int {
        resources.filter { $0.resource != nil }.count
    }

    /// Returns the number of resources in a specific scope.
    ///
    /// - Parameter scope: The scope identifier to count
    /// - Returns: The number of alive resources in the scope
    public func resourceCount(in scope: String) -> Int {
        resources.filter { $0.scope == scope && $0.resource != nil }.count
    }
}

// MARK: - Resource manager extensions for common patterns

extension ResourceManager {
    /// Registers multiple resources at once.
    ///
    /// - Parameters:
    ///   - resources: Array of resources to register
    ///   - scope: Optional scope for all resources
    ///   - autoStart: Whether to auto-start all resources. Defaults to false.
    ///
    /// - Throws: Any error from registering or starting resources
    public func registerAll(
        _ resources: [ResourceManageable],
        scope: String? = nil,
        autoStart: Bool = false
    ) async throws {
        for resource in resources {
            try await register(resource, scope: scope, autoStart: autoStart)
        }
    }

    /// Creates and registers a closure-based resource handle.
    ///
    /// This is a convenience method that combines ``ResourceHandle`` creation
    /// with registration in a single call.
    ///
    /// - Parameters:
    ///   - scope: Optional scope for the handle
    ///   - autoStart: Whether to auto-start the handle. Defaults to false.
    ///   - onStart: Optional start closure
    ///   - onCleanup: Required cleanup closure
    ///
    /// - Returns: The created resource handle
    /// - Throws: Any error from starting the resource if `autoStart` is true
    @discardableResult
    public func registerHandle(
        scope: String? = nil,
        autoStart: Bool = false,
        onStart: (() async throws -> Void)? = nil,
        onCleanup: @escaping () -> Void
    ) async throws -> ResourceHandle {
        let handle = ResourceHandle(onStart: onStart, onCleanup: onCleanup)
        try await register(handle, scope: scope, autoStart: autoStart)
        return handle
    }
}

// MARK: - Observable resource manager (SwiftUI integration)

/// SwiftUI-compatible resource manager that can be used as an environment object.
///
/// This wrapper provides ``@MainActor`` isolation and ``ObservableObject``
/// conformance, making it suitable for SwiftUI view hierarchies.
///
/// ## Usage in SwiftUI
/// ```swift
/// @StateObject private var resourceManager = ObservableResourceManager()
///
/// var body: some View {
///     ContentView()
///         .environmentObject(resourceManager)
///         .task {
///             try? await resourceManager.register(myService)
///         }
///         .onDisappear {
///             Task {
///                 await resourceManager.cleanupAll()
///             }
///         }
/// }
/// ```
@MainActor
public final class ObservableResourceManager: ObservableObject {
    private let manager = ResourceManager()

    public init() {}

    /// Registers a resource for lifecycle management.
    public func register(
        _ resource: ResourceManageable,
        scope: String? = nil,
        autoStart: Bool = false
    ) async throws {
        try await manager.register(resource, scope: scope, autoStart: autoStart)
    }

    /// Cleans up resources in a specific scope.
    public func cleanup(scope: String) async {
        await manager.cleanup(scope: scope)
    }

    /// Cleans up all registered resources.
    public func cleanupAll() async {
        await manager.cleanupAll()
    }

    /// Returns the number of currently managed resources.
    public var managedResourceCount: Int {
        get async {
            await manager.managedResourceCount
        }
    }
}
