//
//  LoadScore.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import Foundation

/// Represents the accumulated activity load with symptom-aware decay
struct LoadScore: Hashable {
    let date: Date
    let rawLoad: Double
    let decayedLoad: Double
    let riskLevel: RiskLevel

    enum RiskLevel: Int, Comparable, Hashable {
        case safe = 0
        case caution = 1
        case high = 2
        case critical = 3

        var description: String {
            switch self {
            case .safe: return "Safe"
            case .caution: return "Caution"
            case .high: return "High risk"
            case .critical: return "Rest needed"
            }
        }

        static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Calculate load score for a given day based on activities and symptoms
    /// - Parameters:
    ///   - date: The date to calculate load for
    ///   - activities: Activities on this day
    ///   - symptoms: Symptom entries on this day
    ///   - previousLoad: The decayed load from the previous day
    ///   - configuration: Optional configuration override (uses LoadCapacityManager if nil)
    /// - Returns: LoadScore for the day
    static func calculate(
        for date: Date,
        activities: [ActivityEvent],
        symptoms: [SymptomEntry],
        previousLoad: Double,
        configuration: LoadConfiguration? = nil
    ) -> LoadScore {
        // Get configuration from LoadCapacityManager or use provided override
        let config = configuration ?? LoadCapacityManager.shared.configuration

        // Calculate raw load from today's activities
        // Scaled to fit 0-100 range: max exertion (5) × max duration weight (2) × multiplier (6) = 60
        // Allows room for symptom load and multiple activities while staying under 100
        let activityLoad = activities.reduce(0.0) { total, activity in
            let exertion = Double(activity.physicalExertion + activity.cognitiveExertion + activity.emotionalLoad) / 3.0
            let duration = activity.durationMinutes?.doubleValue ?? 60.0
            let durationWeight = min(duration / 60.0, 2.0) // Cap at 2 hours for weighting
            return total + (exertion * durationWeight * 6.0)
        }

        // Calculate normalized average severity (once)
        let avgSeverity: Double
        if !symptoms.isEmpty {
            avgSeverity = symptoms.reduce(0.0) { total, entry in
                return total + entry.normalisedSeverity
            } / Double(symptoms.count)
        } else {
            avgSeverity = 0.0
        }

        // Calculate symptom load (high severity symptoms add load)
        // Apply sensitivity multiplier from configuration
        // Severity 4-5 adds load (indicating ongoing physiological stress)
        // Scale: severity 1-3 → 0 load, severity 4 → 10 load, severity 5 → 20 load
        let baseSymptomLoad = max(0, (avgSeverity - 3.0) * 10.0)
        let symptomLoad = baseSymptomLoad * config.symptomMultiplier

        // Calculate symptom severity modifier (affects decay rate)
        // High symptoms = slower recovery (lower decay)
        // Scale: severity 1 → 1.0 (normal), severity 5 → 0.4 (very slow recovery)
        let symptomModifier = symptoms.isEmpty ? 1.0 : max(0.4, 1.2 - (avgSeverity * 0.16))

        // Use decay rate from configuration (based on recovery window)
        let baseDecayRate = config.decayRate

        // Apply symptom-modified decay to previous load
        let decayedPreviousLoad = previousLoad * baseDecayRate * symptomModifier

        // Total load = today's activities + symptom load + decayed load from previous days
        // Cap at 100 to keep scale between 1-100
        let totalLoad = min(activityLoad + symptomLoad + decayedPreviousLoad, 100.0)

        // Determine risk level using configuration thresholds
        let risk: RiskLevel
        let thresholds = config.thresholds
        if totalLoad < thresholds.safe {
            risk = .safe
        } else if totalLoad < thresholds.caution {
            risk = .caution
        } else if totalLoad < thresholds.high {
            risk = .high
        } else {
            risk = .critical
        }

        return LoadScore(
            date: date,
            rawLoad: min(activityLoad + symptomLoad, 100.0),
            decayedLoad: totalLoad,
            riskLevel: risk
        )
    }

    /// Calculate load scores for a range of days
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    ///   - activitiesByDate: Dictionary of activities grouped by day
    ///   - symptomsByDate: Dictionary of symptoms grouped by day
    ///   - configuration: Optional configuration override (uses LoadCapacityManager if nil)
    /// - Returns: Array of LoadScores, one per day
    static func calculateRange(
        from startDate: Date,
        to endDate: Date,
        activitiesByDate: [Date: [ActivityEvent]],
        symptomsByDate: [Date: [SymptomEntry]],
        configuration: LoadConfiguration? = nil
    ) -> [LoadScore] {
        var scores: [LoadScore] = []
        var previousLoad: Double = 0.0

        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let activities = activitiesByDate[dayStart] ?? []
            let symptoms = symptomsByDate[dayStart] ?? []

            let score = calculate(
                for: dayStart,
                activities: activities,
                symptoms: symptoms,
                previousLoad: previousLoad,
                configuration: configuration
            )

            scores.append(score)
            previousLoad = score.decayedLoad

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return scores
    }
}
