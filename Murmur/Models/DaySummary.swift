import SwiftUI

struct DaySummary: Hashable, Identifiable {
    var id: Date { date }

    let date: Date
    let entryCount: Int
    let uniqueSymptoms: Int
    let averageSeverity: Double
    let severityLevel: Int
    let appleHealthMoodUUID: UUID?
    let loadScore: LoadScore?

    var dominantColor: Color {
        Color.severityColor(for: Double(severityLevel))
    }

    static func make(for date: Date, entries: [SymptomEntry], activities: [ActivityEvent] = [], previousLoad: Double = 0.0) -> DaySummary? {
        guard !entries.isEmpty || !activities.isEmpty else { return nil }
        let entryCount = entries.count
        let uniqueSymptoms = Set(entries.compactMap { $0.symptomType?.id }).count
        let averageSeverity = entries.isEmpty ? 0.0 : entries.reduce(0.0) { $0 + Double($1.severity) } / Double(entryCount)
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
            severityLevel: severityLevel,
            appleHealthMoodUUID: nil,
            loadScore: loadScore
        )
    }

    static func makeWithLoadScore(for date: Date, entries: [SymptomEntry], loadScore: LoadScore?) -> DaySummary? {
        guard !entries.isEmpty || loadScore != nil else { return nil }
        let entryCount = entries.count
        let uniqueSymptoms = Set(entries.compactMap { $0.symptomType?.id }).count
        let averageSeverity = entries.isEmpty ? 0.0 : entries.reduce(0.0) { $0 + Double($1.severity) } / Double(entryCount)
        let severityLevel = entries.isEmpty ? 0 : max(1, min(5, Int(round(averageSeverity))))

        return DaySummary(
            date: date,
            entryCount: entryCount,
            uniqueSymptoms: uniqueSymptoms,
            averageSeverity: averageSeverity,
            severityLevel: severityLevel,
            appleHealthMoodUUID: nil,
            loadScore: loadScore
        )
    }
}
