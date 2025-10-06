# Murmur UI test infrastructure

This directory contains the UI testing infrastructure for Murmur, built using the Page Object Model pattern.

## Overview

The test infrastructure provides:

- **Page Objects** - Reusable screen abstractions for consistent test interactions
- **Test Helpers** - Extensions and utilities to reduce flakiness and improve test reliability
- **Launch States** - Predefined app configurations for different test scenarios
- **Test Data Builders** - Flexible data seeding and environment configuration

## Directory structure

```
MurmurUITests/
├── PageObjects/              # Screen abstractions
│   ├── TimelineScreen.swift
│   ├── AddEntryScreen.swift
│   ├── AnalysisScreen.swift
│   ├── SettingsScreen.swift
│   └── DayDetailScreen.swift
├── Helpers/                  # Test utilities
│   ├── XCTestCase+Extensions.swift
│   ├── XCUIElement+Extensions.swift
│   ├── TestDataBuilder.swift
│   └── AppLaunchState.swift
├── Examples/                 # Example tests
│   └── ExampleUserJourneyTest.swift
└── MurmurUITests.swift      # Existing tests
```

## Using Page Objects

Page Objects provide a clean abstraction over UI screens, making tests more readable and maintainable.

### Basic usage

```swift
func testAddSymptom() throws {
    app.launchWithData()

    let timeline = TimelineScreen(app: app)
    let addEntry = AddEntryScreen(app: app)

    timeline.navigateToAddEntry()
    addEntry.addSymptomEntry(symptom: "Headache", severity: 4)

    XCTAssertTrue(timeline.hasEntry(containing: "Headache"))
}
```

### Available Page Objects

#### TimelineScreen
Main timeline view with entry list and navigation.

```swift
let timeline = TimelineScreen(app: app)
timeline.navigateToAddEntry()
timeline.navigateToAnalysis()
timeline.navigateToSettings()
timeline.pullToRefresh()
XCTAssertTrue(timeline.hasEntries())
```

#### AddEntryScreen
Symptom entry form.

```swift
let addEntry = AddEntryScreen(app: app)
addEntry.openSymptomSearch()
addEntry.searchForSymptom("Headache")
addEntry.selectSymptom(named: "Headache")
addEntry.setSeverity(4)
addEntry.enterNote("After long screen time")
addEntry.save()
```

#### AnalysisScreen
Analysis views with trends, calendar, and history.

```swift
let analysis = AnalysisScreen(app: app)
analysis.switchToTrends()
analysis.switchToCalendar()
analysis.switchToHistory()
XCTAssertTrue(analysis.isShowingCalendar())
```

#### SettingsScreen
Settings navigation and management.

```swift
let settings = SettingsScreen(app: app)
settings.navigateToTrackedSymptoms()
settings.addSymptomType(name: "Custom Symptom")
settings.deleteSymptomType(named: "Custom Symptom")
```

#### DayDetailScreen
Day detail view showing entries for a specific day.

```swift
let dayDetail = DayDetailScreen(app: app)
dayDetail.tapFirstEntry()
dayDetail.deleteEntry(at: 0)
XCTAssertTrue(dayDetail.hasEntry(for: "Headache"))
```

## Using test helpers

### XCTestCase extensions

Enhanced assertion and wait methods:

```swift
// Assert element exists with timeout
assertExists(element, timeout: 5, message: "Should exist")

// Assert element doesn't exist
assertNotExists(element)

// Assert element is hittable/tappable
assertHittable(element)

// Wait for element and return it
let button = require(element, timeout: 5)

// Wait for element to disappear
waitForDisappearance(element)

// Retry flaky actions
retry(attempts: 3, delay: 1.0) {
    return element.exists && element.isHittable
}

// Take screenshots
takeScreenshot(named: "Timeline-Populated")

// CI-aware timeouts
let timeout = timeout(5) // 5s locally, 10s in CI
```

### XCUIElement extensions

Stable interaction methods:

```swift
// Tap when element is stable (animations complete)
element.tapWhenStable()

// Tap when element is hittable
element.tapWhenHittable()

// Wait for element to be hittable
element.waitForHittable(timeout: 5)

// Clear and type new text
textField.clearAndType("New text")

// Adjust slider to level
slider.adjustSliderToLevel(4, maxLevel: 5)

// Wait for label to contain text
element.waitForLabelContaining("Success")

// Scroll to make element visible
element.scrollToVisible()

// Debug element details
element.debugPrint()
```

## App launch states

Launch the app in different configurations:

### Quick launch methods

```swift
app.launchWithData()        // Standard sample data
app.launchEmpty()           // No entries
app.launchFresh()           // Fresh install
app.launchWithLargeData()   // 1000+ entries
app.launchDarkMode()        // Dark appearance
app.launchLightMode()       // Light appearance
```

### Scenario-based launch

```swift
app.launch(state: .withData)
app.launch(state: .emptyState)
app.launch(state: .onboarding)
app.launch(state: .lowStorage)
app.launch(state: .offline)
```

### Custom configuration

```swift
app.launch(
    scenario: .activeUser,
    appearance: .dark,
    contentSize: .accessibilityExtraLarge,
    featureFlags: [.disableHealthKit, .enableDebugLogging]
)
```

### Accessibility testing

```swift
app.launchForAccessibility(
    contentSize: .accessibilityExtraLarge,
    boldText: true,
    reduceMotion: true
)
```

### Snapshot testing

```swift
app.launchForSnapshots(locale: .australianLocale)
```

## Test data builder

Flexible test data configuration:

### Launch arguments for scenarios

```swift
TestDataBuilder.launchArguments(for: .newUser)
TestDataBuilder.launchArguments(for: .activeUser)
TestDataBuilder.launchArguments(for: .heavyUser)
TestDataBuilder.launchArguments(for: .emptyState)
```

### Launch arguments for accessibility

```swift
TestDataBuilder.accessibilityLaunchArguments(
    contentSize: .accessibilityLarge,
    boldText: true,
    reduceMotion: false,
    increaseContrast: true
)
```

### Feature flags

```swift
TestDataBuilder.launchArguments(featureFlags: [
    .disableHealthKit,
    .disableLocation,
    .enableDebugLogging,
    .simulateLowStorage
])
```

### Locale testing

```swift
TestDataBuilder.launchArguments(
    locale: TestDataBuilder.australianLocale
)
```

## Writing new tests

### Basic test structure

```swift
final class MyUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testMyFeature() throws {
        // Launch with appropriate state
        app.launchWithData()

        // Create page objects
        let timeline = TimelineScreen(app: app)

        // Use page objects for interactions
        timeline.waitForLoad()
        assertExists(timeline.logSymptomButton)

        // Perform test actions
        timeline.navigateToAddEntry()

        // Verify results
        XCTAssertTrue(timeline.hasEntries())
    }
}
```

### Best practices

1. **Use Page Objects** - Don't access UI elements directly; use page objects
2. **Use helpers** - Use `assertExists()` instead of manual waits
3. **Launch appropriately** - Choose the right launch state for your test
4. **Test isolation** - Each test should be independent
5. **Meaningful names** - Test names should describe what they verify
6. **Reduce flakiness** - Use `tapWhenStable()` and `waitForHittable()`
7. **CI awareness** - Use `timeout()` helper for CI-aware timeouts

### Example: Complete user journey

```swift
func testCompleteSymptomEntry() throws {
    app.launchWithData()

    let timeline = TimelineScreen(app: app)
    let addEntry = AddEntryScreen(app: app)

    // Navigate and wait
    timeline.navigateToAddEntry()
    addEntry.waitForLoad()

    // Complete entry
    addEntry.openSymptomSearch()
    addEntry.searchForSymptom("Headache")
    addEntry.selectSymptom(named: "Headache")
    addEntry.setSeverity(4)
    addEntry.enterNote("After long screen time")
    addEntry.save()

    // Verify
    assertExists(timeline.logSymptomButton)
    XCTAssertTrue(timeline.hasEntry(containing: "Headache"))
}
```

## Running tests

### From Xcode
1. Select MurmurUITests scheme
2. Choose target device/simulator
3. Run tests (Cmd+U)

### From command line
```bash
xcodebuild test -scheme MurmurUITests -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### With Fastlane
```bash
fastlane ui_tests
```

## Debugging tests

### Enable verbose logging
```swift
app.launchArguments += ["-EnableDebugLogging"]
```

### Take screenshots
```swift
takeScreenshot(named: "debug-state")
```

### Print element details
```swift
element.debugPrint()
```

### Check element hierarchy
```swift
print(app.debugDescription)
```

## Common issues

### Element not found
- Use `waitForExistence(timeout:)` instead of checking `exists` immediately
- Check accessibility identifiers are correct
- Use `element.debugPrint()` to inspect element properties

### Flaky tests
- Use `tapWhenStable()` instead of `tap()`
- Increase timeouts with `timeout()` helper
- Add explicit waits with `waitForHittable()`
- Use retry mechanism for unreliable operations

### Animation issues
- Use `tapWhenStable(delay:)` to wait for animations
- Check `isHittable` before tapping
- Use `Thread.sleep(forTimeInterval:)` sparingly

## Next steps

See `Examples/ExampleUserJourneyTest.swift` for comprehensive examples of using the test infrastructure.

To implement the full test suite, create:
- UserJourneyTests.swift - End-to-end user flows
- SnapshotTests.swift - Visual regression tests
- AccessibilityTests.swift - VoiceOver and dynamic type
- EdgeCaseTests.swift - Error and empty states
- PerformanceTests.swift - Performance benchmarks
