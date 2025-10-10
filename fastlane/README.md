fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

    Unit Tests

    Runs all unit tests for the Murmur scheme with code coverage.

    What this tests:
    - Core business logic and data models
    - Service layer functionality
    - Helper utilities and extensions

    Duration: <1 minute
    Device: iPhone 17 Pro
    Coverage: Enabled (generates code coverage report)


### ios test_ui

```sh
[bundle exec] fastlane ios test_ui
```

    UI Tests - Standard Devices

    Runs UI tests on standard devices (iPhone and iPad).

    What this tests:
    - User interface interactions
    - Navigation flows
    - Accessibility features
    - Visual layouts on different form factors

    Duration: ~2-3 minutes
    Devices: iPhone 17 Pro, iPad Pro 13-inch (M4)


### ios test_ui_full

```sh
[bundle exec] fastlane ios test_ui_full
```

    UI Tests - Full Device Coverage

    Runs UI tests across comprehensive device matrix (5 devices).

    What this tests:
    - Compatibility across device generations (iPhone 13-17)
    - Form factor variations (mini, standard, Pro, iPad sizes)
    - Screen size adaptations

    Duration: ~8-12 minutes
    Devices:
    - iPhone 17 Pro
    - iPhone 16 Pro
    - iPhone 15 Pro
    - iPad Pro 13-inch (M4)
    - iPad mini (A17 Pro)

    Use when: Pre-release validation or testing layout changes


### ios test_smoke

```sh
[bundle exec] fastlane ios test_smoke
```

    Smoke Tests - Critical User Journeys

    Quick validation of essential app functionality.

    What this tests:
    - Complete symptom entry flow
    - Navigate to day detail view
    - View trends chart
    - Add custom symptom type

    Duration: ~1 minute
    Device: iPhone 17 Pro
    Use when: Quick validation after small changes or before commits


### ios test_healthkit

```sh
[bundle exec] fastlane ios test_healthkit
```

    HealthKit Integration Tests - Normal Profile

    Runs core HealthKit integration tests with a normal health profile (7 days of data).

    What this tests:
    - App correctly imports synthetic HealthKit data (HRV, sleep, workouts, cycle tracking)
    - UI displays health metrics accurately
    - Data flows from HealthKit → SampleDataSeeder → Core Data → UI

    Duration: ~1-2 minutes
    Use when: Verifying basic HealthKit integration after changes


### ios test_healthkit_extended

```sh
[bundle exec] fastlane ios test_healthkit_extended
```

    HealthKit Integration Tests - Extended Historical Data

    Runs tests with 30 days of synthetic health data to verify historical data handling.

    What this tests:
    - App handles larger datasets (30 days vs standard 7 days)
    - Historical trends display correctly
    - Performance with extended data range

    Duration: ~3-5 minutes (longer due to data seeding)
    Use when: Testing historical data features or performance with larger datasets


### ios test_healthkit_deterministic

```sh
[bundle exec] fastlane ios test_healthkit_deterministic
```

    HealthKit Deterministic Fixture Tests

    Verifies deterministic data generation - same seed produces identical results.

    What this tests:
    - Synthetic data generator produces identical output with seed=42
    - UI displays exact expected values from fixture data
    - Determinism is maintained across test runs

    Duration: ~1 minute
    Use when: Verifying deterministic behaviour after changing data generation logic
    Critical for: Reproducible test results and debugging


### ios test_healthkit_utility

```sh
[bundle exec] fastlane ios test_healthkit_utility
```

    HealthKitUtility Library Smoke Tests

    Low-level tests of the HealthKitUtility synthetic data library (not UI tests).

    What this tests:
    - SyntheticDataGenerator produces deterministic output
    - HKSample conversion preserves data accuracy
    - Library functions work correctly in isolation

    Duration: <30 seconds
    Use when: Verifying the underlying data library before UI testing
    Test suite: MurmurTests (unit tests, not UI tests)


### ios test_healthkit_full

```sh
[bundle exec] fastlane ios test_healthkit_full
```

    Comprehensive HealthKit Test Suite

    Runs all HealthKit-related tests in sequence:
    1. Library smoke tests (HealthKitUtility)
    2. Normal integration tests (7 days)
    3. Deterministic fixture tests (seed validation)
    4. Extended historical data tests (30 days)

    Duration: ~5-8 minutes
    Use when: Full validation before merging HealthKit changes
    Recommended: Run this before releasing features that touch health data


### ios test_all

```sh
[bundle exec] fastlane ios test_all
```

    Standard Test Suite (Unit + UI + HealthKit)

    Runs the standard test suite:
    1. Unit tests (Murmur scheme)
    2. UI tests (MurmurUITests scheme)
    3. HealthKit integration tests (7 days)

    Duration: ~3-5 minutes
    Use when: General validation before commits


### ios test_complete

```sh
[bundle exec] fastlane ios test_complete
```

    Complete Test Suite (Unit + UI + Full HealthKit)

    The most comprehensive test suite, including:
    1. All unit tests
    2. All UI tests
    3. Complete HealthKit test suite (utility + integration + deterministic + extended)

    Duration: ~10-15 minutes
    Use when:
    - Pre-release validation
    - Before merging major HealthKit features
    - Weekly regression testing


### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate screenshots for App Store (standard devices)

### ios screenshots_framed

```sh
[bundle exec] fastlane ios screenshots_framed
```

Generate screenshots with device frames

### ios add_frames

```sh
[bundle exec] fastlane ios add_frames
```

Add device frames to screenshots

### ios prepare_screenshots

```sh
[bundle exec] fastlane ios prepare_screenshots
```

Generate and resize screenshots for App Store

### ios prepare_framed_screenshots

```sh
[bundle exec] fastlane ios prepare_framed_screenshots
```

Generate framed screenshots ready for App Store

### ios resize_screenshots

```sh
[bundle exec] fastlane ios resize_screenshots
```

Resize screenshots for App Store Connect

### ios resize_screenshots_framed

```sh
[bundle exec] fastlane ios resize_screenshots_framed
```

Resize framed screenshots for App Store Connect

### ios clean

```sh
[bundle exec] fastlane ios clean
```

Clean test outputs and screenshots

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
