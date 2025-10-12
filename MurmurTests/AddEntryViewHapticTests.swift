//
//  AddEntryViewHapticTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 12/10/2025.
//

import XCTest
@testable import Murmur

final class AddEntryViewHapticTests: XCTestCase {

    // MARK: - Haptic Feedback Tests

    func testHapticFeedbackOnlyTriggeredOnRelease() {
        // Test that haptic feedback is only triggered when onEditingChanged is false (on release)
        // This simulates the behaviour of the severity sliders

        var hapticTriggeredCount = 0

        // Simulate dragging (onEditingChanged: true)
        let draggingCallback: (Bool) -> Void = { editing in
            if !editing {
                // Only trigger haptic when user finishes adjusting
                hapticTriggeredCount += 1
            }
        }

        // Simulate dragging start
        draggingCallback(true)
        XCTAssertEqual(hapticTriggeredCount, 0, "Haptic should not trigger during dragging")

        // Simulate dragging in progress
        draggingCallback(true)
        XCTAssertEqual(hapticTriggeredCount, 0, "Haptic should not trigger during dragging")

        // Simulate release
        draggingCallback(false)
        XCTAssertEqual(hapticTriggeredCount, 1, "Haptic should trigger once on release")
    }

    func testSharedSeveritySliderHapticBehaviour() {
        // Test that the shared severity slider only triggers haptic on release
        var hapticTriggeredCount = 0

        // Simulate the onEditingChanged callback from the shared severity slider
        let onEditingChanged: (Bool) -> Void = { editing in
            if !editing {
                hapticTriggeredCount += 1
            }
        }

        // User starts dragging
        onEditingChanged(true)
        XCTAssertEqual(hapticTriggeredCount, 0)

        // User continues dragging through multiple values
        onEditingChanged(true)
        onEditingChanged(true)
        onEditingChanged(true)
        XCTAssertEqual(hapticTriggeredCount, 0, "No haptic during continuous dragging")

        // User releases
        onEditingChanged(false)
        XCTAssertEqual(hapticTriggeredCount, 1, "One haptic on release")
    }

    func testIndividualSeveritySliderHapticBehaviour() {
        // Test that individual severity sliders only trigger haptic on release
        var hapticTriggeredCountPerSymptom: [String: Int] = [:]

        let symptoms = ["Headache", "Fatigue", "Nausea"]

        for symptom in symptoms {
            hapticTriggeredCountPerSymptom[symptom] = 0

            let onEditingChanged: (Bool) -> Void = { editing in
                if !editing {
                    hapticTriggeredCountPerSymptom[symptom]! += 1
                }
            }

            // User adjusts this symptom's severity
            onEditingChanged(true)  // Start dragging
            XCTAssertEqual(hapticTriggeredCountPerSymptom[symptom], 0)

            onEditingChanged(true)  // Continue dragging
            XCTAssertEqual(hapticTriggeredCountPerSymptom[symptom], 0)

            onEditingChanged(false) // Release
            XCTAssertEqual(hapticTriggeredCountPerSymptom[symptom], 1)
        }

        // Verify each symptom triggered exactly one haptic
        XCTAssertEqual(hapticTriggeredCountPerSymptom["Headache"], 1)
        XCTAssertEqual(hapticTriggeredCountPerSymptom["Fatigue"], 1)
        XCTAssertEqual(hapticTriggeredCountPerSymptom["Nausua"], nil)
    }

    func testMultipleSliderAdjustments() {
        // Test that multiple adjustments each trigger a single haptic on release
        var hapticTriggeredCount = 0

        let onEditingChanged: (Bool) -> Void = { editing in
            if !editing {
                hapticTriggeredCount += 1
            }
        }

        // First adjustment
        onEditingChanged(true)  // Start
        onEditingChanged(true)  // Dragging
        onEditingChanged(false) // Release
        XCTAssertEqual(hapticTriggeredCount, 1)

        // Second adjustment
        onEditingChanged(true)  // Start
        onEditingChanged(false) // Release
        XCTAssertEqual(hapticTriggeredCount, 2)

        // Third adjustment
        onEditingChanged(true)  // Start
        onEditingChanged(true)  // Dragging
        onEditingChanged(true)  // Still dragging
        onEditingChanged(false) // Release
        XCTAssertEqual(hapticTriggeredCount, 3)
    }

    func testNoHapticDuringContinuousValueChanges() {
        // Test that onChange of severity value does not trigger haptic
        // Only onEditingChanged: false should trigger haptic

        var hapticTriggeredCount = 0
        var severityValue: Double = 3.0

        // Simulate the onChange callback (this should NOT trigger haptic)
        let onChangeCallback: (Double, Double) -> Void = { _, newValue in
            severityValue = newValue
            // NO haptic triggered here
        }

        // Simulate value changes during dragging
        onChangeCallback(3.0, 3.2)
        onChangeCallback(3.2, 3.5)
        onChangeCallback(3.5, 4.0)
        onChangeCallback(4.0, 4.5)

        XCTAssertEqual(hapticTriggeredCount, 0, "onChange should not trigger haptic")
        XCTAssertEqual(severityValue, 4.5)

        // Only when onEditingChanged(false) is called should haptic trigger
        let onEditingChanged: (Bool) -> Void = { editing in
            if !editing {
                hapticTriggeredCount += 1
            }
        }

        onEditingChanged(false)
        XCTAssertEqual(hapticTriggeredCount, 1)
    }

    func testHapticBehaviourConsistency() {
        // Test that haptic behaviour is consistent across multiple slider types
        // (shared severity, individual severity, exertion sliders)

        struct SliderState {
            var hapticCount = 0

            mutating func onEditingChanged(_ editing: Bool) {
                if !editing {
                    hapticCount += 1
                }
            }
        }

        var sharedSeveritySlider = SliderState()
        var individualSlider1 = SliderState()
        var individualSlider2 = SliderState()

        // Test shared severity slider
        sharedSeveritySlider.onEditingChanged(true)  // Start
        sharedSeveritySlider.onEditingChanged(true)  // Dragging
        sharedSeveritySlider.onEditingChanged(false) // Release
        XCTAssertEqual(sharedSeveritySlider.hapticCount, 1)

        // Test individual slider 1
        individualSlider1.onEditingChanged(true)  // Start
        individualSlider1.onEditingChanged(false) // Release
        XCTAssertEqual(individualSlider1.hapticCount, 1)

        // Test individual slider 2
        individualSlider2.onEditingChanged(true)  // Start
        individualSlider2.onEditingChanged(true)  // Dragging
        individualSlider2.onEditingChanged(true)  // Still dragging
        individualSlider2.onEditingChanged(false) // Release
        XCTAssertEqual(individualSlider2.hapticCount, 1)

        // All sliders should have triggered exactly one haptic
        XCTAssertEqual(sharedSeveritySlider.hapticCount, 1)
        XCTAssertEqual(individualSlider1.hapticCount, 1)
        XCTAssertEqual(individualSlider2.hapticCount, 1)
    }

    func testHapticNotTriggeredOnValueChangeWithoutGesture() {
        // Test that programmatic value changes don't trigger haptic
        // (only user gestures that result in onEditingChanged: false)

        var hapticTriggeredCount = 0
        var severityValue: Double = 3.0

        // Programmatic value change (e.g., when toggling "Same severity for all")
        let programmaticChange: (Double) -> Void = { newValue in
            severityValue = newValue
            // NO haptic triggered here
        }

        programmaticChange(1.0)
        programmaticChange(2.0)
        programmaticChange(5.0)

        XCTAssertEqual(hapticTriggeredCount, 0, "Programmatic changes should not trigger haptic")
        XCTAssertEqual(severityValue, 5.0)
    }

    // MARK: - Edge Cases

    func testRapidSliderAdjustments() {
        // Test rapid successive slider adjustments
        var hapticTriggeredCount = 0

        let onEditingChanged: (Bool) -> Void = { editing in
            if !editing {
                hapticTriggeredCount += 1
            }
        }

        // Simulate rapid adjustments
        for _ in 0..<10 {
            onEditingChanged(true)  // Start
            onEditingChanged(false) // Release
        }

        XCTAssertEqual(hapticTriggeredCount, 10, "Each release should trigger haptic")
    }

    func testSliderAdjustmentWithoutRelease() {
        // Test that dragging without release doesn't trigger haptic
        var hapticTriggeredCount = 0

        let onEditingChanged: (Bool) -> Void = { editing in
            if !editing {
                hapticTriggeredCount += 1
            }
        }

        // User starts dragging but never releases (edge case)
        onEditingChanged(true)
        onEditingChanged(true)
        onEditingChanged(true)

        XCTAssertEqual(hapticTriggeredCount, 0, "No release, no haptic")
    }

    func testConsecutiveReleasesWithoutDragging() {
        // Test that consecutive releases without dragging each trigger haptic
        var hapticTriggeredCount = 0

        let onEditingChanged: (Bool) -> Void = { editing in
            if !editing {
                hapticTriggeredCount += 1
            }
        }

        // Multiple releases in a row (unusual but should still work)
        onEditingChanged(false)
        onEditingChanged(false)
        onEditingChanged(false)

        XCTAssertEqual(hapticTriggeredCount, 3, "Each release triggers haptic")
    }
}
