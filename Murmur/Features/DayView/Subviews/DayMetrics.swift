// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DayMetrics.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Component displaying daily metrics and statistics.
//
import CoreLocation
import SwiftUI

/// Aggregated metrics computed from a day's symptom entries
struct DayMetrics {
    let averageHRV: Double?
    let averageRestingHR: Double?
    let primaryLocation: String?
    let predominantState: PhysiologicalState?
    let cycleDay: Int?

    @MainActor
    init(entries: [SymptomEntry]) {
        let hrvValues = entries.compactMap { $0.hkHRV?.doubleValue }
        averageHRV = hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count)
        let restingValues = entries.compactMap { $0.hkRestingHR?.doubleValue }
        averageRestingHR = restingValues.isEmpty ? nil : restingValues.reduce(0, +) / Double(restingValues.count)
        let locationStrings = entries.compactMap { entry -> String? in
            guard let placemark = entry.locationPlacemark else { return nil }
            let formatted = DayMetrics.format(placemark: placemark)
            return formatted.isEmpty ? nil : formatted
        }
        primaryLocation = locationStrings.first

        // Compute predominant physiological state
        let states = entries.compactMap { entry -> PhysiologicalState? in
            PhysiologicalState.compute(
                hrv: entry.hkHRV?.doubleValue,
                restingHR: entry.hkRestingHR?.doubleValue,
                sleepHours: entry.hkSleepHours?.doubleValue,
                workoutMinutes: entry.hkWorkoutMinutes?.doubleValue,
                cycleDay: entry.hkCycleDay?.intValue,
                flowLevel: entry.hkFlowLevel
            )
        }

        if !states.isEmpty {
            let stateCounts = Dictionary(grouping: states, by: { $0 })
            predominantState = stateCounts.max { $0.value.count < $1.value.count }?.key
        } else {
            predominantState = nil
        }

        // Get cycle day from most recent entry
        cycleDay = entries.first?.hkCycleDay?.intValue
    }

    private static func format(placemark: CLPlacemark) -> String {
        [placemark.subLocality, placemark.locality, placemark.country]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
