# HealthKit test data integration guide

This guide explains how to use [HealthKitUtility](https://github.com/aidancornelius/HealthKitUtility) to generate realistic HealthKit test data in your tests.

## Overview

HealthKitTestData is a Swift package that generates synthetic HealthKit data with realistic patterns. This is much better than manually creating test data because:

- **Realistic patterns**: Data follows natural physiological cycles (e.g., sleep cycles, heart rate variability)
- **Multiple presets**: Choose from normal, lower stress, higher stress, or edge case profiles
- **Time savings**: Generate weeks of data instantly instead of manually creating samples
- **Consistency**: Reproducible test data with seeded random generation
- **Comprehensive**: Supports HRV, heart rate, sleep, workouts, and more

## Quick start

### Basic usage

```swift
import XCTest
import HealthKitTestData
@testable import Murmur

@MainActor
final class MyHealthKitTests: XCTestCase {
    func testWithRealisticData() async throws {
        // Create a mock provider with realistic normal health data
        let mockProvider = createMockProviderWithRealisticData(preset: .normal)
        let healthKit = HealthKitAssistant(dataProvider: mockProvider)

        // Use the healthKit instance in your tests
        let hrv = await healthKit.recentHRV()
        XCTAssertNotNil(hrv)
    }
}
```

### Available presets

The package uses `GenerationPreset` with these cases:

- `.normal` - Healthy baseline metrics
- `.lowerStress` - Relaxed state with better recovery metrics
- `.higherStress` - Elevated heart rate, reduced HRV, less sleep
- `.edgeCases` - Boundary conditions and extreme values

### Custom date ranges

```swift
// Generate data for a specific period with a seed for reproducibility
let mockProvider = createMockProviderWithRealisticData(
    preset: .normal,
    startDate: .daysAgo(30),
    endDate: Date(),
    seed: 12345  // Same seed = same data
)
```

## How it works

HealthKitTestData generates lightweight data bundles (`ExportedHealthBundle`) that need to be converted to `HKSamples`. Our integration handles this automatically:

1. Generate bundle using `SyntheticDataGenerator.generateHealthData()`
2. Convert bundle to HKSamples using `convertToHKSamples()`
3. Populate `MockHealthKitDataProvider` with the samples
4. Use with `HealthKitAssistant` as normal

## Advanced usage

### Manual provider population

```swift
let mockProvider = MockHealthKitDataProvider()

HealthKitUtilityTestHelper.populateMockProvider(
    mockProvider,
    preset: .higherStress,
    startDate: .daysAgo(14),
    endDate: Date(),
    seed: 99999
)

let healthKit = HealthKitAssistant(dataProvider: mockProvider)
```

### Comparative testing

```swift
func testStressImpact() async throws {
    // Compare normal vs higher stress profiles using same seed
    let normalProvider = createMockProviderWithRealisticData(
        preset: .normal,
        seed: 54321
    )
    let stressProvider = createMockProviderWithRealisticData(
        preset: .higherStress,
        seed: 54321
    )

    let normalHealthKit = HealthKitAssistant(dataProvider: normalProvider)
    let stressHealthKit = HealthKitAssistant(dataProvider: stressProvider)

    let normalHRV = await normalHealthKit.recentHRV()
    let stressHRV = await stressHealthKit.recentHRV()

    // Compare the values
    print("Normal: \(normalHRV ?? 0)ms, Stress: \(stressHRV ?? 0)ms")
}
```

### Direct bundle generation

```swift
// Generate raw bundle
let bundle = HealthKitUtilityTestHelper.generateNormalData(
    startDate: .daysAgo(7),
    endDate: Date(),
    seed: 11111
)

// Convert to HKSamples
let (quantitySamples, categorySamples, workouts) =
    HealthKitUtilityTestHelper.convertToHKSamples(bundle: bundle)

// Use samples directly
print("Generated \(quantitySamples.count) quantity samples")
```

## Testing baselines

```swift
func testBaselineCalculation() async throws {
    // Generate 30 days of data (required for baseline calculation)
    let mockProvider = createMockProviderWithRealisticData(
        preset: .normal,
        startDate: .daysAgo(30),
        endDate: Date()
    )
    let healthKit = HealthKitAssistant(dataProvider: mockProvider)

    // Clear existing baselines
    await MainActor.run {
        HealthMetricBaselines.shared.hrvBaseline = nil
    }

    // Update baselines
    await healthKit.updateBaselines()

    // Give async calculation time to complete
    try await Task.sleep(nanoseconds: 500_000_000)

    // Check baselines were calculated
    let hrvBaseline = await MainActor.run {
        HealthMetricBaselines.shared.hrvBaseline
    }
    XCTAssertNotNil(hrvBaseline)
    XCTAssertGreaterThan(hrvBaseline?.sampleCount ?? 0, 10)
}
```

## Example tests

See `HealthKitUtilityExampleTests.swift` for focused smoke tests including:

- Basic data generation and conversion
- Stress profile comparison
- Baseline calculation with 30 days of data
- Conversion layer validation

## API reference

### Key types

- `GenerationPreset`: Enum with `.normal`, `.lowerStress`, `.higherStress`, `.edgeCases`
- `ExportedHealthBundle`: Lightweight struct containing generated health data
- `ManipulationType`: How to handle existing data (use `.smoothReplace`)

### Helper methods

```swift
// Generate and populate in one step
createMockProviderWithRealisticData(
    preset: GenerationPreset = .normal,
    startDate: Date = .daysAgo(7),
    endDate: Date = Date(),
    seed: Int = random
) -> MockHealthKitDataProvider

// Manual population
HealthKitUtilityTestHelper.populateMockProvider(
    provider: MockHealthKitDataProvider,
    preset: GenerationPreset,
    startDate: Date,
    endDate: Date,
    seed: Int
)

// Convert bundles to HKSamples
HealthKitUtilityTestHelper.convertToHKSamples(
    bundle: ExportedHealthBundle
) -> (quantitySamples, categorySamples, workouts)
```

## Tips

1. **Use seeds for reproducibility**: Pass the same seed value to get identical data across test runs
2. **Date ranges matter**: Baseline calculations need 10+ days of data
3. **Async operations**: Remember to await async methods and give time for calculations
4. **Print debugging**: Use print statements to inspect generated values during development
5. **Combine with existing mocks**: You can mix HealthKitTestData with manual mocks

## Troubleshooting

### Import errors

Make sure you're importing the correct module:
```swift
import HealthKitTestData  // ✅ Correct
import HealthKitUtility   // ❌ Wrong - no such module
```

### No data returned

- Ensure the date range includes recent dates if testing "recent" methods
- Check that the mock provider is properly configured
- Verify async operations are being awaited
- Check the seed value if expecting specific data

### Unrealistic values

- Double-check you're using the correct preset (`.normal`, `.lowerStress`, `.higherStress`, `.edgeCases`)
- Remember that edge cases intentionally generate extreme values
- Inspect the raw bundle to understand the generated data
- Try a different seed value

### Baseline calculation fails

- Ensure you have at least 10 samples in the date range
- Use a longer date range (e.g., 30 days instead of 7)
- Give async operations enough time to complete (500ms sleep)
- Check that samples are in the correct date range

## Further reading

- [HealthKitUtility GitHub](https://github.com/aidancornelius/HealthKitUtility)
- See `HealthKitTestHelpers.swift` for existing mock helpers
- See `HealthKitAssistantTests.swift` for examples using manual mocks
- See `HealthKitUtilityHelpers.swift` for conversion layer implementation
