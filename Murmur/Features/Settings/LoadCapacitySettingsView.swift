//
//  LoadCapacitySettingsView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import SwiftUI

// MARK: - Risk Level Color Extension
extension LoadScore.RiskLevel {
    /// Static, high-contrast colors for each risk level so the UI is consistent across themes
    var displayColor: Color {
        switch self {
        case .safe:
            return Color(red: 0.12, green: 0.63, blue: 0.38) // Emerald
        case .caution:
            return Color(red: 0.98, green: 0.77, blue: 0.18) // Amber
        case .high:
            return Color(red: 0.96, green: 0.55, blue: 0.15) // Orange
        case .critical:
            return Color(red: 0.86, green: 0.20, blue: 0.28) // Crimson
        }
    }

    func color(from _: ColorPalette) -> Color {
        displayColor
    }
}

struct LoadCapacitySettingsView: View {
    @StateObject private var loadManager = LoadCapacityManager.shared
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCustomSettings = false
    @State private var showingCalibration = false

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        List {
            Section {
                Text("Adjust how Murmur calculates your activity load based on your condition and recovery patterns. The load bar helps you pace activities and avoid crashes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(palette.backgroundColor)
            }

            // Current Status Section
            Section {
                CurrentLoadStatusView()
                    .listRowBackground(palette.surfaceColor)
            } header: {
                Text("Your current thresholds")
            }

            // Condition Presets Section
            Section {
                ForEach(LoadCapacityManager.ConditionPreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    PresetCard(
                        preset: preset,
                        isSelected: loadManager.selectedPreset == preset,
                        palette: palette
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            loadManager.selectedPreset = preset
                        }
                    }
                    .listRowBackground(palette.surfaceColor)
                    .listRowSeparator(.hidden)
                }
            } header: {
                Text("Condition presets")
            } footer: {
                Text("Select a condition for tailored load thresholds and recovery settings")
            }

            // Custom Settings Section
            Section {
                Button {
                    if loadManager.selectedPreset == .custom {
                        showingCustomSettings = true
                    } else {
                        loadManager.selectedPreset = .custom
                        showingCustomSettings = true
                    }
                } label: {
                    HStack {
                        Image(systemName: LoadCapacityManager.ConditionPreset.custom.icon)
                            .font(.title2)
                            .foregroundStyle(loadManager.selectedPreset == .custom ? palette.accentColor : .secondary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Custom settings")
                                .font(.headline)
                                .foregroundStyle(loadManager.selectedPreset == .custom ? palette.accentColor : .primary)

                            if loadManager.selectedPreset == .custom {
                                Text("\(loadManager.capacity.displayName), \(loadManager.sensitivity.displayName) sensitivity, \(loadManager.recoveryWindow.displayName) recovery")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Fine-tune all parameters manually")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if loadManager.selectedPreset == .custom {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(palette.accentColor)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 0) 
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(loadManager.selectedPreset == .custom ? palette.accentColor.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(loadManager.selectedPreset == .custom ? palette.accentColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(palette.surfaceColor)
                .listRowSeparator(.hidden)
            }

            // Personal Baseline Section
            Section {
                if let baseline = loadManager.baseline, baseline.isCalibrated {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Baseline calibrated", systemImage: "checkmark.seal.fill")
                                .font(.subheadline)
                                .foregroundStyle(palette.accentColor)
                            Text("Based on \(baseline.sampleCount) good days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Reset") {
                            loadManager.resetBaseline()
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                } else if loadManager.isCalibrating {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Calibration in progress", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.subheadline)
                            .foregroundStyle(palette.accentColor)
                        Text("Mark good days to establish your baseline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Cancel calibration") {
                            loadManager.cancelCalibration()
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                } else {
                    Button {
                        showingCalibration = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Calibrate personal baseline", systemImage: "person.crop.circle.badge.plus")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text("Track your good days to personalise thresholds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Personal baseline")
            } footer: {
                Text("Calibration adjusts thresholds based on your typical good day load levels")
            }
            .listRowBackground(palette.surfaceColor)
        }
        .navigationTitle("Load capacity")
        .navigationBarTitleDisplayMode(.large)
        .themedScrollBackground()
        .sheet(isPresented: $showingCustomSettings) {
            CustomSettingsSheet()
        }
        .sheet(isPresented: $showingCalibration) {
            CalibrationSheet()
        }
    }
}

// MARK: - Preset Card

struct PresetCard: View {
    let preset: LoadCapacityManager.ConditionPreset
    let isSelected: Bool
    let palette: ColorPalette
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: preset.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? palette.accentColor : .secondary)
                        .frame(width: 32)

                    Text(preset.displayName)
                        .font(.headline)
                        .foregroundStyle(isSelected ? palette.accentColor : .primary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(palette.accentColor)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Description
                Text(preset.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Detailed settings
                if isSelected {
                    Text(preset.detailedDescription)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? palette.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? palette.accentColor : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Current Load Status View

struct CurrentLoadStatusView: View {
    @ObservedObject private var loadManager = LoadCapacityManager.shared
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Visual representation of thresholds
            HStack(spacing: 2) {
                ForEach(0..<100, id: \.self) { value in
                    Rectangle()
                        .fill(colorForValue(Double(value)))
                        .frame(maxWidth: .infinity, maxHeight: 40)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            // Threshold labels
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Safe", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(LoadScore.RiskLevel.safe.displayColor)
                    Text("< \(Int(loadManager.currentThresholds.safe))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Label("Caution", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(LoadScore.RiskLevel.caution.displayColor)
                    Text("\(Int(loadManager.currentThresholds.safe))-\(Int(loadManager.currentThresholds.caution))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Label("High", systemImage: "exclamationmark.2")
                        .font(.caption)
                        .foregroundStyle(LoadScore.RiskLevel.high.displayColor)
                    Text("\(Int(loadManager.currentThresholds.caution))-\(Int(loadManager.currentThresholds.high))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Label("Critical", systemImage: "bed.double.fill")
                        .font(.caption)
                        .foregroundStyle(LoadScore.RiskLevel.critical.displayColor)
                    Text("> \(Int(loadManager.currentThresholds.high))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Explainer text
            Text("This shows how your daily load score (0-100) maps to risk levels. Lower thresholds mean you'll get warnings earlier to help prevent crashes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)

            // Current settings summary
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(loadManager.selectedPreset.displayName, systemImage: loadManager.selectedPreset.icon)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.accentColor)

                    if loadManager.selectedPreset != .custom {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.accentColor)
                    }
                }

                HStack(spacing: 16) {
                    Label {
                        Text(loadManager.sensitivity.displayName)
                    } icon: {
                        Image(systemName: "waveform.path.ecg")
                    }
                    .font(.caption)

                    Label {
                        Text(loadManager.recoveryWindow.displayName)
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func colorForValue(_ value: Double) -> Color {
        let risk = loadManager.riskLevel(for: value)
        return risk.displayColor.opacity(0.3)
    }
}

// MARK: - Custom Settings Sheet

struct CustomSettingsSheet: View {
    @ObservedObject private var loadManager = LoadCapacityManager.shared
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            List {
                // Capacity Level
                Section {
                    Picker("Capacity level", selection: $loadManager.capacity) {
                        ForEach(LoadCapacityManager.CapacityLevel.allCases, id: \.self) { level in
                            Label {
                                VStack(alignment: .leading) {
                                    Text(level.displayName)
                                    Text(level.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: level.icon)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Activity capacity")
                } footer: {
                    Text("Sets the base thresholds for load calculations")
                }

                // Sensitivity Profile
                Section {
                    Picker("Sensitivity", selection: $loadManager.sensitivity) {
                        ForEach(LoadCapacityManager.SensitivityProfile.allCases, id: \.self) { profile in
                            Label {
                                VStack(alignment: .leading) {
                                    Text(profile.displayName)
                                    Text(profile.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: profile.icon)
                            }
                            .tag(profile)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Symptom sensitivity")
                } footer: {
                    Text("How much symptoms contribute to your load score")
                }

                // Recovery Window
                Section {
                    Picker("Recovery", selection: $loadManager.recoveryWindow) {
                        ForEach(LoadCapacityManager.RecoveryWindow.allCases, id: \.self) { window in
                            VStack(alignment: .leading) {
                                Text(window.displayName)
                                Text(window.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(window)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Recovery time")
                } footer: {
                    Text("How long activities impact your load")
                }
            }
            .navigationTitle("Custom settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Mark as custom when settings are manually configured
                        loadManager.selectedPreset = .custom
                        dismiss()
                    }
                }
            }
            .themedScrollBackground()
        }
    }
}

// MARK: - Calibration Sheet

struct CalibrationSheet: View {
    @ObservedObject private var loadManager = LoadCapacityManager.shared
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon and title
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundStyle(palette.accentColor)
                    .padding(.top, 40)

                VStack(spacing: 12) {
                    Text("Calibrate your baseline")
                        .font(.title2.weight(.semibold))

                    Text("Track at least 3 good days to establish your personal baseline. This helps adjust thresholds to match your unique patterns.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    Label {
                        Text("On days when you feel well, mark them as 'good days' in your timeline")
                    } icon: {
                        Image(systemName: "1.circle.fill")
                            .foregroundStyle(palette.accentColor)
                    }

                    Label {
                        Text("After 3 good days, your baseline will be established")
                    } icon: {
                        Image(systemName: "2.circle.fill")
                            .foregroundStyle(palette.accentColor)
                    }

                    Label {
                        Text("Thresholds will adjust based on your typical good day load")
                    } icon: {
                        Image(systemName: "3.circle.fill")
                            .foregroundStyle(palette.accentColor)
                    }
                }
                .padding(.horizontal)
                .font(.subheadline)

                Spacer()

                // Action button
                Button {
                    loadManager.startCalibration()
                    dismiss()
                } label: {
                    Text("Start calibration")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(palette.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Baseline calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .themedSurface()
        }
    }
}
