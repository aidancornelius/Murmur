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
