// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DaySleepRow.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Row component displaying sleep data in day view.
//
import CoreData
import SwiftUI

/// A row displaying a sleep event with quality, duration, and health metrics
struct DaySleepRow: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var sleep: SleepEvent
    @State private var showingQualityPicker = false

    private var hasHealthMetrics: Bool {
        sleep.hkSleepHours != nil || sleep.hkHRV != nil || sleep.hkRestingHR != nil
    }

    /// Whether the quality is still the default (unrated by user)
    private var isUnrated: Bool {
        sleep.isImported && sleep.quality == 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Sleep", systemImage: "moon.stars.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.indigo)
                Spacer()
                if sleep.isImported {
                    Button {
                        openHealthApp()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                            Text("From Health")
                                .font(.caption2)
                        }
                        .foregroundStyle(.pink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.pink.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Imported from Health. Tap to open Health app.")
                }
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
                // Tappable quality rating for imported sleep
                if sleep.isImported {
                    Button {
                        showingQualityPicker = true
                    } label: {
                        HStack(spacing: 2) {
                            if isUnrated {
                                Text("Rate quality")
                                    .font(.caption)
                                    .foregroundStyle(.indigo)
                            } else {
                                Text("\(sleep.quality)/5")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("\(sleep.quality)/5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
        .accessibilityHint(sleep.isImported ? "Imported from Health. Tap to rate quality or tap badge to open Health app." : "Swipe left to delete this sleep event")
        .sheet(isPresented: $showingQualityPicker) {
            SleepQualityPicker(sleep: sleep, context: context)
                .presentationDetents([.height(280)])
        }
    }

    private var sleepDuration: String? {
        guard let bedTime = sleep.bedTime, let wakeTime = sleep.wakeTime else { return nil }
        let hours = wakeTime.timeIntervalSince(bedTime) / 3600
        return String(format: "%.1fh", hours)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if sleep.isImported {
            parts.append("Imported from Health")
        }
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

    /// Opens the Health app to the sleep data section
    private func openHealthApp() {
        // Deep link to Health app's sleep section
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Sleep Quality Picker

/// A sheet for rating imported sleep quality
private struct SleepQualityPicker: View {
    @ObservedObject var sleep: SleepEvent
    let context: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedQuality: Int

    init(sleep: SleepEvent, context: NSManagedObjectContext) {
        self.sleep = sleep
        self.context = context
        self._selectedQuality = State(initialValue: Int(sleep.quality))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Sleep info header
                if let bedTime = sleep.bedTime, let wakeTime = sleep.wakeTime {
                    VStack(spacing: 4) {
                        Text("Sleep on \(DateFormatters.shortDate.string(from: wakeTime))")
                            .font(.headline)
                        Text("\(DateFormatters.shortTime.string(from: bedTime)) – \(DateFormatters.shortTime.string(from: wakeTime))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Quality rating
                VStack(spacing: 12) {
                    Text("How did you feel after this sleep?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { rating in
                            Button {
                                selectedQuality = rating
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: rating <= selectedQuality ? "moon.fill" : "moon")
                                        .font(.title2)
                                        .foregroundStyle(rating <= selectedQuality ? .indigo : .secondary)
                                    Text("\(rating)")
                                        .font(.caption)
                                        .foregroundStyle(rating == selectedQuality ? .primary : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Rate \(rating) out of 5")
                        }
                    }

                    Text(qualityDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(height: 20)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Rate sleep quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveQuality()
                    }
                }
            }
        }
    }

    private var qualityDescription: String {
        switch selectedQuality {
        case 1: return "Very poor – woke up exhausted"
        case 2: return "Poor – didn't feel rested"
        case 3: return "Okay – average sleep"
        case 4: return "Good – felt refreshed"
        case 5: return "Excellent – best sleep"
        default: return ""
        }
    }

    private func saveQuality() {
        sleep.quality = Int16(selectedQuality)
        do {
            try context.save()
        } catch {
            // Silently fail - the UI will still show the old value
        }
        dismiss()
    }
}
