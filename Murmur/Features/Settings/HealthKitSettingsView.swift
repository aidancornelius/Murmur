//
//  HealthKitSettingsView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import HealthKit
import SwiftUI

struct HealthKitSettingsView: View {
    @EnvironmentObject private var healthKit: HealthKitAssistant
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var baselines = HealthMetricBaselines.shared
    @State private var errorMessage: String?
    @State private var isRefreshing = false
    @State private var isRecalibrating = false

    private var hasAnyData: Bool {
        healthKit.latestHRV != nil ||
        healthKit.latestRestingHR != nil ||
        healthKit.latestSleepHours != nil ||
        healthKit.latestWorkoutMinutes != nil ||
        healthKit.latestCycleDay != nil ||
        healthKit.latestFlowLevel != nil
    }

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        Form {
            Section {
                Text("Health data can enrich your tracking by linking to physiological signs. You will need a device which works with Health, for instance Apple Watch, to use this feature.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            Section {
                Button(action: requestAccess) {
                    if isRefreshing {
                        ProgressView()
                    } else if hasAnyData {
                        Label("Refresh health data", systemImage: "arrow.clockwise")
                    } else {
                        Label("Grant access", systemImage: "heart.text.square")
                    }
                }
                .disabled(!healthKit.isHealthDataAvailable || isRefreshing)
            } footer: {
                if !healthKit.isHealthDataAvailable {
                    Text("HealthKit is not available on this device.")
                } else if hasAnyData {
                    Text("Health access is working. Tap to refresh your latest data.")
                } else {
                    Text("If you see data below, Health access is working. Apple's privacy design prevents apps from checking read permissions directly.")
                }
            }
            .listRowBackground(palette.surfaceColor)

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .listRowBackground(palette.surfaceColor)
            }

            Section {
                if let hrvBaseline = baselines.hrvBaseline {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("HRV baseline", systemImage: "waveform.path.ecg")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if hrvBaseline.isCalibrated {
                                Label("Calibrated", systemImage: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(palette.accentColor)
                            }
                        }

                        HStack {
                            Text("Mean")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f ms", hrvBaseline.mean))
                                .font(.caption)
                        }

                        HStack {
                            Text("Normal range")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f–%.1f ms",
                                      hrvBaseline.threshold(deviations: -0.5),
                                      hrvBaseline.threshold(deviations: 0.5)))
                                .font(.caption)
                        }

                        HStack {
                            Text("Samples")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(hrvBaseline.sampleCount)")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Label("HRV baseline", systemImage: "waveform.path.ecg")
                        Spacer()
                        Text("Not calibrated")
                            .foregroundStyle(.secondary)
                    }
                }

                if let hrBaseline = baselines.restingHRBaseline {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Resting HR baseline", systemImage: "heart.fill")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            if hrBaseline.isCalibrated {
                                Label("Calibrated", systemImage: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(palette.accentColor)
                            }
                        }

                        HStack {
                            Text("Mean")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f bpm", hrBaseline.mean))
                                .font(.caption)
                        }

                        HStack {
                            Text("Normal range")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f–%.1f bpm",
                                      hrBaseline.threshold(deviations: -0.5),
                                      hrBaseline.threshold(deviations: 0.5)))
                                .font(.caption)
                        }

                        HStack {
                            Text("Samples")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(hrBaseline.sampleCount)")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Label("Resting HR baseline", systemImage: "heart.fill")
                        Spacer()
                        Text("Not calibrated")
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: recalibrateBaselines) {
                    if isRecalibrating {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Recalibrating...")
                        }
                    } else {
                        Label("Recalculate baselines", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRecalibrating || !healthKit.isHealthDataAvailable)
            } header: {
                Text("Personalised baselines")
            } footer: {
                Text("Baselines are calculated from 30 days of health data and used to personalise physiological state indicators. Recalibrate if your fitness or health patterns have changed significantly.")
            }
            .listRowBackground(palette.surfaceColor)

            Section {
                HStack {
                    Label("HRV", systemImage: "waveform.path.ecg")
                    Spacer()
                    if let hrv = healthKit.latestHRV {
                        Text(String(format: "%.0f ms", hrv))
                    } else {
                        Text("–")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Label("Resting heart rate", systemImage: "heart.fill")
                    Spacer()
                    if let hr = healthKit.latestRestingHR {
                        Text(String(format: "%.0f bpm", hr))
                    } else {
                        Text("–")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Label("Sleep", systemImage: "bed.double.fill")
                    Spacer()
                    if let sleep = healthKit.latestSleepHours {
                        Text(String(format: "%.1f hr", sleep))
                    } else {
                        Text("–")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Label("Workout", systemImage: "figure.run")
                    Spacer()
                    if let workout = healthKit.latestWorkoutMinutes {
                        Text(String(format: "%.0f min", workout))
                    } else {
                        Text("–")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Label("Cycle day", systemImage: "calendar")
                    Spacer()
                    if let cycleDay = healthKit.latestCycleDay {
                        Text("Day \(cycleDay)")
                    } else {
                        Text("–")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Label("Flow level", systemImage: "drop.fill")
                    Spacer()
                    if let flowLevel = healthKit.latestFlowLevel {
                        Text(flowLevel.capitalized)
                    } else {
                        Text("–")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Your recent health data")
            } footer: {
                Text("These show whether Health access is working. If nothing appears, try requesting access again.")
            }
            .listRowBackground(palette.surfaceColor)
        }
        .navigationTitle("Connect to Health")
        .themedScrollBackground()
        .task {
            await healthKit.refreshContext()
        }
    }

    private func requestAccess() {
        Task {
            isRefreshing = true
            defer { isRefreshing = false }
            do {
                try await healthKit.requestPermissions()
                await healthKit.refreshContext()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func recalibrateBaselines() {
        Task {
            isRecalibrating = true
            defer { isRecalibrating = false }
            await healthKit.updateBaselines()
        }
    }
}
