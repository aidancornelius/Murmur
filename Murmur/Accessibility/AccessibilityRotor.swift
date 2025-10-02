import SwiftUI

// MARK: - Accessibility Rotor Support
extension TimelineView {
    func withAccessibilityRotor() -> some View {
        self.accessibilityRotor("High severity days", entries: highSeverityDays) { section in
            AccessibilityRotorEntry(section.date.description, id: section.id) {
                // This will scroll to the section
                NavigationLink(destination: DayDetailView(date: section.date)) {
                    EmptyView()
                }
            }
        }
    }

    private var highSeverityDays: [DaySection] {
        grouped.filter { section in
            guard let summary = section.summary else { return false }
            return summary.averageSeverity >= 4.0
        }
    }
}

// MARK: - Rotor Extension for Main View
struct AccessibilityRotorModifier: ViewModifier {
    let sections: [DaySection]

    func body(content: Content) -> some View {
        content
            .accessibilityRotor("High severity days") {
                ForEach(highSeverityDays) { section in
                    AccessibilityRotorEntry(rotorLabel(for: section), id: section.id)
                }
            }
            .accessibilityRotor("Recent entries") {
                ForEach(recentEntries) { entry in
                    AccessibilityRotorEntry(entryLabel(for: entry), id: entry.id ?? UUID())
                }
            }
    }

    private var highSeverityDays: [DaySection] {
        sections.filter { section in
            guard let summary = section.summary else { return false }
            return summary.averageSeverity >= 4.0
        }
    }

    private var recentEntries: [SymptomEntry] {
        sections.prefix(7)
            .flatMap { $0.entries }
            .prefix(20)
            .map { $0 }
    }

    private func rotorLabel(for section: DaySection) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: section.date)

        guard let summary = section.summary else {
            return dateString
        }

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
    func timelineAccessibilityRotor(sections: [DaySection]) -> some View {
        modifier(AccessibilityRotorModifier(sections: sections))
    }
}
