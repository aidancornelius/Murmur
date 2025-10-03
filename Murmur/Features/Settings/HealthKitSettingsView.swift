import HealthKit
import SwiftUI

struct HealthKitSettingsView: View {
    @EnvironmentObject private var healthKit: HealthKitAssistant
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var errorMessage: String?
    @State private var isRefreshing = false

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
}
