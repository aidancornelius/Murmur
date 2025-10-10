# HealthKit Test Screenshots

The HealthKit integration tests now automatically capture screenshots at key steps in the test flow.

## What Gets Captured

### Deterministic Fixture Test (`testHealthMetricsMatchDeterministicFixture`)
1. **01-app-launched-with-healthkit-data** - App with seeded HealthKit data loaded
2. **02-navigated-to-analysis** - Analysis view showing trends
3. **03-opened-view-selector** - View selector menu open
4. **04-health-correlations-displayed** - Health correlations with HRV, resting HR, sleep data
5. **05-metrics-verified-against-fixture** - Final state with verified values

### Health Analysis Display Test (`testHealthAnalysisDisplaysMetricValues`)
1. **healthkit-analysis-01-app-launched** - Initial app state
2. **healthkit-analysis-02-analysis-view** - Analysis view
3. **healthkit-analysis-03-view-selector-menu** - Menu showing Health option
4. **healthkit-analysis-04-health-correlations** - Displayed health metrics

## How to View Screenshots

### Option 1: Xcode Test Report (Recommended)
1. Run tests in Xcode (⌘U) or via fastlane
2. Open the Report Navigator (⌘9)
3. Select the test run
4. Click on the specific test
5. Scroll down to see attached screenshots

### Option 2: Result Bundle
Screenshots are saved in the `.xcresult` bundle:

```bash
# Run tests
fastlane test_healthkit_deterministic

# Open result bundle in Xcode
open fastlane-output/test-reports/MurmurUITests.xcresult
```

### Option 3: Export Screenshots
```bash
# Extract screenshots from result bundle
xcrun xcresulttool get --path MurmurUITests.xcresult \
  --format json > results.json

# Or use xcparse (install: brew install chargepoint/xcparse/xcparse)
xcparse screenshots MurmurUITests.xcresult screenshots/
```

## Screenshot Naming Convention

Screenshots follow a numbered naming pattern:
- `01-`, `02-`, etc. for deterministic test steps
- `healthkit-analysis-01-`, etc. for analysis test steps

This ensures they appear in chronological order in test reports.

## When Screenshots Are Captured

Screenshots are captured when the `-CaptureTestScreenshots` launch argument is present.

This is **already enabled** in `project.yml` for the MurmurUITests scheme, so screenshots are captured automatically for:
- All fastlane HealthKit test lanes
- Manual test runs in Xcode
- CI/CD pipeline runs

## Disabling Screenshots

To temporarily disable screenshot capture (faster test runs):

```bash
# Edit project.yml and set:
commandLineArguments:
  "-CaptureTestScreenshots":
    enabled: false

# Then regenerate project
xcodegen generate
```

## Use Cases

### Debugging Test Failures
Screenshots show exactly what the UI looked like at each step, making it easy to:
- See if health metrics are displaying correctly
- Verify correlation calculations are shown
- Check if navigation worked as expected
- Identify UI layout issues

### Documentation
Screenshots provide visual documentation of:
- How HealthKit data appears in the UI
- The analysis workflow
- Expected UI states with deterministic data

### Regression Testing
Compare screenshots across test runs to:
- Detect unintended UI changes
- Verify consistent rendering with deterministic data
- Document visual differences between health profiles (normal vs. stress)

## Adding More Screenshots

To add screenshots to other tests, use the `captureStep()` helper:

```swift
func testMyHealthKitFeature() throws {
    launchWithNormalHealthKit()

    captureStep("01-initial-state")

    // Perform some action
    app.buttons["Some Button"].tap()

    captureStep("02-after-button-tap")

    // Continue testing...
}
```

The `captureStep()` helper:
- Only captures when `-CaptureTestScreenshots` is enabled
- Attaches screenshots to the test result with `.keepAlways` lifetime
- Uses the provided name for easy identification
