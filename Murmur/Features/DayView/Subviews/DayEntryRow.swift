//
//  DayEntryRow.swift
//  Murmur
//
//  Extracted from DayDetailView.swift on 10/10/2025.
//

import CoreLocation
import SwiftUI

/// A row displaying a symptom entry with severity, physiological state, and location
struct DayEntryRow: View {
    let entry: SymptomEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(entry.symptomType?.name ?? "Unnamed", systemImage: entry.symptomType?.iconName ?? "circle")
                    .labelStyle(.titleAndIcon)
                Spacer()
                SeverityBadge(value: Double(entry.severity), precision: .integer, isPositive: entry.symptomType?.isPositive ?? false)
            }
            HStack(spacing: 12) {
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let state = physiologicalState {
                    HStack(spacing: 4) {
                        Image(systemName: state.iconName)
                        Text(state.displayText)
                    }
                    .font(.caption2)
                    .foregroundStyle(state.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(state.color.opacity(0.15), in: Capsule())
                }
                if let cycleDay = entry.hkCycleDay?.intValue {
                    Text("Cycle day \(cycleDay)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
            }
            Text(SeverityScale.descriptor(for: Int(entry.severity), isPositive: entry.symptomType?.isPositive ?? false))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(.callout)
            }
            if let location = entry.locationPlacemark, !LocationAssistant.formatted(placemark: location).isEmpty {
                Label(LocationAssistant.formatted(placemark: location), systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Swipe left to delete this entry")
    }

    private var timeLabel: String {
        let reference = entry.backdatedAt ?? entry.createdAt ?? Date()
        return DateFormatters.shortTime.string(from: reference)
    }

    private var physiologicalState: PhysiologicalState? {
        PhysiologicalState.compute(
            hrv: entry.hkHRV?.doubleValue,
            restingHR: entry.hkRestingHR?.doubleValue,
            sleepHours: entry.hkSleepHours?.doubleValue,
            workoutMinutes: entry.hkWorkoutMinutes?.doubleValue,
            cycleDay: entry.hkCycleDay?.intValue,
            flowLevel: entry.hkFlowLevel
        )
    }

    private var accessibilityDescription: String {
        var parts: [String] = []

        parts.append("\(entry.symptomType?.name ?? "Unnamed") at \(timeLabel)")

        let severityDesc = SeverityScale.descriptor(for: Int(entry.severity), isPositive: entry.symptomType?.isPositive ?? false)
        parts.append("Level \(entry.severity): \(severityDesc)")

        if let state = physiologicalState {
            parts.append(state.displayText)
        }

        if let cycleDay = entry.hkCycleDay?.intValue {
            parts.append("Cycle day \(cycleDay)")
        }

        if let note = entry.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }

        if let location = entry.locationPlacemark {
            let formatted = LocationAssistant.formatted(placemark: location)
            if !formatted.isEmpty {
                parts.append("Location: \(formatted)")
            }
        }

        return parts.joined(separator: ". ")
    }
}
