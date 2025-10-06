//
//  AccessibilityExtensions.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI

// MARK: - Severity Accessibility
extension SeverityScale {
    /// Provides semantic, human-friendly descriptions for VoiceOver
    static func accessibilityLabel(for value: Int, isPositive: Bool = false) -> String {
        let level = max(1, min(5, value))

        if isPositive {
            // For positive symptoms (higher is better)
            switch level {
            case 1: return "Level 1: Very low, minimal wellbeing"
            case 2: return "Level 2: Low, some wellbeing"
            case 3: return "Level 3: Moderate, decent wellbeing"
            case 4: return "Level 4: High, good wellbeing"
            default: return "Level 5: Very high, excellent wellbeing"
            }
        } else {
            // For negative symptoms (lower is better)
            switch level {
            case 1: return "Level 1: Stable, minimal impact"
            case 2: return "Level 2: Manageable, mild discomfort"
            case 3: return "Level 3: Challenging, moderate impact"
            case 4: return "Level 4: Severe, significant difficulty"
            default: return "Level 5: Crisis, immediate attention needed"
            }
        }
    }

    static func accessibilityValue(for value: Double, isPositive: Bool = false) -> String {
        let rounded = Int(round(value))
        return accessibilityLabel(for: rounded, isPositive: isPositive)
    }
}

// MARK: - View Modifiers
extension View {
    /// Applies comprehensive accessibility labels for symptom entries
    func symptomEntryAccessibility(
        symptomName: String,
        severity: Int,
        time: String,
        isPositive: Bool = false,
        note: String? = nil,
        physiologicalState: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(generateLabel(
                symptomName: symptomName,
                severity: severity,
                time: time,
                isPositive: isPositive,
                note: note,
                physiologicalState: physiologicalState
            ))
            .accessibilityHint("Double tap to view details")
    }

    private func generateLabel(
        symptomName: String,
        severity: Int,
        time: String,
        isPositive: Bool,
        note: String?,
        physiologicalState: String?
    ) -> String {
        var parts: [String] = []

        // Symptom and time
        parts.append("\(symptomName) at \(time)")

        // Severity with semantic description
        parts.append(SeverityScale.accessibilityLabel(for: severity, isPositive: isPositive))

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
    func severitySliderAccessibility(value: Double, isPositive: Bool = false) -> some View {
        self
            .accessibilityValue(SeverityScale.accessibilityValue(for: value, isPositive: isPositive))
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
