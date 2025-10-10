# ResourceManager usage examples

This document provides practical examples of using the `ResourceManager` system in the Murmur app.

## Overview

The `ResourceManager` provides centralised lifecycle management for resources like observers, timers, network connections, and HealthKit queries.

## Basic usage

### Creating a resource

```swift
class MyService: ResourceManageable {
    private var timer: Timer?
    private var observer: NSObjectProtocol?

    func start() async throws {
        // Initialise resources
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            print("Tick")
        }

        observer = NotificationCenter.default.addObserver(
            forName: .openAddEntry,
            object: nil,
            queue: .main
        ) { _ in
            print("Notification received")
        }
    }

    func cleanup() {
        // Release resources
        timer?.invalidate()
        timer = nil

        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }
}
```

### Using the resource manager

```swift
// Create manager
let manager = ResourceManager()

// Register resource
let service = MyService()
try await manager.register(service, autoStart: true)

// Later, cleanup all resources
await manager.cleanupAll()
```

## SwiftUI integration

### Using with views

```swift
struct ContentView: View {
    @StateObject private var resourceManager = ObservableResourceManager()

    var body: some View {
        MyContentView()
            .environmentObject(resourceManager)
            .task {
                // Start resources when view appears
                let service = MyService()
                try? await resourceManager.register(service, autoStart: true)
            }
            .onDisappear {
                // Cleanup when view disappears
                Task {
                    await resourceManager.cleanupAll()
                }
            }
    }
}
```

### Scene-based cleanup

```swift
@main
struct MurmurApp: App {
    @StateObject private var resourceManager = ObservableResourceManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(resourceManager)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background {
                        Task {
                            await resourceManager.cleanupAll()
                        }
                    }
                }
        }
    }
}
```

## Scoped cleanup

### Managing view-specific resources

```swift
struct SettingsView: View {
    @EnvironmentObject var resourceManager: ObservableResourceManager

    var body: some View {
        List {
            // Settings content
        }
        .task {
            // Register resources for this view
            let notificationService = NotificationService()
            try? await resourceManager.register(
                notificationService,
                scope: "settings",
                autoStart: true
            )
        }
        .onDisappear {
            // Cleanup only settings-scoped resources
            Task {
                await resourceManager.cleanup(scope: "settings")
            }
        }
    }
}
```

### Multiple scopes

```swift
// Register resources with different scopes
try await manager.register(healthKitService, scope: "health")
try await manager.register(locationService, scope: "location")
try await manager.register(analyticsService, scope: "analytics")

// Cleanup specific scope
await manager.cleanup(scope: "health")

// Other scopes remain active
let locationCount = await manager.resourceCount(in: "location") // Still 1
```

## Closure-based resources

### Simple cleanup with ResourceHandle

```swift
// Register a notification observer
let observer = NotificationCenter.default.addObserver(
    forName: .openAddEntry,
    object: nil,
    queue: .main
) { _ in
    print("Entry opened")
}

let handle = ResourceHandle(
    onCleanup: {
        NotificationCenter.default.removeObserver(observer)
    }
)

try await manager.register(handle)
```

### Direct registration with closure

```swift
// Even simpler - register directly
try await manager.registerHandle(
    scope: "notifications",
    onCleanup: {
        NotificationCenter.default.removeObserver(observer)
    }
)
```

### With start closure

```swift
var timer: Timer?

let handle = try await manager.registerHandle(
    scope: "timers",
    autoStart: true,
    onStart: {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            print("Tick")
        }
    },
    onCleanup: {
        timer?.invalidate()
        timer = nil
    }
)
```

## Real-world examples

### HealthKit query management

```swift
class HealthKitQueryManager: ResourceManageable {
    private var activeQueries: [HKQuery] = []
    private let healthStore = HKHealthStore()

    func start() async throws {
        // Start observing HealthKit changes
        let queryTypes = [
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        ]

        for queryType in queryTypes {
            let query = HKObserverQuery(sampleType: queryType, predicate: nil) { _, _, error in
                if let error = error {
                    print("Query error: \(error)")
                    return
                }
                // Handle update
            }
            healthStore.execute(query)
            activeQueries.append(query)
        }
    }

    func cleanup() {
        // Stop all active queries
        for query in activeQueries {
            healthStore.stop(query)
        }
        activeQueries.removeAll()
    }
}

// Usage in app
let healthKitManager = HealthKitQueryManager()
try await appResourceManager.register(healthKitManager, autoStart: true)
```

### Location updates

```swift
class LocationUpdateManager: NSObject, ResourceManageable, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager?

    func start() async throws {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
    }

    func cleanup() {
        locationManager?.stopUpdatingLocation()
        locationManager?.delegate = nil
        locationManager = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Handle location updates
    }
}

// Register for location updates
let locationManager = LocationUpdateManager()
try await manager.register(locationManager, scope: "location", autoStart: true)
```

### Multiple resource registration

```swift
// Register multiple resources at once
let services: [ResourceManageable] = [
    HealthKitQueryManager(),
    LocationUpdateManager(),
    NotificationManager(),
    AnalyticsService()
]

try await manager.registerAll(services, autoStart: true)

// Later cleanup all
await manager.cleanupAll()
```

## App delegate integration

### Registering app-level resources

```swift
final class MurmurAppDelegate: NSObject, UIApplicationDelegate {
    private let resourceManager = ResourceManager()
    let healthKitAssistant: HealthKitAssistant
    let calendarAssistant: CalendarAssistant

    override init() {
        self.healthKitAssistant = HealthKitAssistant()
        self.calendarAssistant = CalendarAssistant()
        super.init()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Register app-level resources
        Task {
            // Register HealthKit assistant with cleanup
            try await resourceManager.registerHandle(
                scope: "app",
                onCleanup: {
                    self.healthKitAssistant.cleanup()
                }
            )

            // Register other app resources
            if let backgroundService = setupBackgroundServices() {
                try await resourceManager.register(
                    backgroundService,
                    scope: "app",
                    autoStart: true
                )
            }
        }

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Cleanup all resources before app terminates
        Task {
            await resourceManager.cleanupAll()
        }
    }
}
```

## Best practices

### 1. Use weak references when capturing self

```swift
class MyService: ResourceManageable {
    func start() async throws {
        NotificationCenter.default.addObserver(
            forName: .someNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleNotification()
        }
    }
}
```

### 2. Make cleanup idempotent

```swift
func cleanup() {
    // Safe to call multiple times
    timer?.invalidate()
    timer = nil

    // Check before removing observer
    if let observer = observer {
        NotificationCenter.default.removeObserver(observer)
        self.observer = nil
    }
}
```

### 3. Use scopes for logical grouping

```swift
// Group related resources
try await manager.register(hrvMonitor, scope: "health-monitoring")
try await manager.register(heartRateMonitor, scope: "health-monitoring")
try await manager.register(sleepMonitor, scope: "health-monitoring")

// Cleanup all health monitoring at once
await manager.cleanup(scope: "health-monitoring")
```

### 4. Handle errors in start()

```swift
func start() async throws {
    guard HKHealthStore.isHealthDataAvailable() else {
        throw HealthKitError.notAvailable
    }

    // Proceed with setup
}

// Caller handles error
do {
    try await manager.register(service, autoStart: true)
} catch {
    print("Failed to start service: \(error)")
}
```

### 5. Prune dead references periodically

```swift
// In a long-running app, periodically prune
Task {
    while !Task.isCancelled {
        try await Task.sleep(for: .minutes(5))
        await resourceManager.pruneDeadReferences()
    }
}
```

## Testing

### Mock resource for testing

```swift
class MockResource: ResourceManageable {
    var didStart = false
    var didCleanup = false
    var startThrows = false

    func start() async throws {
        if startThrows {
            throw NSError(domain: "test", code: 1)
        }
        didStart = true
    }

    func cleanup() {
        didCleanup = true
    }
}

// In tests
func testResourceManagement() async throws {
    let manager = ResourceManager()
    let resource = MockResource()

    try await manager.register(resource, autoStart: true)
    XCTAssertTrue(resource.didStart)

    await manager.cleanupAll()
    XCTAssertTrue(resource.didCleanup)
}
```

## Performance considerations

- **Weak references**: Resources are stored as weak references to prevent retain cycles
- **Actor isolation**: `ResourceManager` is an actor, ensuring thread-safe access
- **LIFO cleanup**: Resources are cleaned up in reverse registration order
- **Automatic pruning**: Dead references are automatically removed during operations

## Summary

The `ResourceManager` system provides:

- Centralised resource lifecycle management
- Automatic cleanup on deallocation
- Scoped cleanup for logical grouping
- Thread-safe registration and cleanup
- SwiftUI integration via `ObservableResourceManager`
- Closure-based resources via `ResourceHandle`
- Weak references to prevent retain cycles
