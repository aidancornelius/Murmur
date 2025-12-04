// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// PhysiologicalState.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Enum representing physiological states affecting load capacity.
//
import SwiftUI

enum PhysiologicalState: String {
    case relaxed
    case elevated
    case fatigued
    case recovered
    case active
    case menstrual
    case preMenstrual
    case ovulation

    var displayText: String {
        switch self {
        case .relaxed: return "Body: quiet signals"
        case .elevated: return "Body: higher tension"
        case .fatigued: return "Body: fatigue markers"
        case .recovered: return "Body: recovery pattern"
        case .active: return "Body: busy signals"
        case .menstrual: return "Cycle: menstrual"
        case .preMenstrual: return "Cycle: pre-menstrual"
        case .ovulation: return "Cycle: ovulation"
        }
    }

    var iconName: String {
        switch self {
        case .relaxed: return "wind"
        case .elevated: return "waveform.path.ecg"
        case .fatigued: return "bed.double"
        case .recovered: return "checkmark.circle"
        case .active: return "figure.run"
        case .menstrual: return "drop.fill"
        case .preMenstrual: return "moon.fill"
        case .ovulation: return "sun.max.fill"
        }
    }

    var color: Color {
        switch self {
        case .relaxed: return .green
        case .elevated: return .orange
        case .fatigued: return .orange
        case .recovered: return .blue
        case .active: return .purple
        case .menstrual: return .red
        case .preMenstrual: return .orange
        case .ovulation: return .cyan
        }
    }

    /// Compute physiological state from available health metrics
    /// - Parameters:
    ///   - hrv: Heart rate variability in milliseconds
    ///   - restingHR: Resting heart rate in bpm
    ///   - sleepHours: Sleep duration in hours
    ///   - workoutMinutes: Workout duration in minutes
    ///   - cycleDay: Day of menstrual cycle
    ///   - flowLevel: Menstrual flow level
    ///   - baselines: Optional personalised baselines (defaults to shared instance)
    /// - Returns: The computed state, or nil if insufficient data
    @MainActor
    static func compute(
        hrv: Double?,
        restingHR: Double?,
        sleepHours: Double?,
        workoutMinutes: Double?,
        cycleDay: Int?,
        flowLevel: String?,
        baselines: HealthMetricBaselines? = nil
    ) -> PhysiologicalState? {
        let baselineManager = baselines ?? HealthMetricBaselines.shared

        // Cycle phase is weighted heavily if present
        if let cycleDay = cycleDay {
            if cycleDay >= 1 && cycleDay <= 5 {
                return .menstrual
            } else if cycleDay >= 12 && cycleDay <= 16 {
                return .ovulation
            } else if cycleDay >= 24 && cycleDay <= 28 {
                return .preMenstrual
            }
        }

        // Also check flow level directly (in case cycle day calculation is off)
        if let flowLevel = flowLevel, !flowLevel.isEmpty {
            return .menstrual
        }

        // Score-based assessment for non-cycle states
        var relaxedScore = 0
        var elevatedScore = 0
        var fatiguedScore = 0
        var recoveredScore = 0
        var activeScore = 0

        // HRV assessment using personalised baselines
        if let hrv = hrv {
            let evaluation = baselineManager.evaluateHRV(hrv)
            switch evaluation {
            case 1:  // High HRV = good, relaxed
                relaxedScore += 2
                recoveredScore += 1
            case 0:  // Normal HRV
                relaxedScore += 1
            case -1: // Low HRV = stressed
                elevatedScore += 2
            default:
                break
            }
        }

        // Resting heart rate assessment using personalised baselines
        if let restingHR = restingHR {
            let evaluation = baselineManager.evaluateRestingHR(restingHR)
            switch evaluation {
            case -1:  // Low resting HR = good recovery
                recoveredScore += 2
                relaxedScore += 1
            case 0:   // Normal resting HR
                recoveredScore += 1
            case 1:   // High resting HR = stressed/fatigued
                elevatedScore += 1
                fatiguedScore += 1
            default:
                break
            }
        }

        // Sleep assessment
        if let sleep = sleepHours {
            if sleep < 6 {
                fatiguedScore += 2
            } else if sleep > 8 {
                recoveredScore += 2
                relaxedScore += 1
            } else {
                recoveredScore += 1
            }
        }

        // Workout assessment
        // Recent workout indicates active state, not recovered
        // (Previously incorrectly added to recoveredScore)
        if let workout = workoutMinutes {
            if workout > 30 {
                activeScore += 3
            } else if workout > 0 {
                activeScore += 2
            }
        }

        // Return state with highest score, or nil if no data
        let scores = [
            (PhysiologicalState.relaxed, relaxedScore),
            (PhysiologicalState.elevated, elevatedScore),
            (PhysiologicalState.fatigued, fatiguedScore),
            (PhysiologicalState.recovered, recoveredScore),
            (PhysiologicalState.active, activeScore)
        ]

        let maxScore = scores.max { $0.1 < $1.1 }
        guard let maxScore = maxScore, maxScore.1 > 0 else { return nil }

        return maxScore.0
    }
}
