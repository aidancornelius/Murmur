//
//  DaySummary.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
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

        let loadScore = LoadScore.calculate(
            for: date,
            activities: activities,
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
