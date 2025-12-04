// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// HealthMetricBaselines.swift
// Created by Aidan Cornelius-Bell on 06/10/2025.
// Data structure for HealthKit metric baselines.
//
import Foundation

/// Manages personalised baseline values for health metrics
@MainActor
class HealthMetricBaselines: ObservableObject {
    static let shared = HealthMetricBaselines()

    // MARK: - Baseline Data

    struct Baseline: Codable {
        let mean: Double
        let standardDeviation: Double
        let sampleCount: Int
        let lastUpdated: Date

        var isCalibrated: Bool {
            sampleCount >= 10  // Need at least 10 samples for meaningful baseline
        }

        /// Calculate thresholds based on standard deviations
        func threshold(deviations: Double) -> Double {
            mean + (deviations * standardDeviation)
        }
    }

    // MARK: - Published Properties

    @Published var hrvBaseline: Baseline? {
        didSet {
            if let baseline = hrvBaseline {
                if let data = try? JSONEncoder().encode(baseline) {
                    UserDefaults.standard.set(data, forKey: UserDefaultsKeys.hrvBaseline)
                }
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hrvBaseline)
            }
        }
    }

    @Published var restingHRBaseline: Baseline? {
        didSet {
            if let baseline = restingHRBaseline {
                if let data = try? JSONEncoder().encode(baseline) {
                    UserDefaults.standard.set(data, forKey: UserDefaultsKeys.restingHRBaseline)
                }
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.restingHRBaseline)
            }
        }
    }

    // MARK: - Initialisation

    private init() {
        // Load HRV baseline
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.hrvBaseline),
           let baseline = try? JSONDecoder().decode(Baseline.self, from: data) {
            self.hrvBaseline = baseline
        }

        // Load resting HR baseline
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.restingHRBaseline),
           let baseline = try? JSONDecoder().decode(Baseline.self, from: data) {
            self.restingHRBaseline = baseline
        }
    }

    // MARK: - Update Methods

    /// Update baseline from array of samples
    func updateHRVBaseline(from samples: [Double]) {
        guard samples.count >= 10 else { return }
        hrvBaseline = calculateBaseline(from: samples)
    }

    /// Update resting HR baseline from array of samples
    func updateRestingHRBaseline(from samples: [Double]) {
        guard samples.count >= 10 else { return }
        restingHRBaseline = calculateBaseline(from: samples)
    }

    /// Calculate baseline statistics from samples
    private func calculateBaseline(from samples: [Double]) -> Baseline {
        let mean = samples.reduce(0, +) / Double(samples.count)

        let variance = samples.reduce(0.0) { result, value in
            let diff = value - mean
            return result + (diff * diff)
        } / Double(samples.count)

        let standardDeviation = sqrt(variance)

        return Baseline(
            mean: mean,
            standardDeviation: standardDeviation,
            sampleCount: samples.count,
            lastUpdated: DateUtility.now()
        )
    }

    // MARK: - Reset

    func resetAll() {
        hrvBaseline = nil
        restingHRBaseline = nil
    }

    // MARK: - Evaluation Helpers

    /// Evaluate HRV relative to baseline
    /// Returns: -1 (low), 0 (normal), 1 (high)
    func evaluateHRV(_ value: Double) -> Int {
        guard let baseline = hrvBaseline, baseline.isCalibrated else {
            // Fallback to fixed thresholds if no baseline
            if value > 50 { return 1 }
            if value < 30 { return -1 }
            return 0
        }

        // High HRV = good (above mean + 0.5 SD)
        if value > baseline.threshold(deviations: 0.5) {
            return 1
        }
        // Low HRV = stressed (below mean - 0.5 SD)
        else if value < baseline.threshold(deviations: -0.5) {
            return -1
        }
        return 0
    }

    /// Evaluate resting HR relative to baseline
    /// Returns: -1 (low), 0 (normal), 1 (high/elevated)
    func evaluateRestingHR(_ value: Double) -> Int {
        guard let baseline = restingHRBaseline, baseline.isCalibrated else {
            // Fallback to general thresholds if no baseline
            if value > 75 { return 1 }
            if value < 55 { return -1 }
            return 0
        }

        // High resting HR = stressed/fatigued (above mean + 0.5 SD)
        if value > baseline.threshold(deviations: 0.5) {
            return 1
        }
        // Low resting HR = good recovery (below mean - 0.5 SD)
        else if value < baseline.threshold(deviations: -0.5) {
            return -1
        }
        return 0
    }
}
