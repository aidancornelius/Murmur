//
//  PhysiologicalState.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
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
        case .relaxed: return "Relaxed"
        case .elevated: return "Elevated"
        case .fatigued: return "Fatigued"
        case .recovered: return "Recovered"
        case .active: return "Active"
        case .menstrual: return "Menstrual"
        case .preMenstrual: return "Pre-menstrual"
        case .ovulation: return "Ovulation"
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
    /// - Returns: The computed state, or nil if insufficient data
    static func compute(
        hrv: Double?,
        restingHR: Double?,
        sleepHours: Double?,
        workoutMinutes: Double?,
        cycleDay: Int?,
        flowLevel: String?
    ) -> PhysiologicalState? {
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

        // HRV assessment
        if let hrv = hrv {
            if hrv > 50 {
                relaxedScore += 2
                recoveredScore += 1
            } else if hrv >= 30 {
                relaxedScore += 1
            } else {
                elevatedScore += 2
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
        if let workout = workoutMinutes {
            if workout > 30 {
                activeScore += 2
                recoveredScore += 1
            } else if workout > 0 {
                activeScore += 1
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
