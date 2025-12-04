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
final class LoadCalculator {

    // MARK: - Configuration

    /// Consistent lookback period for load score calculations (in days)
    /// This ensures all views calculate load scores with the same historical data
    static let lookbackDays: Int = 60

    // MARK: - Singleton

    static let shared = LoadCalculator()
    private init() {}

    // MARK: - Main Calculation Method

    /// Calculate load score for a given day based on all contributors and symptoms
    /// - Parameters:
    ///   - date: The date to calculate load for
    ///   - contributors: Array of load contributors (activities, meals, sleep)
    ///   - symptoms: Symptom entries for the day
    ///   - previousLoad: The decayed load from the previous day (should be effective load, i.e. felt load if available)
    ///   - reflectionMultiplier: Optional multiplier from user's day reflection (0.5-2.0)
    ///   - configuration: Optional configuration override (uses LoadCapacityManager if nil)
    /// - Returns: LoadScore for the day
    func calculate(
        for date: Date,
        contributors: [LoadContributor],
        symptoms: [SymptomEntry],
        previousLoad: Double,
        reflectionMultiplier: Double? = nil,
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
            riskLevel: risk,
            reflectionMultiplier: reflectionMultiplier
        )
    }

    // MARK: - Range Calculation

    /// Calculate load scores for a range of days
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    ///   - contributorsByDate: Dictionary of load contributors grouped by day
    ///   - symptomsByDate: Dictionary of symptoms grouped by day
    ///   - reflectionsByDate: Dictionary of reflection multipliers grouped by day
    ///   - configuration: Optional configuration override
    /// - Returns: Array of LoadScores, one per day
    func calculateRange(
        from startDate: Date,
        to endDate: Date,
        contributorsByDate: [Date: [LoadContributor]],
        symptomsByDate: [Date: [SymptomEntry]],
        reflectionsByDate: [Date: Double] = [:],
        configuration: LoadConfiguration? = nil
    ) -> [LoadScore] {
        var scores: [LoadScore] = []
        var previousEffectiveLoad: Double = 0.0

        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let contributors = contributorsByDate[dayStart] ?? []
            let symptoms = symptomsByDate[dayStart] ?? []
            let reflectionMultiplier = reflectionsByDate[dayStart]

            let score = calculate(
                for: dayStart,
                contributors: contributors,
                symptoms: symptoms,
                previousLoad: previousEffectiveLoad,
                reflectionMultiplier: reflectionMultiplier,
                configuration: configuration
            )

            scores.append(score)
            // Use effective load (felt load if available) for the decay chain
            // This ensures user's reflection affects subsequent days
            previousEffectiveLoad = score.effectiveLoad

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return scores
    }

    // MARK: - Legacy Compatibility Methods

    /// Calculate using separate arrays (for backward compatibility)
    func calculate(
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
        // High symptoms = slower recovery (more load retained, so higher modifier on remaining load)
        // Formula: as severity increases, we want to retain more load
        // Severity 0: modifier ~1.0 (normal decay)
        // Severity 5: modifier ~1.8 (retain more load, slower recovery)
        let symptomModifier = 1.0 + (avgSeverity * 0.16)

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
    func groupContributorsByDate(
        _ contributors: [LoadContributor]
    ) -> [Date: [LoadContributor]] {
        let calendar = Calendar.current
        return Dictionary(grouping: contributors) { contributor in
            calendar.startOfDay(for: contributor.effectiveDate)
        }
    }

    /// Group reflection multipliers by date for range calculations
    func groupReflectionsByDate(
        _ reflections: [DayReflection]
    ) -> [Date: Double] {
        let calendar = Calendar.current
        var result: [Date: Double] = [:]
        for reflection in reflections {
            guard let date = reflection.date,
                  let multiplier = reflection.loadMultiplierValue else { continue }
            let dayStart = calendar.startOfDay(for: date)
            result[dayStart] = multiplier
        }
        return result
    }

    /// Analyse load contribution breakdown for a day
    func analyseContributions(
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
struct LoadBreakdown {
    let activityLoad: Double
    let mealLoad: Double
    let sleepLoad: Double
    let symptomLoad: Double
    let totalLoad: Double

    var activityPercentage: Double {
        totalLoad > 0 ? (activityLoad / totalLoad) * 100 : 0
    }

    var mealPercentage: Double {
        totalLoad > 0 ? (mealLoad / totalLoad) * 100 : 0
    }

    var sleepPercentage: Double {
        totalLoad > 0 ? (sleepLoad / totalLoad) * 100 : 0
    }

    var symptomPercentage: Double {
        totalLoad > 0 ? (symptomLoad / totalLoad) * 100 : 0
    }
}

// MARK: - Centralized Data Fetching

extension LoadCalculator {
    /// Calculate load score for a specific date by fetching all necessary data
    /// Uses consistent lookback period for all event types
    /// - Parameters:
    ///   - targetDate: The date to calculate load for
    ///   - context: Core Data managed object context
    /// - Returns: LoadScore for the target date, or nil if no data exists
    func calculateWithFetch(
        for targetDate: Date,
        context: NSManagedObjectContext
    ) throws -> LoadScore? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: targetDate)

        // Use consistent lookback period for all event types
        guard let lookbackStart = calendar.date(byAdding: .day, value: -Self.lookbackDays, to: dayStart) else {
            return nil
        }

        // Fetch all data with same lookback period
        let allEntries = try fetchEntries(since: lookbackStart, context: context)
        let allActivities = try fetchActivities(since: lookbackStart, context: context)
        let allMeals = try fetchMeals(since: lookbackStart, context: context)
        let allSleep = try fetchSleep(since: lookbackStart, context: context)
        let allReflections = try fetchReflections(since: lookbackStart, context: context)

        guard !allEntries.isEmpty || !allActivities.isEmpty || !allMeals.isEmpty || !allSleep.isEmpty else {
            return nil
        }

        // Group symptoms by date
        let groupedEntries = groupSymptomsByDate(allEntries, calendar: calendar)

        // Combine all contributors and group by date
        var allContributors: [LoadContributor] = []
        allContributors.append(contentsOf: allActivities as [LoadContributor])
        allContributors.append(contentsOf: allMeals as [LoadContributor])
        allContributors.append(contentsOf: allSleep as [LoadContributor])
        let groupedContributors = groupContributorsByDate(allContributors)

        // Group reflection multipliers by date
        let reflectionsByDate = groupReflectionMultipliersByDate(allReflections, calendar: calendar)

        // Get all unique dates to process
        let allDates = Set(groupedEntries.keys).union(Set(groupedContributors.keys)).sorted()
        guard let firstDate = allDates.first else { return nil }

        // Calculate load scores using the range calculator
        let loadScores = calculateRange(
            from: firstDate,
            to: dayStart,
            contributorsByDate: groupedContributors,
            symptomsByDate: groupedEntries,
            reflectionsByDate: reflectionsByDate
        )

        return loadScores.first { $0.date == dayStart }
    }

    // MARK: - Private Fetch Methods

    private func fetchEntries(since date: Date, context: NSManagedObjectContext) throws -> [SymptomEntry] {
        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            date as NSDate,
            date as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: true),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: true)
        ]
        request.relationshipKeyPathsForPrefetching = ["symptomType"]
        return try context.fetch(request)
    }

    private func fetchActivities(since date: Date, context: NSManagedObjectContext) throws -> [ActivityEvent] {
        let request = ActivityEvent.fetchRequest()
        request.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            date as NSDate,
            date as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ActivityEvent.backdatedAt, ascending: true),
            NSSortDescriptor(keyPath: \ActivityEvent.createdAt, ascending: true)
        ]
        return try context.fetch(request)
    }

    private func fetchMeals(since date: Date, context: NSManagedObjectContext) throws -> [MealEvent] {
        let request = MealEvent.fetchRequest()
        request.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            date as NSDate,
            date as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \MealEvent.backdatedAt, ascending: true),
            NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: true)
        ]
        return try context.fetch(request)
    }

    private func fetchSleep(since date: Date, context: NSManagedObjectContext) throws -> [SleepEvent] {
        let request = SleepEvent.fetchRequest()
        request.predicate = NSPredicate(
            format: "(backdatedAt >= %@ OR (backdatedAt == nil AND createdAt >= %@))",
            date as NSDate,
            date as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SleepEvent.backdatedAt, ascending: true),
            NSSortDescriptor(keyPath: \SleepEvent.createdAt, ascending: true)
        ]
        return try context.fetch(request)
    }

    private func groupSymptomsByDate(_ symptoms: [SymptomEntry], calendar: Calendar = Calendar.current) -> [Date: [SymptomEntry]] {
        Dictionary(grouping: symptoms) { entry in
            calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? DateUtility.now())
        }
    }

    private func fetchReflections(since date: Date, context: NSManagedObjectContext) throws -> [DayReflection] {
        let request = DayReflection.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@", date as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DayReflection.date, ascending: true)]
        return try context.fetch(request)
    }

    private func groupReflectionMultipliersByDate(_ reflections: [DayReflection], calendar: Calendar = Calendar.current) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for reflection in reflections {
            guard let date = reflection.date,
                  let multiplier = reflection.loadMultiplierValue else { continue }
            let dayStart = calendar.startOfDay(for: date)
            result[dayStart] = multiplier
        }
        return result
    }
}