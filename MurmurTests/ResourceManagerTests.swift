//
//  ResourceManagerTests.swift
//  MurmurTests
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import XCTest
@testable import Murmur

final class ResourceManagerTests: XCTestCase {
    var manager: ResourceManager?

    override func setUp() async throws {
        try await super.setUp()
        manager = ResourceManager()
    }

    override func tearDown() async throws {
        await manager!.cleanupAll()
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Basic registration tests

    func testRegisterResource() async throws {
        // Arrange
        let resource = MockResource()

        // Act
        try await manager!.register(resource)

        // Assert
        let count = await manager!.managedResourceCount
        XCTAssertEqual(count, 1)
    }

    func testRegisterMultipleResources() async throws {
        // Arrange
        let resource1 = MockResource()
        let resource2 = MockResource()
        let resource3 = MockResource()

        // Act
        try await manager!.register(resource1)
        try await manager!.register(resource2)
        try await manager!.register(resource3)

        // Assert
        let count = await manager!.managedResourceCount
        XCTAssertEqual(count, 3)
    }

    func testRegisterResourceWithAutoStart() async throws {
        // Arrange
        let resource = MockResource()
        XCTAssertFalse(resource.didStart)

        // Act
        try await manager!.register(resource, autoStart: true)

        // Assert
        XCTAssertTrue(resource.didStart)
    }

    func testRegisterResourceWithoutAutoStart() async throws {
        // Arrange
        let resource = MockResource()

        // Act
        try await manager!.register(resource, autoStart: false)

        // Assert
        XCTAssertFalse(resource.didStart)
    }

    // MARK: - Cleanup tests

    func testCleanupAllCleansUpAllResources() async throws {
        // Arrange
        let resource1 = MockResource()
        let resource2 = MockResource()
        let resource3 = MockResource()

        try await manager!.register(resource1)
        try await manager!.register(resource2)
        try await manager!.register(resource3)

        // Act
        await manager!.cleanupAll()

        // Assert
        XCTAssertTrue(resource1.didCleanup)
        XCTAssertTrue(resource2.didCleanup)
        XCTAssertTrue(resource3.didCleanup)

        let count = await manager!.managedResourceCount
        XCTAssertEqual(count, 0)
    }

    func testCleanupAllReversesRegistrationOrder() async throws {
        // Arrange
        var cleanupOrder: [String] = []
        let resource1 = MockResource(cleanupCallback: { cleanupOrder.append("resource1") })
        let resource2 = MockResource(cleanupCallback: { cleanupOrder.append("resource2") })
        let resource3 = MockResource(cleanupCallback: { cleanupOrder.append("resource3") })

        try await manager!.register(resource1)
        try await manager!.register(resource2)
        try await manager!.register(resource3)

        // Act
        await manager!.cleanupAll()

        // Assert: LIFO order (last in, first out)
        XCTAssertEqual(cleanupOrder, ["resource3", "resource2", "resource1"])
    }

    // MARK: - Scoped cleanup tests

    func testRegisterResourceWithScope() async throws {
        // Arrange
        let resource = MockResource()

        // Act
        try await manager!.register(resource, scope: "test-scope")

        // Assert
        let count = await manager!.resourceCount(in: "test-scope")
        XCTAssertEqual(count, 1)
    }

    func testCleanupScope() async throws {
        // Arrange
        let scopedResource1 = MockResource()
        let scopedResource2 = MockResource()
        let unscopedResource = MockResource()

        try await manager!.register(scopedResource1, scope: "test-scope")
        try await manager!.register(scopedResource2, scope: "test-scope")
        try await manager!.register(unscopedResource)

        // Act
        await manager!.cleanup(scope: "test-scope")

        // Assert
        XCTAssertTrue(scopedResource1.didCleanup)
        XCTAssertTrue(scopedResource2.didCleanup)
        XCTAssertFalse(unscopedResource.didCleanup)

        let scopedCount = await manager!.resourceCount(in: "test-scope")
        XCTAssertEqual(scopedCount, 0)

        let totalCount = await manager!.managedResourceCount
        XCTAssertEqual(totalCount, 1) // Only unscopedResource remains
    }

    func testCleanupMultipleScopes() async throws {
        // Arrange
        let scope1Resource = MockResource()
        let scope2Resource = MockResource()
        let scope3Resource = MockResource()

        try await manager!.register(scope1Resource, scope: "scope1")
        try await manager!.register(scope2Resource, scope: "scope2")
        try await manager!.register(scope3Resource, scope: "scope3")

        // Act
        await manager!.cleanup(scope: "scope1")
        await manager!.cleanup(scope: "scope3")

        // Assert
        XCTAssertTrue(scope1Resource.didCleanup)
        XCTAssertFalse(scope2Resource.didCleanup)
        XCTAssertTrue(scope3Resource.didCleanup)

        let remainingCount = await manager!.managedResourceCount
        XCTAssertEqual(remainingCount, 1)
    }

    // MARK: - Weak reference tests

    func testWeakReferencesPruneWhenResourceDeallocated() async throws {
        // Arrange
        var resource: MockResource? = MockResource()
        try await manager!.register(resource!)

        var count = await manager!.managedResourceCount
        XCTAssertEqual(count, 1)

        // Act: Deallocate resource
        resource = nil

        await manager!.pruneDeadReferences()

        // Assert
        count = await manager!.managedResourceCount
        XCTAssertEqual(count, 0)
    }

    func testDeadReferencesDoNotPreventCleanup() async throws {
        // Arrange
        var resource1: MockResource? = MockResource()
        let resource2 = MockResource()

        try await manager!.register(resource1!)
        try await manager!.register(resource2)

        // Deallocate one resource
        resource1 = nil

        // Act
        await manager!.cleanupAll()

        // Assert: Should not crash and should cleanup remaining resource
        XCTAssertTrue(resource2.didCleanup)

        let count = await manager!.managedResourceCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - ResourceHandle tests

    func testResourceHandle() async throws {
        // Arrange
        let didStart = Box(false)
        let didCleanup = Box(false)

        let handle = ResourceHandle(
            onStart: { didStart.value = true },
            onCleanup: { didCleanup.value = true }
        )

        // Act
        try await handle.start()
        handle.cleanup()

        // Assert
        XCTAssertTrue(didStart.value)
        XCTAssertTrue(didCleanup.value)
    }

    func testResourceHandleWithoutStart() async throws {
        // Arrange
        let didCleanup = Box(false)

        let handle = ResourceHandle(
            onCleanup: { didCleanup.value = true }
        )

        // Act
        handle.cleanup()

        // Assert
        XCTAssertTrue(didCleanup.value)
    }

    func testResourceHandleIdempotentStart() async throws {
        // Arrange
        let startCount = Box(0)

        let handle = ResourceHandle(
            onStart: { startCount.value += 1 },
            onCleanup: {}
        )

        // Act
        try await handle.start()
        try await handle.start()
        try await handle.start()

        // Assert
        XCTAssertEqual(startCount.value, 1)
    }

    func testResourceHandleIdempotentCleanup() async throws {
        // Arrange
        let cleanupCount = Box(0)

        let handle = ResourceHandle(
            onCleanup: { cleanupCount.value += 1 }
        )

        // Act
        handle.cleanup()
        handle.cleanup()
        handle.cleanup()

        // Assert
        XCTAssertEqual(cleanupCount.value, 1)
    }

    func testResourceHandleDeinitCallsCleanup() async throws {
        // Arrange
        let didCleanup = Box(false)

        // Act
        do {
            let handle = ResourceHandle(
                onCleanup: { didCleanup.value = true }
            )
            _ = handle // Use handle to avoid warning
        } // handle deallocated here

        // Assert
        XCTAssertTrue(didCleanup.value)
    }

    // MARK: - Extension method tests

    func testRegisterAll() async throws {
        // Arrange
        let resources = [MockResource(), MockResource(), MockResource()]

        // Act
        try await manager!.registerAll(resources)

        // Assert
        let count = await manager!.managedResourceCount
        XCTAssertEqual(count, 3)
    }

    func testRegisterAllWithScope() async throws {
        // Arrange
        let resources = [MockResource(), MockResource()]

        // Act
        try await manager!.registerAll(resources, scope: "batch-scope")

        // Assert
        let count = await manager!.resourceCount(in: "batch-scope")
        XCTAssertEqual(count, 2)
    }

    func testRegisterAllWithAutoStart() async throws {
        // Arrange
        let resources = [MockResource(), MockResource()]

        // Act
        try await manager!.registerAll(resources, autoStart: true)

        // Assert
        XCTAssertTrue(resources[0].didStart)
        XCTAssertTrue(resources[1].didStart)
    }

    func testRegisterHandle() async throws {
        // Arrange
        let didCleanup = Box(false)

        // Act
        let handle = try await manager!.registerHandle(
            onCleanup: { didCleanup.value = true }
        )

        await manager!.cleanupAll()

        // Assert
        XCTAssertNotNil(handle)
        XCTAssertTrue(didCleanup.value)
    }

    func testRegisterHandleWithScope() async throws {
        // Arrange
        let didCleanup = Box(false)

        // Act
        _ = try await manager!.registerHandle(
            scope: "handle-scope",
            onCleanup: { didCleanup.value = true }
        )

        await manager!.cleanup(scope: "handle-scope")

        // Assert
        XCTAssertTrue(didCleanup.value)
    }

    // MARK: - Error handling tests

    func testStartErrorPropagates() async throws {
        // Arrange
        let resource = ThrowingResource(shouldThrow: true)

        // Act & Assert
        do {
            try await manager!.register(resource, autoStart: true)
            XCTFail("Should have thrown error")
        } catch {
            // Expected
        }
    }

    func testStartErrorDoesNotPreventRegistration() async throws {
        // Arrange
        let throwingResource = ThrowingResource(shouldThrow: true)

        // Act
        do {
            try await manager!.register(throwingResource, autoStart: true)
            XCTFail("Should have thrown error")
        } catch {
            // Expected
        }

        // Assert: Resource should not be registered
        let count = await manager!.managedResourceCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - Re-registration tests

    func testReregisteringSameResourceReplacesOld() async throws {
        // Arrange
        let resource = MockResource()
        try await manager!.register(resource)

        var count = await manager!.managedResourceCount
        XCTAssertEqual(count, 1)

        // Act: Re-register same resource
        try await manager!.register(resource)

        // Assert: Should still be 1 (not 2)
        count = await manager!.managedResourceCount
        XCTAssertEqual(count, 1)
    }
}

// MARK: - Mock resources

private final class MockResource: ResourceManageable, @unchecked Sendable {
    var didStart = false
    var didCleanup = false
    var cleanupCallback: (() -> Void)?

    init(cleanupCallback: (() -> Void)? = nil) {
        self.cleanupCallback = cleanupCallback
    }

    func start() async throws {
        didStart = true
    }

    func cleanup() {
        didCleanup = true
        cleanupCallback?()
    }
}

private final class ThrowingResource: ResourceManageable, @unchecked Sendable {
    var shouldThrow: Bool

    init(shouldThrow: Bool) {
        self.shouldThrow = shouldThrow
    }

    func start() async throws {
        if shouldThrow {
            throw NSError(domain: "test.error", code: 1)
        }
    }

    func cleanup() {}
}

// Helper class for capturing mutable state in closures
private final class Box<T>: @unchecked Sendable {
    var value: T

    init(_ value: T) {
        self.value = value
    }
}
