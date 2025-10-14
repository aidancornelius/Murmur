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

Run unit tests with code coverage [<1 min, iPhone 17 Pro]

### ios test_ui

```sh
[bundle exec] fastlane ios test_ui
```

Run UI tests on iPhone and iPad [2-3 mins, 2 devices]

### ios test_ui_full

```sh
[bundle exec] fastlane ios test_ui_full
```

Run UI tests across 5 devices including multiple iPhone and iPad models [8-12 mins]

### ios test_smoke

```sh
[bundle exec] fastlane ios test_smoke
```

Run smoke tests for critical user journeys [~1 min, iPhone 17 Pro]

### ios test_widgets

```sh
[bundle exec] fastlane ios test_widgets
```

Run widget tests [<1 min, iPhone 17 Pro]

### ios test_unified_event

```sh
[bundle exec] fastlane ios test_unified_event
```

Run UnifiedEventView tests [<1 min, iPhone 17 Pro]

### ios test_intents

```sh
[bundle exec] fastlane ios test_intents
```

Run App Intents tests [<1 min, iPhone 17 Pro]

### ios test_background

```sh
[bundle exec] fastlane ios test_background
```

Run background tasks tests [<1 min, iPhone 17 Pro]

### ios test_new_features

```sh
[bundle exec] fastlane ios test_new_features
```

Run all new feature tests: widgets, unified event, intents, background [2-3 mins]

### ios test_core_data

```sh
[bundle exec] fastlane ios test_core_data
```

Run core data tests [<1 min, iPhone 17 Pro]

### ios test_analysis

```sh
[bundle exec] fastlane ios test_analysis
```

Run analysis engine tests [<1 min, iPhone 17 Pro]

### ios test_integrations

```sh
[bundle exec] fastlane ios test_integrations
```

Run location and calendar tests [<1 min, iPhone 17 Pro]

### ios test_healthkit

```sh
[bundle exec] fastlane ios test_healthkit
```

Run HealthKit integration tests with 7 days of synthetic data [1-2 mins]

### ios test_healthkit_extended

```sh
[bundle exec] fastlane ios test_healthkit_extended
```

Run HealthKit integration tests with 30 days of synthetic data [3-5 mins]

### ios test_healthkit_deterministic

```sh
[bundle exec] fastlane ios test_healthkit_deterministic
```

Verify deterministic data generation with seed=42 [~1 min]

### ios test_healthkit_utility

```sh
[bundle exec] fastlane ios test_healthkit_utility
```

Run unit tests for HealthKitUtility synthetic data library [<30 secs]

### ios test_healthkit_full

```sh
[bundle exec] fastlane ios test_healthkit_full
```

Run all HealthKit tests: utility + integration + deterministic + extended [5-8 mins]

### ios test_all

```sh
[bundle exec] fastlane ios test_all
```

Run standard test suite: unit + UI + HealthKit integration [3-5 mins]

### ios test_complete

```sh
[bundle exec] fastlane ios test_complete
```

Run complete test suite: unit + UI + full HealthKit [10-15 mins]

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate screenshots for App Store [standard devices]

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
