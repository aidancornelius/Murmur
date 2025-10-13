# Murmur test suite

This document explains how tests are organised in Murmur.

## Overview

Tests are split into focused files by feature area. All HealthKit tests inherit from a base class and use shared factories for creating test data.

## Test files

### Core infrastructure

- HealthKitAssistantTestCase.swift - Base class with common setup and helper methods
- HealthKitSampleFactory.swift - Creates test samples for HRV, heart rate, sleep, workouts, and menstrual cycles

### Test suites

- HealthKitAssistantRecentMetricsTests.swift - Recent metrics and cache behaviour
- HealthKitAssistantHistoricalTests.swift - Historical data queries
- HealthKitAssistantManualTrackingTests.swift - Manual cycle tracking integration
- HealthKitAssistantBaselineTests.swift - Baseline calculations
- HealthKitAssistantErrorHandlingTests.swift - Error handling and permissions
- HealthKitAssistantQueryLifecycleTests.swift - Query lifecycle and caching

### Supporting infrastructure

- HealthKitTestHelpers.swift - Mock implementations and date helpers

## Writing tests

1. Inherit from `HealthKitAssistantTestCase` (not `XCTestCase`)
2. Use `HealthKitSampleFactory` to create test data
3. Use base class helpers like `configureMockData()` and `invalidateCache()`

Example:

```swift
@MainActor
final class HealthKitAssistantMyFeatureTests: HealthKitAssistantTestCase {
    func testMyNewFeature() async throws {
        let samples = HealthKitSampleFactory.makeHRVSamples(
            values: [45.0, 50.0, 48.0],
            startDate: Date()
        )
        mockDataProvider.mockQuantitySamples = samples

        let result = await healthKit.myNewFeature()

        XCTAssertEqual(result, expectedValue)
    }
}
```

## Running tests

Run all tests:
```bash
xcodebuild test -project Murmur.xcodeproj -scheme Murmur -destination 'platform=iOS Simulator,OS=latest'
```

Run a specific test file:
```bash
xcodebuild test -project Murmur.xcodeproj -scheme Murmur \
    -destination 'platform=iOS Simulator,OS=latest' \
    -only-testing:MurmurTests/HealthKitAssistantRecentMetricsTests
```

## Guidelines

- Use `HealthKitSampleFactory` for test data
- Inherit from `HealthKitAssistantTestCase`
- Keep tests focused on one thing
- Use clear test names
- Mark async tests with `async throws`

## Async testing patterns

### Waiting for async operations

Never use `Thread.sleep()` in tests. Instead, use proper async patterns:

#### 1. XCTestExpectation for async operations

```swift
func testAsyncOperation() async throws {
    let expectation = XCTestExpectation(description: "Operation completes")

    Task {
        // Check condition periodically
        var checkCount = 0
        while checkCount < 40 { // 40 * 50ms = 2 seconds max
            if conditionMet {
                expectation.fulfill()
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            checkCount += 1
        }
        if checkCount >= 40 {
            expectation.fulfill() // Fulfill anyway to prevent hanging
        }
    }

    await fulfillment(of: [expectation], timeout: 2.5)
    XCTAssertTrue(conditionMet)
}
```

#### 2. waitForExistence for UI elements (UI tests only)

```swift
let element = app.buttons["Save"]
XCTAssertTrue(element.waitForExistence(timeout: 5.0))
```

#### 3. XCTNSPredicateExpectation for condition-based waiting (UI tests only)

```swift
let predicate = NSPredicate(format: "isHittable == true")
let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
let result = XCTWaiter.wait(for: [expectation], timeout: 5.0)
XCTAssertEqual(result, .completed)
```

#### 4. RunLoop for UI settling (UI tests only)

```swift
// Wait for animations or UI updates to complete
RunLoop.current.run(until: Date().addingTimeInterval(0.5))
```

### Common async test patterns

#### Waiting for Core Data saves

Use the helper method in XCTestCase+Extensions:

```swift
func testCoreDataSave() {
    // Make changes
    let entity = MyEntity(context: context)
    try? context.save()

    // Wait for persistence
    waitForDataPersistence(timeout: 0.5)

    // Assert
    XCTAssertNotNil(entity.id)
}
```

#### Waiting for UI to settle

```swift
func testUITransition() {
    button.tap()

    // Wait for transition animation
    waitForUIToSettle(timeout: 0.5)

    XCTAssertTrue(nextScreen.exists)
}
```

#### Waiting for sheet dismissal

```swift
func testSheetDismissal() {
    let sheet = app.sheets.firstMatch
    dismissButton.tap()

    waitForSheetDismissal(sheet, timeout: 3.0)

    XCTAssertFalse(sheet.exists)
}
```

### Why avoid Thread.sleep()?

- **Flaky tests**: Sleep doesn't guarantee the operation has completed, just that time has passed
- **Slow tests**: You often wait longer than necessary
- **Poor CI performance**: Tests that sleep accumulate wasted time
- **Unreliable**: UI animations or async operations may take variable time

### Best practices

1. **Use predicates**: XCTNSPredicateExpectation automatically retries until condition is met
2. **Set appropriate timeouts**: Not too short (causes flakiness), not too long (slows tests)
3. **Check for actual conditions**: Wait for the thing you care about, not arbitrary time
4. **Use helper methods**: Encapsulate common patterns in test helpers
