//
//  AnalysisEngineTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import CoreData
import XCTest
@testable import Murmur

final class AnalysisEngineTests: XCTestCase {
    var testStack: InMemoryCoreDataStack!

    override func setUp() {
        super.setUp()
        testStack = InMemoryCoreDataStack()
        SampleDataSeeder.seedIfNeeded(in: testStack.context, forceSeed: true)
    }

    override func tearDown() {
        testStack = nil
        super.tearDown()
    }

    // MARK: - Symptom Trend Tests

    func testAnalyseSymptomTrendsWithNoData() throws {
        let trends = AnalysisEngine.analyseSymptomTrends(in: testStack.context, days: 30)
        XCTAssertTrue(trends.isEmpty)
    }

    func testAnalyseSymptomTrendsDetectsDecreasing() throws {
        let calendar = Calendar.current
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.isPositive = false
        symptomType.name = "Fatigue"

        // Create worsening trend: low severity in first half, high in second half
        for i in 0..<30 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            let date = calendar.date(byAdding: .day, value: -i, to: now)!
            entry.createdAt = date
            entry.symptomType = symptomType

            // First half (days 15-30): severity 2, second half (days 0-14): severity 5
            entry.severity = i >= 15 ? 2 : 5
        }
        try testStack.context.save()

        let trends = AnalysisEngine.analyseSymptomTrends(in: testStack.context, days: 30)

        XCTAssertEqual(trends.count, 1)
        let trend = try XCTUnwrap(trends.first)
        XCTAssertEqual(trend.symptomTypeName, "Fatigue")
        XCTAssertEqual(trend.trend, .decreasing) // Worsening for negative symptoms
    }

    func testAnalyseSymptomTrendsDetectsIncreasing() throws {
        let calendar = Calendar.current
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.isPositive = false
        symptomType.name = "Pain"

        // Create improving trend: high severity in first half, low in second half
        for i in 0..<30 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            let date = calendar.date(byAdding: .day, value: -i, to: now)!
            entry.createdAt = date
            entry.symptomType = symptomType

            // First half (days 15-30): severity 5, second half (days 0-14): severity 2
            entry.severity = i >= 15 ? 5 : 2
        }
        try testStack.context.save()

        let trends = AnalysisEngine.analyseSymptomTrends(in: testStack.context, days: 30)

        XCTAssertEqual(trends.count, 1)
        let trend = try XCTUnwrap(trends.first)
        XCTAssertEqual(trend.trend, .increasing) // Improving for negative symptoms
    }

    func testAnalyseSymptomTrendsDetectsStable() throws {
        let calendar = Calendar.current
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.name = "Stable Symptom"

        // Create stable trend: consistent severity
        for i in 0..<30 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            let date = calendar.date(byAdding: .day, value: -i, to: now)!
            entry.createdAt = date
            entry.symptomType = symptomType
            entry.severity = 3
        }
        try testStack.context.save()

        let trends = AnalysisEngine.analyseSymptomTrends(in: testStack.context, days: 30)

        XCTAssertEqual(trends.count, 1)
        let trend = try XCTUnwrap(trends.first)
        XCTAssertEqual(trend.trend, .stable)
    }

    func testAnalyseSymptomTrendsWithPositiveSymptom() throws {
        let calendar = Calendar.current
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.isPositive = true
        symptomType.name = "Energy"

        // Create improving trend for positive symptom: low in first half, high in second half
        for i in 0..<30 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            let date = calendar.date(byAdding: .day, value: -i, to: now)!
            entry.createdAt = date
            entry.symptomType = symptomType

            // First half (days 15-30): severity 2, second half (days 0-14): severity 5
            entry.severity = i >= 15 ? 2 : 5
        }
        try testStack.context.save()

        let trends = AnalysisEngine.analyseSymptomTrends(in: testStack.context, days: 30)

        XCTAssertEqual(trends.count, 1)
        let trend = try XCTUnwrap(trends.first)
        XCTAssertTrue(trend.isPositive)
        // For positive symptoms, higher severity = better = improving
        XCTAssertEqual(trend.trend, .increasing)
    }

    func testAnalyseSymptomTrendsHandlesInsufficientData() throws {
        let calendar = Calendar.current
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))

        // Only create entries in first half
        for i in 15..<30 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            let date = calendar.date(byAdding: .day, value: -i, to: now)!
            entry.createdAt = date
            entry.symptomType = symptomType
            entry.severity = 3
        }
        try testStack.context.save()

        let trends = AnalysisEngine.analyseSymptomTrends(in: testStack.context, days: 30)

        // Should still return trend, but marked as stable due to insufficient comparison data
        XCTAssertEqual(trends.count, 1)
        XCTAssertEqual(trends.first?.trend, .stable)
    }

    // MARK: - Activity Correlation Tests

    func testAnalyseActivityCorrelationsWithNoData() throws {
        let correlations = AnalysisEngine.analyseActivityCorrelations(in: testStack.context, days: 30)
        XCTAssertTrue(correlations.isEmpty)
    }

    func testAnalyseActivityCorrelationsDetectsPositiveCorrelation() throws {
        let calendar = Calendar.current
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.isPositive = false
        symptomType.name = "Headache"

        // Create activities followed by symptoms
        for i in 0..<10 {
            let activityDate = calendar.date(byAdding: .day, value: -i, to: now)!

            let activity = ActivityEvent(context: testStack.context)
            activity.id = UUID()
            activity.createdAt = activityDate
            activity.name = "Screen Time"
            activity.physicalExertion = 1
            activity.cognitiveExertion = 4
            activity.emotionalLoad = 2

            // Create symptom 12 hours after activity (within 24hr window)
            let symptomDate = activityDate.addingTimeInterval(12 * 3600)
            let symptom = SymptomEntry(context: testStack.context)
            symptom.id = UUID()
            symptom.createdAt = symptomDate
            symptom.symptomType = symptomType
            symptom.severity = 4
        }

        // Create some symptoms without preceding activities (lower severity)
        for i in 10..<15 {
            let symptomDate = calendar.date(byAdding: .day, value: -i, to: now)!
            let symptom = SymptomEntry(context: testStack.context)
            symptom.id = UUID()
            symptom.createdAt = symptomDate
            symptom.symptomType = symptomType
            symptom.severity = 2
        }

        try testStack.context.save()

        let correlations = AnalysisEngine.analyseActivityCorrelations(in: testStack.context, days: 30, hoursWindow: 24)

        XCTAssertGreaterThan(correlations.count, 0)
        let correlation = try XCTUnwrap(correlations.first(where: { $0.activityName == "Screen Time" }))
        XCTAssertGreaterThan(correlation.correlationStrength, 0.2) // Positive correlation (activity worsens symptom)
        XCTAssertEqual(correlation.symptomTypeName, "Headache")
    }

    func testAnalyseActivityCorrelationsWithPositiveSymptom() throws {
        let calendar = Calendar.current
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.isPositive = true
        symptomType.name = "Mood"

        // Create activities followed by improved positive symptoms
        for i in 0..<10 {
            let activityDate = calendar.date(byAdding: .day, value: -i, to: now)!

            let activity = ActivityEvent(context: testStack.context)
            activity.id = UUID()
            activity.createdAt = activityDate
            activity.name = "Exercise"
            activity.physicalExertion = 4

            let symptomDate = activityDate.addingTimeInterval(6 * 3600)
            let symptom = SymptomEntry(context: testStack.context)
            symptom.id = UUID()
            symptom.createdAt = symptomDate
            symptom.symptomType = symptomType
            symptom.severity = 5 // High positive symptom = good
        }

        // Symptoms without activity (lower)
        for i in 10..<15 {
            let symptomDate = calendar.date(byAdding: .day, value: -i, to: now)!
            let symptom = SymptomEntry(context: testStack.context)
            symptom.id = UUID()
            symptom.createdAt = symptomDate
            symptom.symptomType = symptomType
            symptom.severity = 2
        }

        try testStack.context.save()

        let correlations = AnalysisEngine.analyseActivityCorrelations(in: testStack.context, days: 30)

        XCTAssertGreaterThan(correlations.count, 0)
        let correlation = try XCTUnwrap(correlations.first(where: { $0.activityName == "Exercise" }))
        // For positive symptoms, correlation should be flipped
        XCTAssertLessThan(correlation.correlationStrength, -0.2) // Negative correlation (activity improves positive symptom)
        XCTAssertTrue(correlation.isPositive)
    }

    func testAnalyseActivityCorrelationsMinimumOccurrences() throws {
        let calendar = Calendar.current
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))

        // Create only 1 activity-symptom pair (below minimum threshold)
        let activityDate = calendar.date(byAdding: .day, value: -1, to: now)!
        let activity = ActivityEvent(context: testStack.context)
        activity.id = UUID()
        activity.createdAt = activityDate
        activity.name = "Rare Activity"

        let symptom = SymptomEntry(context: testStack.context)
        symptom.id = UUID()
        symptom.createdAt = activityDate.addingTimeInterval(3600)
        symptom.symptomType = symptomType
        symptom.severity = 4

        try testStack.context.save()

        let correlations = AnalysisEngine.analyseActivityCorrelations(in: testStack.context, days: 30)

        // Should not include correlation with < 2 occurrences
        XCTAssertTrue(correlations.isEmpty || !correlations.contains(where: { $0.activityName == "Rare Activity" }))
    }

    // MARK: - Time Pattern Tests

    func testAnalyseTimePatternsWithNoData() throws {
        let patterns = AnalysisEngine.analyseTimePatterns(in: testStack.context, days: 30)
        XCTAssertTrue(patterns.isEmpty)
    }

    func testAnalyseTimePatternsDetectsPeakHour() throws {
        let calendar = Calendar.current
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.name = "Morning Symptom"

        // Create symptoms clustered around 9am
        for i in 0..<10 {
            let baseDate = calendar.date(byAdding: .day, value: -i, to: now)!
            var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
            components.hour = 9
            components.minute = 0

            let symptomDate = calendar.date(from: components)!
            let symptom = SymptomEntry(context: testStack.context)
            symptom.id = UUID()
            symptom.createdAt = symptomDate
            symptom.symptomType = symptomType
            symptom.severity = 3
        }

        try testStack.context.save()

        let patterns = AnalysisEngine.analyseTimePatterns(in: testStack.context, days: 30)

        XCTAssertEqual(patterns.count, 1)
        let pattern = try XCTUnwrap(patterns.first)
        XCTAssertEqual(pattern.peakHour, 9)
        XCTAssertEqual(pattern.symptomTypeName, "Morning Symptom")
    }

    func testAnalyseTimePatternsDetectsPeakDayOfWeek() throws {
        let calendar = Calendar.current
        let now = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.name = "Monday Blues"

        // Create symptoms on Mondays (weekday = 2)
        var mondayDate = now
        var mondayCount = 0

        while mondayCount < 6 {
            if calendar.component(.weekday, from: mondayDate) == 2 { // Monday
                let symptom = SymptomEntry(context: testStack.context)
                symptom.id = UUID()
                symptom.createdAt = mondayDate
                symptom.symptomType = symptomType
                symptom.severity = 4
                mondayCount += 1
            }
            mondayDate = calendar.date(byAdding: .day, value: -1, to: mondayDate)!
        }

        try testStack.context.save()

        let patterns = AnalysisEngine.analyseTimePatterns(in: testStack.context, days: 60)

        XCTAssertEqual(patterns.count, 1)
        let pattern = try XCTUnwrap(patterns.first)
        XCTAssertEqual(pattern.peakDayOfWeek, 2) // Monday
    }

    func testAnalyseTimePatternsMinimumOccurrences() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))

        // Create only 4 occurrences (below minimum of 5)
        for i in 0..<4 {
            let symptom = SymptomEntry(context: testStack.context)
            symptom.id = UUID()
            symptom.createdAt = Date().addingTimeInterval(TimeInterval(-i * 86400))
            symptom.symptomType = symptomType
            symptom.severity = 3
        }

        try testStack.context.save()

        let patterns = AnalysisEngine.analyseTimePatterns(in: testStack.context, days: 30)

        // Should be filtered out due to insufficient occurrences
        XCTAssertTrue(patterns.isEmpty)
    }

    // MARK: - Physiological Correlation Tests

    func testAnalysePhysiologicalCorrelationsWithNoData() throws {
        let correlations = AnalysisEngine.analysePhysiologicalCorrelations(in: testStack.context, days: 30)
        XCTAssertTrue(correlations.isEmpty)
    }

    func testAnalysePhysiologicalCorrelationsHRV() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.isPositive = false
        symptomType.name = "Stress"

        // Create high severity entries with low HRV
        for i in 0..<5 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            entry.createdAt = Date().addingTimeInterval(TimeInterval(-i * 86400))
            entry.symptomType = symptomType
            entry.severity = 5
            entry.hkHRV = NSNumber(value: 30.0) // Low HRV
        }

        // Create low severity entries with high HRV
        for i in 5..<10 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            entry.createdAt = Date().addingTimeInterval(TimeInterval(-i * 86400))
            entry.symptomType = symptomType
            entry.severity = 1
            entry.hkHRV = NSNumber(value: 70.0) // High HRV
        }

        try testStack.context.save()

        let correlations = AnalysisEngine.analysePhysiologicalCorrelations(in: testStack.context, days: 30)

        let hrvCorrelation = correlations.first(where: { $0.metricName == "HRV" })
        XCTAssertNotNil(hrvCorrelation)
        XCTAssertEqual(hrvCorrelation?.symptomTypeName, "Stress")
        // High symptom severity correlates with low HRV = negative correlation
        XCTAssertLessThan(hrvCorrelation?.correlationStrength ?? 0, 0)
    }

    func testAnalysePhysiologicalCorrelationsRestingHR() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.isPositive = false
        symptomType.name = "Anxiety"

        // High severity with high resting HR
        for i in 0..<5 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            entry.createdAt = Date().addingTimeInterval(TimeInterval(-i * 86400))
            entry.symptomType = symptomType
            entry.severity = 5
            entry.hkRestingHR = NSNumber(value: 80.0)
        }

        // Low severity with low resting HR
        for i in 5..<10 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            entry.createdAt = Date().addingTimeInterval(TimeInterval(-i * 86400))
            entry.symptomType = symptomType
            entry.severity = 1
            entry.hkRestingHR = NSNumber(value: 60.0)
        }

        try testStack.context.save()

        let correlations = AnalysisEngine.analysePhysiologicalCorrelations(in: testStack.context, days: 30)

        let hrCorrelation = correlations.first(where: { $0.metricName == "Resting heart rate" })
        XCTAssertNotNil(hrCorrelation)
        // High symptom severity correlates with high HR = positive correlation
        XCTAssertGreaterThan(hrCorrelation?.correlationStrength ?? 0, 0)
    }

    func testAnalysePhysiologicalCorrelationsSleep() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.isPositive = false
        symptomType.name = "Fatigue"

        // High severity with low sleep
        for i in 0..<5 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            entry.createdAt = Date().addingTimeInterval(TimeInterval(-i * 86400))
            entry.symptomType = symptomType
            entry.severity = 5
            entry.hkSleepHours = NSNumber(value: 4.0)
        }

        // Low severity with good sleep
        for i in 5..<10 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            entry.createdAt = Date().addingTimeInterval(TimeInterval(-i * 86400))
            entry.symptomType = symptomType
            entry.severity = 1
            entry.hkSleepHours = NSNumber(value: 8.0)
        }

        try testStack.context.save()

        let correlations = AnalysisEngine.analysePhysiologicalCorrelations(in: testStack.context, days: 30)

        let sleepCorrelation = correlations.first(where: { $0.metricName == "Sleep hours" })
        XCTAssertNotNil(sleepCorrelation)
        // High symptom severity correlates with low sleep = negative correlation
        XCTAssertLessThan(sleepCorrelation?.correlationStrength ?? 0, 0)
    }

    func testAnalysePhysiologicalCorrelationsMinimumStrength() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))

        // Create entries with very similar HRV (weak correlation)
        for i in 0..<5 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            entry.createdAt = Date().addingTimeInterval(TimeInterval(-i * 86400))
            entry.symptomType = symptomType
            entry.severity = 5
            entry.hkHRV = NSNumber(value: 50.0)
        }

        for i in 5..<10 {
            let entry = SymptomEntry(context: testStack.context)
            entry.id = UUID()
            entry.createdAt = Date().addingTimeInterval(TimeInterval(-i * 86400))
            entry.symptomType = symptomType
            entry.severity = 1
            entry.hkHRV = NSNumber(value: 51.0) // Very similar
        }

        try testStack.context.save()

        let correlations = AnalysisEngine.analysePhysiologicalCorrelations(in: testStack.context, days: 30)

        // Weak correlations (< 0.15) should be filtered out
        let hrvCorrelation = correlations.first(where: { $0.metricName == "HRV" })
        XCTAssertNil(hrvCorrelation)
    }
}
