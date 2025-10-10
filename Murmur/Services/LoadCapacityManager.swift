//
//  LoadCapacityManager.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import Foundation
import SwiftUI

/// Manages user's load capacity settings and adaptability preferences
@MainActor
class LoadCapacityManager: ObservableObject {
    static let shared = LoadCapacityManager()

    // MARK: - Condition Presets

    enum ConditionPreset: String, CaseIterable {
        case standard = "standard"
        case mecfs = "mecfs"
        case fibromyalgia = "fibromyalgia"
        case pcos = "pcos"
        case ptsd = "ptsd"
        case longCovid = "longcovid"
        case autoimmune = "autoimmune"
        case custom = "custom"

        var displayName: String {
            switch self {
            case .standard: return "Standard"
            case .mecfs: return "ME/CFS"
            case .fibromyalgia: return "Fibromyalgia"
            case .pcos: return "PCOS"
            case .ptsd: return "PTSD"
            case .longCovid: return "Long COVID"
            case .autoimmune: return "Autoimmune conditions"
            case .custom: return "Custom settings"
            }
        }

        var description: String {
            switch self {
            case .standard:
                return "Default settings for general symptom tracking"
            case .mecfs:
                return "Post-exertional malaise aware, extended recovery"
            case .fibromyalgia:
                return "Pain sensitivity focus, moderate recovery"
            case .pcos:
                return "Hormone cycle aware, standard recovery"
            case .ptsd:
                return "Stress-sensitive, quick-moderate recovery"
            case .longCovid:
                return "Fatigue focus, extended recovery periods"
            case .autoimmune:
                return "Flare-aware, variable recovery"
            case .custom:
                return "Manually configure all settings"
            }
        }

        var detailedDescription: String {
            switch self {
            case .standard:
                return "Balanced thresholds: Safe < 25, Caution 25-50, High 50-75. Activities decay 30% daily. Standard symptom impact."
            case .mecfs:
                return "Conservative thresholds: Safe < 20, Caution 20-40, High 40-60. Very slow recovery (60% load carries over). Symptoms amplified 1.5x to catch crashes early."
            case .fibromyalgia:
                return "Low thresholds: Safe < 20, Caution 20-40, High 40-60. Moderate recovery (45% carries over). Pain amplified 1.5x in calculations."
            case .pcos:
                return "Standard thresholds: Safe < 25, Caution 25-50, High 50-75. Normal 24hr recovery. Tracks hormonal patterns without amplification."
            case .ptsd:
                return "Moderate thresholds: Safe < 25, Caution 25-50, High 50-75. 48hr recovery window. Stress responses amplified 1.5x."
            case .longCovid:
                return "Very conservative: Safe < 20, Caution 20-40, High 40-60. Slowest recovery (60% carries). Fatigue symptoms weighted heavily."
            case .autoimmune:
                return "Conservative thresholds: Safe < 20, Caution 20-40, High 40-60. 48hr recovery. Standard symptom weighting for variable flares."
            case .custom:
                return "Fine-tune capacity levels, symptom sensitivity, and recovery windows to match your unique patterns."
            }
        }

        var icon: String {
            switch self {
            case .standard: return "heart"
            case .mecfs: return "battery.25"
            case .fibromyalgia: return "waveform.path.ecg"
            case .pcos: return "leaf"
            case .ptsd: return "brain.head.profile"
            case .longCovid: return "lungs"
            case .autoimmune: return "shield.lefthalf.filled"
            case .custom: return "slider.horizontal.3"
            }
        }

        var capacity: CapacityLevel {
            switch self {
            case .standard: return .medium
            case .mecfs: return .low
            case .fibromyalgia: return .low
            case .pcos: return .medium
            case .ptsd: return .medium
            case .longCovid: return .low
            case .autoimmune: return .low
            case .custom: return .medium // Default for custom
            }
        }

        var sensitivity: SensitivityProfile {
            switch self {
            case .standard: return .standard
            case .mecfs: return .sensitive
            case .fibromyalgia: return .sensitive
            case .pcos: return .standard
            case .ptsd: return .sensitive
            case .longCovid: return .sensitive
            case .autoimmune: return .standard
            case .custom: return .standard // Default for custom
            }
        }

        var recoveryWindow: RecoveryWindow {
            switch self {
            case .standard: return .standard
            case .mecfs: return .extended
            case .fibromyalgia: return .moderate
            case .pcos: return .standard
            case .ptsd: return .moderate
            case .longCovid: return .extended
            case .autoimmune: return .moderate
            case .custom: return .standard // Default for custom
            }
        }
    }

    // MARK: - Capacity Level

    enum CapacityLevel: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"

        var displayName: String {
            switch self {
            case .low: return "Low capacity"
            case .medium: return "Medium capacity"
            case .high: return "High capacity"
            }
        }

        var description: String {
            switch self {
            case .low:
                return "More conservative thresholds, earlier warnings"
            case .medium:
                return "Balanced thresholds for typical activity levels"
            case .high:
                return "Higher thresholds for active lifestyles"
            }
        }

        var icon: String {
            switch self {
            case .low: return "battery.25"
            case .medium: return "battery.50"
            case .high: return "battery.75"
            }
        }

        /// Risk thresholds for each capacity level
        var thresholds: LoadThresholds {
            switch self {
            case .low:
                return LoadThresholds(safe: 20, caution: 40, high: 60, critical: 60)
            case .medium:
                return LoadThresholds(safe: 25, caution: 50, high: 75, critical: 75)
            case .high:
                return LoadThresholds(safe: 30, caution: 60, high: 80, critical: 80)
            }
        }
    }

    // MARK: - Sensitivity Profile

    enum SensitivityProfile: String, CaseIterable, Codable {
        case sensitive = "sensitive"
        case standard = "standard"
        case resilient = "resilient"

        var displayName: String {
            switch self {
            case .sensitive: return "Sensitive"
            case .standard: return "Standard"
            case .resilient: return "Resilient"
            }
        }

        var description: String {
            switch self {
            case .sensitive:
                return "Symptoms have greater impact on load"
            case .standard:
                return "Typical symptom impact calculation"
            case .resilient:
                return "Reduced symptom impact on load"
            }
        }

        var icon: String {
            switch self {
            case .sensitive: return "exclamationmark.triangle"
            case .standard: return "checkmark.circle"
            case .resilient: return "shield"
            }
        }

        /// Multiplier for symptom severity contribution
        var symptomMultiplier: Double {
            switch self {
            case .sensitive: return 1.5
            case .standard: return 1.0
            case .resilient: return 0.7
            }
        }
    }

    // MARK: - Recovery Window

    enum RecoveryWindow: String, CaseIterable, Codable {
        case quick = "12h"
        case standard = "24h"
        case moderate = "48h"
        case extended = "72h"

        var displayName: String {
            switch self {
            case .quick: return "12 hours"
            case .standard: return "24 hours"
            case .moderate: return "48 hours"
            case .extended: return "72 hours"
            }
        }

        var description: String {
            switch self {
            case .quick:
                return "Quick recovery, recent activities matter less"
            case .standard:
                return "Standard recovery period"
            case .moderate:
                return "Slower recovery, activities linger"
            case .extended:
                return "Extended recovery, long-lasting impact"
            }
        }

        /// Decay rate for previous load (lower = slower recovery)
        var decayRate: Double {
            switch self {
            case .quick: return 0.85    // Faster decay
            case .standard: return 0.7   // Normal decay
            case .moderate: return 0.55  // Slower decay
            case .extended: return 0.4   // Much slower decay
            }
        }

        /// Number of hours for recovery window
        var hours: Int {
            switch self {
            case .quick: return 12
            case .standard: return 24
            case .moderate: return 48
            case .extended: return 72
            }
        }
    }

    // MARK: - Baseline State

    struct PersonalBaseline: Codable {
        let establishedDate: Date
        let averageGoodDayLoad: Double
        let sampleCount: Int

        var isCalibrated: Bool {
            sampleCount >= 3
        }
    }

    // MARK: - Published Properties

    private var isApplyingPreset = false

    @Published var selectedPreset: ConditionPreset {
        didSet {
            UserDefaults.standard.set(selectedPreset.rawValue, forKey: UserDefaultsKeys.conditionPreset)
            // Apply preset values if not custom
            if selectedPreset != .custom {
                isApplyingPreset = true
                capacity = selectedPreset.capacity
                sensitivity = selectedPreset.sensitivity
                recoveryWindow = selectedPreset.recoveryWindow
                isApplyingPreset = false
            }
        }
    }

    @Published var capacity: CapacityLevel {
        didSet {
            UserDefaults.standard.set(capacity.rawValue, forKey: UserDefaultsKeys.loadCapacity)
            // Only switch to custom if not applying a preset
            if !isApplyingPreset {
                checkForCustomSettings()
            }
        }
    }

    @Published var sensitivity: SensitivityProfile {
        didSet {
            UserDefaults.standard.set(sensitivity.rawValue, forKey: UserDefaultsKeys.sensitivityProfile)
            // Only switch to custom if not applying a preset
            if !isApplyingPreset {
                checkForCustomSettings()
            }
        }
    }

    @Published var recoveryWindow: RecoveryWindow {
        didSet {
            UserDefaults.standard.set(recoveryWindow.rawValue, forKey: UserDefaultsKeys.recoveryWindow)
            // Only switch to custom if not applying a preset
            if !isApplyingPreset {
                checkForCustomSettings()
            }
        }
    }

    @Published var baseline: PersonalBaseline? {
        didSet {
            if let baseline = baseline {
                if let data = try? JSONEncoder().encode(baseline) {
                    UserDefaults.standard.set(data, forKey: UserDefaultsKeys.personalBaseline)
                }
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.personalBaseline)
            }
        }
    }

    @Published var isCalibrating: Bool = false
    @Published var calibrationDays: [Double] = []

    // MARK: - Initialization

    private init() {
        // Load preset
        let savedPreset = UserDefaults.standard.string(forKey: UserDefaultsKeys.conditionPreset) ?? "standard"
        self.selectedPreset = ConditionPreset(rawValue: savedPreset) ?? .standard

        // Load capacity
        let savedCapacity = UserDefaults.standard.string(forKey: UserDefaultsKeys.loadCapacity) ?? "medium"
        self.capacity = CapacityLevel(rawValue: savedCapacity) ?? .medium

        // Load sensitivity
        let savedSensitivity = UserDefaults.standard.string(forKey: UserDefaultsKeys.sensitivityProfile) ?? "standard"
        self.sensitivity = SensitivityProfile(rawValue: savedSensitivity) ?? .standard

        // Load recovery window
        let savedRecovery = UserDefaults.standard.string(forKey: UserDefaultsKeys.recoveryWindow) ?? "24h"
        self.recoveryWindow = RecoveryWindow(rawValue: savedRecovery) ?? .standard

        // Load baseline
        if let baselineData = UserDefaults.standard.data(forKey: UserDefaultsKeys.personalBaseline),
           let savedBaseline = try? JSONDecoder().decode(PersonalBaseline.self, from: baselineData) {
            self.baseline = savedBaseline
        }
    }

    // Check if current settings match a preset
    private func checkForCustomSettings() {
        // Don't check during initialization
        guard selectedPreset != .custom else { return }

        // Check if current settings match the selected preset
        if capacity != selectedPreset.capacity ||
           sensitivity != selectedPreset.sensitivity ||
           recoveryWindow != selectedPreset.recoveryWindow {
            selectedPreset = .custom
        }
    }

    // MARK: - Computed Properties

    /// Current load thresholds based on capacity, adjusted for personal baseline
    var currentThresholds: LoadThresholds {
        let base = capacity.thresholds
        let adjustment = baselineAdjustment

        return LoadThresholds(
            safe: base.safe * adjustment,
            caution: base.caution * adjustment,
            high: base.high * adjustment,
            critical: base.critical * adjustment
        )
    }

    /// Combined configuration for load calculations
    var configuration: LoadConfiguration {
        LoadConfiguration(
            thresholds: currentThresholds,
            symptomMultiplier: sensitivity.symptomMultiplier,
            decayRate: recoveryWindow.decayRate
        )
    }

    /// Baseline adjustment factor (0.8 - 1.2 based on personal baseline)
    private var baselineAdjustment: Double {
        guard let baseline = baseline, baseline.isCalibrated else {
            return 1.0
        }
        // Adjust thresholds based on personal baseline
        // If baseline is lower than average, reduce thresholds
        // If baseline is higher, increase thresholds slightly
        let standardBaseline = 30.0 // Assumed standard good day load
        let ratio = baseline.averageGoodDayLoad / standardBaseline
        return max(0.8, min(1.2, ratio))
    }

    // MARK: - Calibration Methods

    func startCalibration() {
        isCalibrating = true
        calibrationDays = []
    }

    func recordGoodDay(load: Double) {
        guard isCalibrating else { return }
        calibrationDays.append(load)

        if calibrationDays.count >= 3 {
            completeCalibration()
        }
    }

    func cancelCalibration() {
        isCalibrating = false
        calibrationDays = []
    }

    private func completeCalibration() {
        guard !calibrationDays.isEmpty else { return }

        let average = calibrationDays.reduce(0, +) / Double(calibrationDays.count)
        baseline = PersonalBaseline(
            establishedDate: Date(),
            averageGoodDayLoad: average,
            sampleCount: calibrationDays.count
        )
        isCalibrating = false
        calibrationDays = []
    }

    func resetBaseline() {
        baseline = nil
        isCalibrating = false
        calibrationDays = []
    }

    // MARK: - Helper Methods

    /// Determine risk level based on load value and current configuration
    func riskLevel(for load: Double) -> LoadScore.RiskLevel {
        let thresholds = currentThresholds

        if load < thresholds.safe {
            return .safe
        } else if load < thresholds.caution {
            return .caution
        } else if load < thresholds.high {
            return .high
        } else {
            return .critical
        }
    }
}

// MARK: - Supporting Types

struct LoadThresholds {
    let safe: Double
    let caution: Double
    let high: Double
    let critical: Double
}

struct LoadConfiguration: Hashable {
    let thresholds: LoadThresholds
    let symptomMultiplier: Double
    let decayRate: Double
}

extension LoadThresholds: Hashable {}