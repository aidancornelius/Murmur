import SwiftUI
import CoreData

// MARK: - Accessibility Rotor Support for Timeline
struct AccessibilityRotorModifier: ViewModifier {
    let daySummaries: [DaySummary]
    let recentEntries: [SymptomEntry]

    func body(content: Content) -> some View {
        content
            .accessibilityRotor("High severity days") {
                ForEach(highSeverityDays) { summary in
                    AccessibilityRotorEntry(rotorLabel(for: summary), id: summary.id)
                }
            }
            .accessibilityRotor("Recent entries") {
                ForEach(recentEntries) { entry in
                    AccessibilityRotorEntry(entryLabel(for: entry), id: entry.id ?? UUID())
                }
            }
    }

    private var highSeverityDays: [DaySummary] {
        daySummaries.filter { summary in
            summary.averageSeverity >= 4.0
        }
    }

    private func rotorLabel(for summary: DaySummary) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: summary.date)

        let severityText = SeverityScale.descriptor(for: Int(summary.averageSeverity)).lowercased()
        return "\(dateString): \(severityText) severity, \(summary.entryCount) entries"
    }

    private func entryLabel(for entry: SymptomEntry) -> String {
        let symptom = entry.symptomType?.name ?? "Unknown"
        let severity = SeverityScale.descriptor(for: Int(entry.severity))
        return "\(symptom): \(severity)"
    }
}

extension View {
    func timelineAccessibilityRotor(daySummaries: [DaySummary], recentEntries: [SymptomEntry]) -> some View {
        modifier(AccessibilityRotorModifier(daySummaries: daySummaries, recentEntries: recentEntries))
    }
}
