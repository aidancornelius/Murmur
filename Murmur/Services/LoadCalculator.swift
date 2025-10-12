//
//  LoadCalculator.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/12/2025.
//

import Foundation
import CoreData

/// Modern load calculation service using protocol-based contributors
/// Replaces the legacy LoadScore.calculate methods with a more flexible approach
@MainActor
public final class LoadCalculator {

    // MARK: - Singleton

    public static let shared = LoadCalculator()
    private init() {}

    // MARK: - Main Calculation Method

    /// Calculate load score for a given day based on all contributors and symptoms
    /// - Parameters:
    ///   - date: The date to calculate load for
    ///   - contributors: Array of load contributors (activities, meals, sleep)
    ///   - symptoms: Symptom entries for the day
    ///   - previousLoad: The decayed load from the previous day
    ///   - configuration: Optional configuration override (uses LoadCapacityManager if nil)
    /// - Returns: LoadScore for the day
    public func calculate(
        for date: Date,
        contributors: [LoadContributor],
        symptoms: [SymptomEntry],
        previousLoad: Double,
        configuration: LoadConfiguration? = nil
    ) -> LoadScore {
        // Get configuration from LoadCapacityManager or use provided override
        let config = configuration ?? LoadCapacityManager.shared.configuration

        // Separate contributors by type for processing
        let exertionEvents = contributors.compactMap { $0 as? ExertionEvent }
        let recoveryModifiers = contributors.compactMap { $0 as? RecoveryModifier }

        // Calculate raw load from exertion events (activities and meals)
        let exertionLoad = exertionEvents.reduce(0.0) { total, event in
            total + event.loadContribution
        }

        // Add any direct load from recovery events (e.g., very poor sleep)
        let recoveryLoad = recoveryModifiers.reduce(0.0) { total, modifier in
            total + modifier.loadContribution
        }

        // Calculate symptom contribution (unchanged from original)
        let (symptomLoad, symptomModifier) = calculateSymptomImpact(
            symptoms: symptoms,
            config: config
        )

        // Calculate combined recovery modifier from all sources
        let combinedRecoveryModifier = calculateCombinedRecoveryModifier(
            recoveryModifiers: recoveryModifiers,
            symptomModifier: symptomModifier
        )

        // Apply decay to previous load with combined modifiers
        let baseDecayRate = config.decayRate
        let decayedPreviousLoad = previousLoad * baseDecayRate * combinedRecoveryModifier

        // Total raw load for today (before decay)
        let todayRawLoad = exertionLoad + recoveryLoad + symptomLoad

        // Total load including decayed previous load, capped at 100
        let totalLoad = min(todayRawLoad + decayedPreviousLoad, 100.0)

        // Determine risk level using configuration thresholds
        let risk = determineRiskLevel(load: totalLoad, thresholds: config.thresholds)

        return LoadScore(
            date: date,
            rawLoad: min(todayRawLoad, 100.0),
            decayedLoad: totalLoad,
            riskLevel: risk
        )
    }

    // MARK: - Range Calculation

    /// Calculate load scores for a range of days
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    ///   - contributorsByDate: Dictionary of load contributors grouped by day
    ///   - symptomsByDate: Dictionary of symptoms grouped by day
    ///   - configuration: Optional configuration override
    /// - Returns: Array of LoadScores, one per day
    public func calculateRange(
        from startDate: Date,
        to endDate: Date,
        contributorsByDate: [Date: [LoadContributor]],
        symptomsByDate: [Date: [SymptomEntry]],
        configuration: LoadConfiguration? = nil
    ) -> [LoadScore] {
        var scores: [LoadScore] = []
        var previousLoad: Double = 0.0

        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let contributors = contributorsByDate[dayStart] ?? []
            let symptoms = symptomsByDate[dayStart] ?? []

            let score = calculate(
                for: dayStart,
                contributors: contributors,
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

    // MARK: - Legacy Compatibility Methods

    /// Calculate using separate arrays (for backward compatibility)
    public func calculate(
        for date: Date,
        activities: [ActivityEvent],
        meals: [MealEvent],
        sleep: [SleepEvent],
        symptoms: [SymptomEntry],
        previousLoad: Double,
        configuration: LoadConfiguration? = nil
    ) -> LoadScore {
        // Combine all contributors
        var contributors: [LoadContributor] = []
        contributors.append(contentsOf: activities as [LoadContributor])
        contributors.append(contentsOf: meals as [LoadContributor])
        contributors.append(contentsOf: sleep as [LoadContributor])

        return calculate(
            for: date,
            contributors: contributors,
            symptoms: symptoms,
            previousLoad: previousLoad,
            configuration: configuration
        )
    }

    // MARK: - Private Helper Methods

    /// Calculate symptom impact on load and recovery
    private func calculateSymptomImpact(
        symptoms: [SymptomEntry],
        config: LoadConfiguration
    ) -> (load: Double, modifier: Double) {
        guard !symptoms.isEmpty else {
            return (load: 0.0, modifier: 1.0)
        }

        // Calculate normalized average severity
        let avgSeverity = symptoms.reduce(0.0) { total, entry in
            total + entry.normalisedSeverity
        } / Double(symptoms.count)

        // Calculate symptom load (high severity symptoms add load)
        // Severity 4-5 adds load (indicating ongoing physiological stress)
        let baseSymptomLoad = max(0, (avgSeverity - 3.0) * 10.0)
        let symptomLoad = baseSymptomLoad * config.symptomMultiplier

        // Calculate symptom severity modifier (affects decay rate)
        // High symptoms = slower recovery (lower decay)
        let symptomModifier = max(0.4, 1.2 - (avgSeverity * 0.16))

        return (load: symptomLoad, modifier: symptomModifier)
    }

    /// Combine recovery modifiers from multiple sources
    private func calculateCombinedRecoveryModifier(
        recoveryModifiers: [RecoveryModifier],
        symptomModifier: Double
    ) -> Double {
        // Start with symptom modifier
        var combinedModifier = symptomModifier

        // Apply recovery modifiers (multiplicative for compounding effects)
        for modifier in recoveryModifiers {
            if let recoveryImpact = modifier.recoveryModifier {
                combinedModifier *= recoveryImpact
            }
        }

        // Clamp to reasonable range (0.2 to 2.0)
        return min(2.0, max(0.2, combinedModifier))
    }

    /// Determine risk level based on load value
    private func determineRiskLevel(
        load: Double,
        thresholds: LoadThresholds
    ) -> LoadScore.RiskLevel {
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

// MARK: - Convenience Methods

extension LoadCalculator {
    /// Group contributors by date for range calculations
    public func groupContributorsByDate(
        _ contributors: [LoadContributor]
    ) -> [Date: [LoadContributor]] {
        let calendar = Calendar.current
        return Dictionary(grouping: contributors) { contributor in
            calendar.startOfDay(for: contributor.effectiveDate)
        }
    }

    /// Analyse load contribution breakdown for a day
    public func analyseContributions(
        contributors: [LoadContributor],
        symptoms: [SymptomEntry],
        config: LoadConfiguration? = nil
    ) -> LoadBreakdown {
        let configuration = config ?? LoadCapacityManager.shared.configuration

        let activities = contributors.compactMap { $0 as? ActivityEvent }
        let meals = contributors.compactMap { $0 as? MealEvent }
        let sleep = contributors.compactMap { $0 as? SleepEvent }

        let activityLoad = activities.reduce(0.0) { $0 + $1.loadContribution }
        let mealLoad = meals.reduce(0.0) { $0 + $1.loadContribution }
        let sleepLoad = sleep.reduce(0.0) { $0 + $1.loadContribution }

        let (symptomLoad, _) = calculateSymptomImpact(
            symptoms: symptoms,
            config: configuration
        )

        return LoadBreakdown(
            activityLoad: activityLoad,
            mealLoad: mealLoad,
            sleepLoad: sleepLoad,
            symptomLoad: symptomLoad,
            totalLoad: activityLoad + mealLoad + sleepLoad + symptomLoad
        )
    }
}

// MARK: - Supporting Types

/// Breakdown of load contributions by type
public struct LoadBreakdown {
    public let activityLoad: Double
    public let mealLoad: Double
    public let sleepLoad: Double
    public let symptomLoad: Double
    public let totalLoad: Double

    public var activityPercentage: Double {
        totalLoad > 0 ? (activityLoad / totalLoad) * 100 : 0
    }

    public var mealPercentage: Double {
        totalLoad > 0 ? (mealLoad / totalLoad) * 100 : 0
    }

    public var sleepPercentage: Double {
        totalLoad > 0 ? (sleepLoad / totalLoad) * 100 : 0
    }

    public var symptomPercentage: Double {
        totalLoad > 0 ? (symptomLoad / totalLoad) * 100 : 0
    }
}