import SwiftUI

// MARK: - Severity Accessibility
extension SeverityScale {
    /// Provides semantic, human-friendly descriptions for VoiceOver
    static func accessibilityLabel(for value: Int) -> String {
        switch max(1, min(5, value)) {
        case 1: return "Level 1: Stable, minimal impact"
        case 2: return "Level 2: Manageable, mild discomfort"
        case 3: return "Level 3: Challenging, moderate impact"
        case 4: return "Level 4: Severe, significant difficulty"
        default: return "Level 5: Crisis, immediate attention needed"
        }
    }

    static func accessibilityValue(for value: Double) -> String {
        let rounded = Int(round(value))
        return accessibilityLabel(for: rounded)
    }
}

// MARK: - View Modifiers
extension View {
    /// Applies comprehensive accessibility labels for symptom entries
    func symptomEntryAccessibility(
        symptomName: String,
        severity: Int,
        time: String,
        note: String? = nil,
        physiologicalState: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(generateLabel(
                symptomName: symptomName,
                severity: severity,
                time: time,
                note: note,
                physiologicalState: physiologicalState
            ))
            .accessibilityHint("Double tap to view details")
    }

    private func generateLabel(
        symptomName: String,
        severity: Int,
        time: String,
        note: String?,
        physiologicalState: String?
    ) -> String {
        var parts: [String] = []

        // Symptom and time
        parts.append("\(symptomName) at \(time)")

        // Severity with semantic description
        parts.append(SeverityScale.accessibilityLabel(for: severity))

        // Physiological state if available
        if let state = physiologicalState {
            parts.append(state)
        }

        // Note if available
        if let note = note, !note.isEmpty {
            parts.append("Note: \(note)")
        }

        return parts.joined(separator: ". ")
    }

    /// Applies accessibility for severity slider
    func severitySliderAccessibility(value: Double) -> some View {
        self
            .accessibilityValue(SeverityScale.accessibilityValue(for: value))
            .accessibilityAdjustableAction { direction in
                // This will be handled by the slider binding
            }
    }

    /// Applies accessibility for day summaries
    func daySummaryAccessibility(
        date: Date,
        averageSeverity: Double,
        entryCount: Int
    ) -> some View {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none

        let dateString = dateFormatter.string(from: date)
        let severityDescription = SeverityScale.accessibilityValue(for: averageSeverity)

        let label = "\(dateString). \(entryCount) \(entryCount == 1 ? "entry" : "entries"). Average: \(severityDescription)"

        return self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint("Double tap to view all entries for this day")
    }
}

// MARK: - Accessibility Identifiers
enum AccessibilityIdentifiers {
    // Main screens
    static let timeline = "timeline_screen"
    static let addEntry = "add_entry_screen"
    static let dayDetail = "day_detail_screen"
    static let settings = "settings_screen"

    // Actions
    static let addEntryButton = "add_entry_button"
    static let saveButton = "save_entry_button"
    static let cancelButton = "cancel_button"

    // Inputs
    static let symptomPicker = "symptom_picker"
    static let severitySlider = "severity_slider"
    static let noteField = "note_field"
    static let dateTimePicker = "date_time_picker"

    // Lists
    static let entryList = "entry_list"
    static let symptomTypeList = "symptom_type_list"
}
