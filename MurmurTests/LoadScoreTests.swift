//
//  LoadScoreTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import CoreData
import XCTest
@testable import Murmur

final class LoadScoreTests: XCTestCase {
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

    // MARK: - Basic Load Calculation Tests

    func testCalculateLoadWithNoActivitiesOrSymptoms() throws {
        let date = Date()
        let activities: [ActivityEvent] = []
        let symptoms: [SymptomEntry] = []
        let previousLoad = 0.0

        let score = LoadScore.calculate(
            for: date,
            activities: activities,
            symptoms: symptoms,
            previousLoad: previousLoad
        )

        XCTAssertEqual(score.rawLoad, 0.0)
        XCTAssertEqual(score.decayedLoad, 0.0)
        XCTAssertEqual(score.riskLevel, .safe)
    }

    func testCalculateLoadWithSingleActivity() throws {
        let date = Date()
        let activity = ActivityEvent(context: testStack.context)
        activity.id = UUID()
        activity.createdAt = date
        activity.name = "Test Activity"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 2
        activity.emotionalLoad = 1
        activity.durationMinutes = 60

        let score = LoadScore.calculate(
            for: date,
            activities: [activity],
            symptoms: [],
            previousLoad: 0.0
        )

        // Expected: avg exertion = (3+2+1)/3 = 2.0, duration weight = 1.0, multiplier = 6.0
        // Activity load = 2.0 * 1.0 * 6.0 = 12.0
        let expectedLoad = 12.0
        XCTAssertEqual(score.rawLoad, expectedLoad, accuracy: 0.1)
    }

    func testCalculateLoadWithHighExertionActivity() throws {
        let date = Date()
        let activity = ActivityEvent(context: testStack.context)
        activity.id = UUID()
        activity.createdAt = date
        activity.name = "High Intensity"
        activity.physicalExertion = 5
        activity.cognitiveExertion = 5
        activity.emotionalLoad = 5
        activity.durationMinutes = 120

        let score = LoadScore.calculate(
            for: date,
            activities: [activity],
            symptoms: [],
            previousLoad: 0.0
        )

        // Expected: avg exertion = 5.0, duration weight = 2.0 (capped), multiplier = 6.0
        // Activity load = 5.0 * 2.0 * 6.0 = 60.0
        let expectedLoad = 60.0
        XCTAssertEqual(score.rawLoad, expectedLoad, accuracy: 0.1)
    }

    func testCalculateLoadWithHighSeveritySymptoms() throws {
        let date = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.category = "Physical"

        let symptom = SymptomEntry(context: testStack.context)
        symptom.id = UUID()
        symptom.createdAt = date
        symptom.severity = 5
        symptom.symptomType = symptomType

        let score = LoadScore.calculate(
            for: date,
            activities: [],
            symptoms: [symptom],
            previousLoad: 0.0
        )

        // High severity symptoms (4-5) should add load
        // Normalised severity for negative symptom at level 5 = 5.0
        // Base symptom load = max(0, (5.0 - 3.0) * 10.0) = 20.0
        // With default multiplier (1.0): 20.0
        XCTAssertGreaterThan(score.rawLoad, 0.0)
        XCTAssertEqual(score.rawLoad, 20.0, accuracy: 0.1)
    }

    func testCalculateLoadWithLowSeveritySymptoms() throws {
        let date = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))

        let symptom = SymptomEntry(context: testStack.context)
        symptom.id = UUID()
        symptom.createdAt = date
        symptom.severity = 2
        symptom.symptomType = symptomType

        let score = LoadScore.calculate(
            for: date,
            activities: [],
            symptoms: [symptom],
            previousLoad: 0.0
        )

        // Low severity (1-3) should add minimal or no load
        // Normalised severity = 2.0
        // Base symptom load = max(0, (2.0 - 3.0) * 10.0) = 0.0
        XCTAssertEqual(score.rawLoad, 0.0, accuracy: 0.1)
    }

    func testCalculateLoadWithPositiveSymptom() throws {
        let date = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.category = "Positive wellbeing"

        let symptom = SymptomEntry(context: testStack.context)
        symptom.id = UUID()
        symptom.createdAt = date
        symptom.severity = 5
        symptom.symptomType = symptomType

        let score = LoadScore.calculate(
            for: date,
            activities: [],
            symptoms: [symptom],
            previousLoad: 0.0
        )

        // Positive symptom at level 5 should be normalized to low burden
        // Normalised severity for positive symptom at level 5 = 1.0
        // Base symptom load = max(0, (1.0 - 3.0) * 10.0) = 0.0
        XCTAssertEqual(score.rawLoad, 0.0, accuracy: 0.1)
    }

    func testCalculateLoadWithDecayFromPreviousDay() throws {
        let date = Date()
        let previousLoad = 50.0

        let score = LoadScore.calculate(
            for: date,
            activities: [],
            symptoms: [],
            previousLoad: previousLoad
        )

        // Previous load should decay
        // Default decay rate is typically around 0.7-0.85
        XCTAssertLessThan(score.decayedLoad, previousLoad)
        XCTAssertGreaterThan(score.decayedLoad, 0.0)
    }

    func testCalculateLoadWithSymptomModifiedDecay() throws {
        let date = Date()
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack.context))
        symptomType.category = "Physical"

        let highSeveritySymptom = SymptomEntry(context: testStack.context)
        highSeveritySymptom.id = UUID()
        highSeveritySymptom.createdAt = date
        highSeveritySymptom.severity = 5
        highSeveritySymptom.symptomType = symptomType

        let previousLoad = 50.0

        let scoreWithSymptom = LoadScore.calculate(
            for: date,
            activities: [],
            symptoms: [highSeveritySymptom],
            previousLoad: previousLoad
        )

        let scoreWithoutSymptom = LoadScore.calculate(
            for: date,
            activities: [],
            symptoms: [],
            previousLoad: previousLoad
        )

        // High severity symptoms should slow recovery (higher decayed load)
        XCTAssertGreaterThan(scoreWithSymptom.decayedLoad, scoreWithoutSymptom.decayedLoad)
    }

    // MARK: - Risk Level Tests

    func testRiskLevelSafe() throws {
        let date = Date()
        let activity = ActivityEvent(context: testStack.context)
        activity.id = UUID()
        activity.createdAt = date
        activity.physicalExertion = 1
        activity.cognitiveExertion = 1
        activity.emotionalLoad = 1
        activity.durationMinutes = 30

        let score = LoadScore.calculate(
            for: date,
            activities: [activity],
            symptoms: [],
            previousLoad: 0.0
        )

        XCTAssertEqual(score.riskLevel, .safe)
        XCTAssertLessThan(score.decayedLoad, 30.0) // Default safe threshold
    }

    func testRiskLevelHigh() throws {
        let date = Date()
        // Create multiple high-exertion activities
        var activities: [ActivityEvent] = []
        for i in 0..<5 {
            let activity = ActivityEvent(context: testStack.context)
            activity.id = UUID()
            activity.createdAt = date
            activity.name = "Activity \(i)"
            activity.physicalExertion = 5
            activity.cognitiveExertion = 5
            activity.emotionalLoad = 5
            activity.durationMinutes = 60
            activities.append(activity)
        }

        let score = LoadScore.calculate(
            for: date,
            activities: activities,
            symptoms: [],
            previousLoad: 0.0
        )

        // With 5 high-intensity activities, should reach high or critical risk
        XCTAssertTrue(score.riskLevel == .high || score.riskLevel == .critical)
    }

    // MARK: - Load Range Tests

    func testCalculateRangeWithMultipleDays() throws {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!

        // Create activities for each day
        var activitiesByDate: [Date: [ActivityEvent]] = [:]
        for i in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: -i, to: endDate) else { continue }
            let dayStart = calendar.startOfDay(for: day)

            let activity = ActivityEvent(context: testStack.context)
            activity.id = UUID()
            activity.createdAt = day
            activity.physicalExertion = 3
            activity.cognitiveExertion = 3
            activity.emotionalLoad = 3
            activity.durationMinutes = 60

            activitiesByDate[dayStart] = [activity]
        }

        let scores = LoadScore.calculateRange(
            from: startDate,
            to: endDate,
            activitiesByDate: activitiesByDate,
            symptomsByDate: [:]
        )

        XCTAssertEqual(scores.count, 8) // 8 days including start and end

        // Verify load accumulates over days
        for i in 1..<scores.count {
            // Each day should have some decayed load from previous days
            XCTAssertGreaterThan(scores[i].decayedLoad, scores[i].rawLoad * 0.5)
        }
    }

    func testCalculateRangeLoadAccumulation() throws {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -3, to: endDate)!

        // Create consistent high load each day
        var activitiesByDate: [Date: [ActivityEvent]] = [:]
        for i in 0...3 {
            guard let day = calendar.date(byAdding: .day, value: -i, to: endDate) else { continue }
            let dayStart = calendar.startOfDay(for: day)

            let activity = ActivityEvent(context: testStack.context)
            activity.id = UUID()
            activity.createdAt = day
            activity.physicalExertion = 4
            activity.cognitiveExertion = 4
            activity.emotionalLoad = 4
            activity.durationMinutes = 90

            activitiesByDate[dayStart] = [activity]
        }

        let scores = LoadScore.calculateRange(
            from: startDate,
            to: endDate,
            activitiesByDate: activitiesByDate,
            symptomsByDate: [:]
        )

        // Load should accumulate - last day should have higher total load
        XCTAssertGreaterThan(scores.last!.decayedLoad, scores.first!.decayedLoad)
    }

    func testCalculateRangeWithRecoveryDays() throws {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -4, to: endDate)!

        var activitiesByDate: [Date: [ActivityEvent]] = [:]

        // Day 0: high load
        let day0 = calendar.date(byAdding: .day, value: -4, to: endDate)!
        let activity0 = ActivityEvent(context: testStack.context)
        activity0.id = UUID()
        activity0.createdAt = day0
        activity0.physicalExertion = 5
        activity0.cognitiveExertion = 5
        activity0.emotionalLoad = 5
        activity0.durationMinutes = 120
        activitiesByDate[calendar.startOfDay(for: day0)] = [activity0]

        // Days 1-4: no activities (recovery)
        // activitiesByDate entries will be empty for these days

        let scores = LoadScore.calculateRange(
            from: startDate,
            to: endDate,
            activitiesByDate: activitiesByDate,
            symptomsByDate: [:]
        )

        // Load should decay over recovery days
        for i in 1..<scores.count {
            XCTAssertLessThan(scores[i].decayedLoad, scores[i-1].decayedLoad)
        }
    }

    // MARK: - Load Capping Tests

    func testLoadCappedAt100() throws {
        let date = Date()
        // Create an extreme number of high-intensity activities
        var activities: [ActivityEvent] = []
        for i in 0..<20 {
            let activity = ActivityEvent(context: testStack.context)
            activity.id = UUID()
            activity.createdAt = date
            activity.name = "Extreme Activity \(i)"
            activity.physicalExertion = 5
            activity.cognitiveExertion = 5
            activity.emotionalLoad = 5
            activity.durationMinutes = 120
            activities.append(activity)
        }

        let score = LoadScore.calculate(
            for: date,
            activities: activities,
            symptoms: [],
            previousLoad: 0.0
        )

        // Load should be capped at 100
        XCTAssertLessThanOrEqual(score.decayedLoad, 100.0)
        XCTAssertLessThanOrEqual(score.rawLoad, 100.0)
    }
}
