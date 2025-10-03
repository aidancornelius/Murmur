//
//  AnalysisModels.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import Foundation
import CoreData

// MARK: - Symptom trend analysis

struct SymptomTrend: Identifiable {
    let id = UUID()
    let symptomTypeName: String
    let symptomTypeColor: String
    let occurrences: Int
    let averageSeverity: Double
    let trend: TrendDirection
    let periodComparison: String
    let isPositive: Bool  // True if higher values are better

    enum TrendDirection {
        case increasing  // Getting better (could be less symptoms or more positive states)
        case stable
        case decreasing  // Getting worse (could be more symptoms or fewer positive states)
    }
}

// MARK: - Activity correlation analysis

struct ActivityCorrelation: Identifiable {
    let id = UUID()
    let activityName: String
    let symptomTypeName: String
    let symptomTypeColor: String
    let correlationStrength: Double // -1 to 1
    let occurrencesWithSymptom: Int
    let occurrencesWithoutSymptom: Int
    let averageSeverityAfterActivity: Double
    let averageSeverityWithoutActivity: Double
    let hoursWindow: Int // Time window for correlation
    let isPositive: Bool  // True if this is a positive symptom

    var correlationType: CorrelationType {
        if correlationStrength > 0.3 {
            return .positive
        } else if correlationStrength < -0.3 {
            return .negative
        } else {
            return .neutral
        }
    }

    enum CorrelationType {
        case positive  // Activity associated with worsening (higher negative symptoms or lower positive symptoms)
        case negative  // Activity associated with improving (lower negative symptoms or higher positive symptoms)
        case neutral   // No clear correlation
    }
}

// MARK: - Time pattern analysis

struct TimePattern: Identifiable {
    let id = UUID()
    let symptomTypeName: String
    let symptomTypeColor: String
    let peakHour: Int
    let peakDayOfWeek: Int?
    let occurrencesByHour: [Int: Int]
    let occurrencesByDayOfWeek: [Int: Int]
}

// MARK: - Physiological state correlation

struct PhysiologicalCorrelation: Identifiable {
    let id = UUID()
    let symptomTypeName: String
    let symptomTypeColor: String
    let metricName: String
    let averageWithHighSymptoms: Double?
    let averageWithLowSymptoms: Double?
    let correlationStrength: Double
    let isPositive: Bool  // True if this is a positive symptom
}

// MARK: - Analysis engine

class AnalysisEngine {

    // MARK: Symptom trends

    static func analyseSymptomTrends(
        in context: NSManagedObjectContext,
        days: Int = 30
    ) -> [SymptomTrend] {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now),
              let midPoint = calendar.date(byAdding: .day, value: -(days/2), to: now) else {
            return []
        }

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@) OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )

        guard let entries = try? context.fetch(request) else { return [] }

        // Group by symptom type
        let grouped = Dictionary(grouping: entries) { $0.symptomType }

        return grouped.compactMap { (type, entries) -> SymptomTrend? in
            guard let type = type, let name = type.name else { return nil }

            let firstHalf = entries.filter { entry in
                let date = entry.backdatedAt ?? entry.createdAt ?? Date()
                return date < midPoint
            }

            let secondHalf = entries.filter { entry in
                let date = entry.backdatedAt ?? entry.createdAt ?? Date()
                return date >= midPoint
            }

            let avgSeverity = entries.reduce(0.0) { $0 + Double($1.severity) } / Double(entries.count)

            let firstAvg = firstHalf.isEmpty ? 0 : firstHalf.reduce(0.0) { $0 + Double($1.severity) } / Double(firstHalf.count)
            let secondAvg = secondHalf.isEmpty ? 0 : secondHalf.reduce(0.0) { $0 + Double($1.severity) } / Double(secondHalf.count)

            let trend: SymptomTrend.TrendDirection
            let diff = secondAvg - firstAvg
            // For positive symptoms, higher values = improving; for negative symptoms, lower values = improving
            let isPositive = type.isPositive
            if diff > 0.5 {
                // Values went up: good for positive symptoms, bad for negative symptoms
                trend = isPositive ? .increasing : .decreasing
            } else if diff < -0.5 {
                // Values went down: bad for positive symptoms, good for negative symptoms
                trend = isPositive ? .decreasing : .increasing
            } else {
                trend = .stable
            }

            return SymptomTrend(
                symptomTypeName: name,
                symptomTypeColor: type.color ?? "gray",
                occurrences: entries.count,
                averageSeverity: avgSeverity,
                trend: trend,
                periodComparison: String(format: "%.1f → %.1f", firstAvg, secondAvg),
                isPositive: isPositive
            )
        }
        .sorted { $0.occurrences > $1.occurrences }
    }

    // MARK: Activity correlations

    static func analyseActivityCorrelations(
        in context: NSManagedObjectContext,
        days: Int = 30,
        hoursWindow: Int = 24
    ) -> [ActivityCorrelation] {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return []
        }

        // Fetch activities
        let activitiesRequest = ActivityEvent.fetchRequest()
        activitiesRequest.predicate = NSPredicate(
            format: "((backdatedAt >= %@) OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )

        // Fetch symptoms
        let symptomsRequest = SymptomEntry.fetchRequest()
        symptomsRequest.predicate = NSPredicate(
            format: "((backdatedAt >= %@) OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )

        guard let activities = try? context.fetch(activitiesRequest),
              let symptoms = try? context.fetch(symptomsRequest) else {
            return []
        }

        // Group activities by name
        let groupedActivities = Dictionary(grouping: activities) { $0.name ?? "Unnamed" }

        var correlations: [ActivityCorrelation] = []

        // For each unique activity
        for (activityName, activityInstances) in groupedActivities {
            // Group symptoms by type
            let symptomsByType = Dictionary(grouping: symptoms) { $0.symptomType }

            // For each symptom type
            for (type, typeSymptoms) in symptomsByType {
                guard let type = type, let symptomName = type.name else { continue }

                var symptomsAfterActivity = [SymptomEntry]()
                var symptomsWithoutActivity = [SymptomEntry]()

                // Check each symptom
                for symptom in typeSymptoms {
                    let symptomDate = symptom.backdatedAt ?? symptom.createdAt ?? Date()

                    // Check if any activity happened in the window before this symptom
                    let hasActivityBefore = activityInstances.contains { activity in
                        let activityDate = activity.backdatedAt ?? activity.createdAt ?? Date()
                        let timeDiff = symptomDate.timeIntervalSince(activityDate)
                        return timeDiff > 0 && timeDiff <= Double(hoursWindow * 3600)
                    }

                    if hasActivityBefore {
                        symptomsAfterActivity.append(symptom)
                    } else {
                        symptomsWithoutActivity.append(symptom)
                    }
                }

                // Calculate correlation
                guard !symptomsAfterActivity.isEmpty || !symptomsWithoutActivity.isEmpty else { continue }

                let avgWithActivity = symptomsAfterActivity.isEmpty ? 0.0 :
                    symptomsAfterActivity.reduce(0.0) { $0 + Double($1.severity) } / Double(symptomsAfterActivity.count)

                let avgWithoutActivity = symptomsWithoutActivity.isEmpty ? 0.0 :
                    symptomsWithoutActivity.reduce(0.0) { $0 + Double($1.severity) } / Double(symptomsWithoutActivity.count)

                // Simple correlation: normalized difference
                let maxSeverity = max(avgWithActivity, avgWithoutActivity, 1.0)
                var correlationStrength = (avgWithActivity - avgWithoutActivity) / maxSeverity

                // For positive symptoms, flip the correlation (higher is better)
                if type.isPositive {
                    correlationStrength = -correlationStrength
                }

                // Only include meaningful correlations
                if abs(correlationStrength) > 0.2 && symptomsAfterActivity.count >= 2 {
                    correlations.append(ActivityCorrelation(
                        activityName: activityName,
                        symptomTypeName: symptomName,
                        symptomTypeColor: type.color ?? "gray",
                        correlationStrength: correlationStrength,
                        occurrencesWithSymptom: symptomsAfterActivity.count,
                        occurrencesWithoutSymptom: symptomsWithoutActivity.count,
                        averageSeverityAfterActivity: avgWithActivity,
                        averageSeverityWithoutActivity: avgWithoutActivity,
                        hoursWindow: hoursWindow,
                        isPositive: type.isPositive
                    ))
                }
            }
        }

        return correlations.sorted { abs($0.correlationStrength) > abs($1.correlationStrength) }
    }

    // MARK: Time patterns

    static func analyseTimePatterns(
        in context: NSManagedObjectContext,
        days: Int = 30
    ) -> [TimePattern] {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return []
        }

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@) OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )

        guard let entries = try? context.fetch(request) else { return [] }

        // Group by symptom type
        let grouped = Dictionary(grouping: entries) { $0.symptomType }

        return grouped.compactMap { (type, entries) -> TimePattern? in
            guard let type = type, let name = type.name else { return nil }

            var hourCounts = [Int: Int]()
            var dayOfWeekCounts = [Int: Int]()

            for entry in entries {
                let date = entry.backdatedAt ?? entry.createdAt ?? Date()
                let hour = calendar.component(.hour, from: date)
                let dayOfWeek = calendar.component(.weekday, from: date)

                hourCounts[hour, default: 0] += 1
                dayOfWeekCounts[dayOfWeek, default: 0] += 1
            }

            let peakHour = hourCounts.max { $0.value < $1.value }?.key ?? 12
            let peakDay = dayOfWeekCounts.max { $0.value < $1.value }?.key

            return TimePattern(
                symptomTypeName: name,
                symptomTypeColor: type.color ?? "gray",
                peakHour: peakHour,
                peakDayOfWeek: peakDay,
                occurrencesByHour: hourCounts,
                occurrencesByDayOfWeek: dayOfWeekCounts
            )
        }
        .filter { $0.occurrencesByHour.values.reduce(0, +) >= 5 } // Minimum 5 occurrences
    }

    // MARK: Physiological correlations

    static func analysePhysiologicalCorrelations(
        in context: NSManagedObjectContext,
        days: Int = 30
    ) -> [PhysiologicalCorrelation] {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return []
        }

        let request = SymptomEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "((backdatedAt >= %@) OR (backdatedAt == nil AND createdAt >= %@))",
            startDate as NSDate, startDate as NSDate
        )

        guard let entries = try? context.fetch(request) else { return [] }

        // Group by symptom type
        let grouped = Dictionary(grouping: entries) { $0.symptomType }

        var correlations: [PhysiologicalCorrelation] = []

        for (type, entries) in grouped {
            guard let type = type, let name = type.name else { continue }

            // High severity = 4-5, Low severity = 1-2
            let highSeverityEntries = entries.filter { $0.severity >= 4 }
            let lowSeverityEntries = entries.filter { $0.severity <= 2 }

            let isPositive = type.isPositive

            // HRV correlation
            if let hrvCorr = calculateMetricCorrelation(
                symptomTypeName: name,
                symptomTypeColor: type.color ?? "gray",
                metricName: "HRV",
                highSeverityEntries: highSeverityEntries,
                lowSeverityEntries: lowSeverityEntries,
                extractor: { $0.hkHRV?.doubleValue },
                isPositive: isPositive
            ) {
                correlations.append(hrvCorr)
            }

            // Resting HR correlation
            if let hrCorr = calculateMetricCorrelation(
                symptomTypeName: name,
                symptomTypeColor: type.color ?? "gray",
                metricName: "Resting heart rate",
                highSeverityEntries: highSeverityEntries,
                lowSeverityEntries: lowSeverityEntries,
                extractor: { $0.hkRestingHR?.doubleValue },
                isPositive: isPositive
            ) {
                correlations.append(hrCorr)
            }

            // Sleep correlation
            if let sleepCorr = calculateMetricCorrelation(
                symptomTypeName: name,
                symptomTypeColor: type.color ?? "gray",
                metricName: "Sleep hours",
                highSeverityEntries: highSeverityEntries,
                lowSeverityEntries: lowSeverityEntries,
                extractor: { $0.hkSleepHours?.doubleValue },
                isPositive: isPositive
            ) {
                correlations.append(sleepCorr)
            }
        }

        return correlations.sorted { abs($0.correlationStrength) > abs($1.correlationStrength) }
    }

    private static func calculateMetricCorrelation(
        symptomTypeName: String,
        symptomTypeColor: String,
        metricName: String,
        highSeverityEntries: [SymptomEntry],
        lowSeverityEntries: [SymptomEntry],
        extractor: (SymptomEntry) -> Double?,
        isPositive: Bool = false
    ) -> PhysiologicalCorrelation? {
        let highValues = highSeverityEntries.compactMap(extractor)
        let lowValues = lowSeverityEntries.compactMap(extractor)

        guard !highValues.isEmpty && !lowValues.isEmpty else { return nil }

        let avgHigh = highValues.reduce(0, +) / Double(highValues.count)
        let avgLow = lowValues.reduce(0, +) / Double(lowValues.count)

        // Normalise correlation
        let maxValue = max(avgHigh, avgLow, 1.0)
        var correlation = (avgHigh - avgLow) / maxValue

        // For positive symptoms, flip the correlation (higher severity is better)
        if isPositive {
            correlation = -correlation
        }

        // Only return if meaningful
        guard abs(correlation) > 0.15 else { return nil }

        return PhysiologicalCorrelation(
            symptomTypeName: symptomTypeName,
            symptomTypeColor: symptomTypeColor,
            metricName: metricName,
            averageWithHighSymptoms: avgHigh,
            averageWithLowSymptoms: avgLow,
            correlationStrength: correlation,
            isPositive: isPositive
        )
    }
}
