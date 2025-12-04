// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DaySummary.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Computed daily summary including load scores and metrics.
//
import SwiftUI

struct DaySummary: Hashable, Identifiable {
    var id: Date { date }

    let date: Date
    let entryCount: Int
    let uniqueSymptoms: Int
    let averageSeverity: Double  // Normalised for calculations (higher = worse)
    let rawAverageSeverity: Double  // Raw average for display (1-5 scale)
    let severityLevel: Int
    let appleHealthMoodUUID: UUID?
    let loadScore: LoadScore?

    func dominantColor(for colorScheme: ColorScheme) -> Color {
        Color.severityColor(for: Double(severityLevel), colorScheme: colorScheme)
    }

    @MainActor
    static func make(for date: Date, entries: [SymptomEntry], activities: [ActivityEvent] = [], previousLoad: Double = 0.0) -> DaySummary? {
        guard !entries.isEmpty || !activities.isEmpty else { return nil }
        let entryCount = entries.count
        let uniqueSymptoms = Set(entries.compactMap { $0.symptomType?.id }).count

        // Calculate raw average (for display)
        let rawAverageSeverity = entries.isEmpty ? 0.0 : entries.reduce(0.0) { total, entry in
            return total + Double(entry.severity)
        } / Double(entryCount)

        // Calculate normalized average (for calculations)
        let averageSeverity = entries.isEmpty ? 0.0 : entries.reduce(0.0) { total, entry in
            return total + entry.normalisedSeverity
        } / Double(entryCount)

        let severityLevel = entries.isEmpty ? 0 : max(1, min(5, Int(round(averageSeverity))))

        // Use new LoadCalculator with activities only (no meals/sleep for this legacy method)
        let contributors: [LoadContributor] = activities as [LoadContributor]
        let loadScore = LoadCalculator.shared.calculate(
            for: date,
            contributors: contributors,
            symptoms: entries,
            previousLoad: previousLoad
        )

        return DaySummary(
            date: date,
            entryCount: entryCount,
            uniqueSymptoms: uniqueSymptoms,
            averageSeverity: averageSeverity,
            rawAverageSeverity: rawAverageSeverity,
            severityLevel: severityLevel,
            appleHealthMoodUUID: nil,
            loadScore: loadScore
        )
    }

    static func makeWithLoadScore(for date: Date, entries: [SymptomEntry], loadScore: LoadScore?) -> DaySummary? {
        guard !entries.isEmpty || loadScore != nil else { return nil }
        let entryCount = entries.count
        let uniqueSymptoms = Set(entries.compactMap { $0.symptomType?.id }).count

        // Calculate raw average (for display)
        let rawAverageSeverity = entries.isEmpty ? 0.0 : entries.reduce(0.0) { total, entry in
            return total + Double(entry.severity)
        } / Double(entryCount)

        // Calculate normalized average (for calculations)
        let averageSeverity = entries.isEmpty ? 0.0 : entries.reduce(0.0) { total, entry in
            return total + entry.normalisedSeverity
        } / Double(entryCount)

        let severityLevel = entries.isEmpty ? 0 : max(1, min(5, Int(round(averageSeverity))))

        return DaySummary(
            date: date,
            entryCount: entryCount,
            uniqueSymptoms: uniqueSymptoms,
            averageSeverity: averageSeverity,
            rawAverageSeverity: rawAverageSeverity,
            severityLevel: severityLevel,
            appleHealthMoodUUID: nil,
            loadScore: loadScore
        )
    }
}
