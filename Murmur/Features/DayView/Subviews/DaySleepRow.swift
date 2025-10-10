//
//  DaySleepRow.swift
//  Murmur
//
//  Extracted from DayDetailView.swift on 10/10/2025.
//

import SwiftUI

/// A row displaying a sleep event with quality, duration, and health metrics
struct DaySleepRow: View {
    let sleep: SleepEvent

    private var hasHealthMetrics: Bool {
        sleep.hkSleepHours != nil || sleep.hkHRV != nil || sleep.hkRestingHR != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Sleep", systemImage: "moon.stars.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.indigo)
                Spacer()
            }
            HStack(spacing: 12) {
                if let bedTime = sleep.bedTime {
                    Text(DateFormatters.shortTime.string(from: bedTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let duration = sleepDuration {
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(sleep.quality)/5")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if hasHealthMetrics {
                HStack(spacing: 12) {
                    if let sleepHours = sleep.hkSleepHours?.doubleValue {
                        Text(String(format: "%.1fh sleep", sleepHours))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let hrv = sleep.hkHRV?.doubleValue {
                        Text(String(format: "%.0f ms HRV", hrv))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let rhr = sleep.hkRestingHR?.doubleValue {
                        Text(String(format: "%.0f bpm", rhr))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let symptoms = sleep.symptoms as? Set<SymptomType>, !symptoms.isEmpty {
                let symptomNames = symptoms.compactMap { $0.name }.sorted()
                Text("Symptoms: \(symptomNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let note = sleep.note, !note.isEmpty {
                Text(note)
                    .font(.callout)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Swipe left to delete this sleep event")
    }

    private var sleepDuration: String? {
        guard let bedTime = sleep.bedTime, let wakeTime = sleep.wakeTime else { return nil }
        let hours = wakeTime.timeIntervalSince(bedTime) / 3600
        return String(format: "%.1fh", hours)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if let bedTime = sleep.bedTime {
            parts.append("Sleep at \(DateFormatters.shortTime.string(from: bedTime))")
        } else {
            parts.append("Sleep")
        }
        if let duration = sleepDuration {
            parts.append("Duration: \(duration)")
        }
        parts.append("Quality: \(sleep.quality) out of 5")
        if let sleepHours = sleep.hkSleepHours?.doubleValue {
            parts.append(String(format: "%.1f hours sleep", sleepHours))
        }
        if let hrv = sleep.hkHRV?.doubleValue {
            parts.append(String(format: "HRV %.0f milliseconds", hrv))
        }
        if let rhr = sleep.hkRestingHR?.doubleValue {
            parts.append(String(format: "Resting heart rate %.0f beats per minute", rhr))
        }
        if let symptoms = sleep.symptoms as? Set<SymptomType>, !symptoms.isEmpty {
            let symptomNames = symptoms.compactMap { $0.name }.sorted()
            parts.append("Symptoms: \(symptomNames.joined(separator: ", "))")
        }
        if let note = sleep.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }
        return parts.joined(separator: ". ")
    }
}
