//
//  LoadScoreCacheTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell
//

import XCTest
import CoreData
@testable import Murmur

@MainActor
final class LoadScoreCacheTests: XCTestCase {
    var testStack: InMemoryCoreDataStack?
    var cache: LoadScoreCache!
    let calendar = Calendar.current

    override func setUp() async throws {
        try await super.setUp()
        testStack = InMemoryCoreDataStack()
        cache = LoadScoreCache()
        SampleDataSeeder.seedIfNeeded(in: testStack!.context, forceSeed: true)
    }

    override func tearDown() {
        cache = nil
        testStack = nil
        super.tearDown()
    }

    // MARK: - Cache Hit/Miss Tests

    func testCacheHitReturnsStoredValue() throws {
        let today = calendar.startOfDay(for: Date())
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        // Create test data
        let entry = SymptomEntry(context: testStack!.context)
        entry.id = UUID()
        entry.createdAt = today
        entry.symptomType = symptomType
        entry.severity = 3

        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = today
        activity.name = "Test"
        activity.physicalExertion = 3
        activity.cognitiveExertion = 2
        activity.emotionalLoad = 2

        try testStack!.context.save()

        let config = LoadCapacityManager.shared.configuration

        // Calculate and cache
        let firstScore = LoadCalculator.shared.calculate(
            for: today,
            contributors: [activity],
            symptoms: [entry],
            previousLoad: 0.0,
            configuration: config
        )

        cache.set(firstScore, for: today, contributors: [activity],
                 symptoms: [entry], previousLoad: 0.0, config: config)

        // Verify cache hit
        let cachedScore = cache.get(for: today, contributors: [activity],
                                    symptoms: [entry], previousLoad: 0.0, config: config)

        XCTAssertNotNil(cachedScore)
        XCTAssertEqual(cachedScore?.date, firstScore.date)
        XCTAssertEqual(cachedScore?.decayedLoad ?? 0, firstScore.decayedLoad, accuracy: 0.01)
        XCTAssertEqual(cache.hits, 1)
        XCTAssertEqual(cache.misses, 0)
    }

    func testCacheMissReturnsNilForUnknownDate() throws {
        let today = calendar.startOfDay(for: Date())
        let config = LoadCapacityManager.shared.configuration

        let result = cache.get(for: today, contributors: [], symptoms: [],
                              previousLoad: 0.0, config: config)

        XCTAssertNil(result)
        XCTAssertEqual(cache.hits, 0)
        XCTAssertEqual(cache.misses, 1)
    }

    func testCacheMissWhenDataChanges() throws {
        let today = calendar.startOfDay(for: Date())
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))

        let entry1 = SymptomEntry(context: testStack!.context)
        entry1.id = UUID()
        entry1.createdAt = today
        entry1.symptomType = symptomType
        entry1.severity = 3

        try testStack!.context.save()

        let config = LoadCapacityManager.shared.configuration

        // Cache with first entry
        let firstScore = LoadCalculator.shared.calculate(for: today, contributors: [], symptoms: [entry1],
                                            previousLoad: 0.0, configuration: config)
        cache.set(firstScore, for: today, contributors: [], symptoms: [entry1],
                 previousLoad: 0.0, config: config)

        // Try to get with different entry
        let entry2 = SymptomEntry(context: testStack!.context)
        entry2.id = UUID()
        entry2.createdAt = today
        entry2.symptomType = symptomType
        entry2.severity = 4

        try testStack!.context.save()

        let cachedScore = cache.get(for: today, contributors: [], symptoms: [entry2],
                                    previousLoad: 0.0, config: config)

        XCTAssertNil(cachedScore, "Should miss cache when entry data changes")
        XCTAssertEqual(cache.misses, 1)
    }

    // MARK: - Calculate Range Tests

    func testCalculateRangeWithEmptyCache() throws {
        let startDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        let endDate = Date()

        let scores = cache.calculateRange(
            from: startDate,
            to: endDate,
            contributorsByDate: [:],
            symptomsByDate: [:]
        )

        XCTAssertEqual(scores.count, 8) // 7 days + today
        XCTAssertEqual(cache.misses, 8)
        XCTAssertEqual(cache.hits, 0)
    }

    func testCalculateRangeReusesCachedValues() throws {
        let startDate = calendar.date(byAdding: .day, value: -3, to: Date())!
        let endDate = Date()

        // First calculation - all misses
        let firstScores = cache.calculateRange(
            from: startDate,
            to: endDate,
            contributorsByDate: [:],
            symptomsByDate: [:]
        )

        XCTAssertEqual(firstScores.count, 4)
        XCTAssertEqual(cache.misses, 4)

        cache.resetStatistics()

        // Second calculation - all hits
        let secondScores = cache.calculateRange(
            from: startDate,
            to: endDate,
            contributorsByDate: [:],
            symptomsByDate: [:]
        )

        XCTAssertEqual(secondScores.count, 4)
        XCTAssertEqual(cache.hits, 4)
        XCTAssertEqual(cache.misses, 0)
    }

    func testCalculateRangeMaintainsDecayChain() throws {
        let symptomType = try XCTUnwrap(fetchFirstObject(SymptomType.fetchRequest(), in: testStack!.context))
        let day1 = calendar.date(byAdding: .day, value: -2, to: Date())!
        let day2 = calendar.date(byAdding: .day, value: -1, to: Date())!
        let day3 = Date()

        // Create high load activity on day 1
        let activity = ActivityEvent(context: testStack!.context)
        activity.id = UUID()
        activity.createdAt = day1
        activity.name = "Intense activity"
        activity.physicalExertion = 5
        activity.cognitiveExertion = 5
        activity.emotionalLoad = 5
        activity.durationMinutes = 120

        try testStack!.context.save()

        let contributorsByDate: [Date: [ActivityEvent]] = [
            calendar.startOfDay(for: day1): [activity]
        ]

        let scores = cache.calculateRange(
            from: day1,
            to: day3,
            contributorsByDate: contributorsByDate,
            symptomsByDate: [:]
        )

        XCTAssertEqual(scores.count, 3)

        // Day 1 should have high raw load from activity
        XCTAssertGreaterThan(scores[0].rawLoad, 0)

        // Day 2 should have decayed load from day 1 (no new load)
        XCTAssertGreaterThan(scores[1].decayedLoad, 0)
        XCTAssertLessThan(scores[1].decayedLoad, scores[0].decayedLoad)

        // Day 3 should have further decayed load
        XCTAssertLessThan(scores[2].decayedLoad, scores[1].decayedLoad)
    }

    // MARK: - Invalidation Tests

    func testInvalidateFromRemovesFutureEntries() throws {
        let day1 = calendar.date(byAdding: .day, value: -3, to: Date())!
        let day2 = calendar.date(byAdding: .day, value: -2, to: Date())!
        let day3 = calendar.date(byAdding: .day, value: -1, to: Date())!

        // Populate cache
        _ = cache.calculateRange(from: day1, to: day3, contributorsByDate: [:], symptomsByDate: [:])

        cache.resetStatistics()

        // Invalidate from day 2 onward
        cache.invalidateFrom(date: day2)

        // day1 should hit, day2 and day3 should miss
        _ = cache.calculateRange(from: day1, to: day3, contributorsByDate: [:], symptomsByDate: [:])

        XCTAssertEqual(cache.hits, 1, "Day 1 should be cached")
        XCTAssertEqual(cache.misses, 2, "Day 2 and 3 should be recalculated")
    }

    func testInvalidateSpecificDateOnly() throws {
        let day1 = calendar.date(byAdding: .day, value: -2, to: Date())!
        let day2 = calendar.date(byAdding: .day, value: -1, to: Date())!
        let day3 = Date()

        // Populate cache
        _ = cache.calculateRange(from: day1, to: day3, contributorsByDate: [:], symptomsByDate: [:])

        cache.resetStatistics()

        // Invalidate only day 2
        cache.invalidate(date: day2)

        // day1 and day3 should hit, day2 should miss
        _ = cache.calculateRange(from: day1, to: day3, contributorsByDate: [:], symptomsByDate: [:])

        XCTAssertEqual(cache.hits, 2, "Day 1 and 3 should be cached")
        XCTAssertEqual(cache.misses, 1, "Day 2 should be recalculated")
    }

    func testInvalidateAllClearsEntireCache() throws {
        let startDate = calendar.date(byAdding: .day, value: -5, to: Date())!
        let endDate = Date()

        // Populate cache
        _ = cache.calculateRange(from: startDate, to: endDate, contributorsByDate: [:], symptomsByDate: [:])

        cache.invalidateAll()
        cache.resetStatistics()

        // All should miss
        _ = cache.calculateRange(from: startDate, to: endDate, contributorsByDate: [:], symptomsByDate: [:])

        XCTAssertEqual(cache.hits, 0)
        XCTAssertEqual(cache.misses, 6) // 6 days
    }

    // MARK: - Pruning Tests

    func testPruneOlderThanRemovesOldEntries() throws {
        let oldDate = calendar.date(byAdding: .day, value: -150, to: Date())!
        let recentDate = calendar.date(byAdding: .day, value: -5, to: Date())!

        // Populate cache with old and recent dates
        _ = cache.calculateRange(from: oldDate, to: oldDate, contributorsByDate: [:], symptomsByDate: [:])
        _ = cache.calculateRange(from: recentDate, to: recentDate, contributorsByDate: [:], symptomsByDate: [:])

        let statsBefore = cache.statistics()
        XCTAssertEqual(statsBefore.entries, 2)

        // Prune entries older than 120 days
        cache.pruneOlderThan(days: 120)

        let statsAfter = cache.statistics()
        XCTAssertEqual(statsAfter.entries, 1, "Should keep only recent entry")
    }

    // MARK: - Statistics Tests

    func testStatisticsTrackHitRate() throws {
        let startDate = calendar.date(byAdding: .day, value: -2, to: Date())!
        let endDate = Date()

        // First pass - 3 misses
        _ = cache.calculateRange(from: startDate, to: endDate, contributorsByDate: [:], symptomsByDate: [:])

        // Second pass - 3 hits
        _ = cache.calculateRange(from: startDate, to: endDate, contributorsByDate: [:], symptomsByDate: [:])

        let stats = cache.statistics()
        XCTAssertEqual(stats.entries, 3)
        XCTAssertEqual(stats.hits, 3)
        XCTAssertEqual(stats.misses, 3)
        XCTAssertEqual(stats.hitRate, 0.5, accuracy: 0.01)
    }

    func testResetStatisticsClearsCounters() throws {
        _ = cache.calculateRange(from: Date(), to: Date(), contributorsByDate: [:], symptomsByDate: [:])

        cache.resetStatistics()

        let stats = cache.statistics()
        XCTAssertEqual(stats.hits, 0)
        XCTAssertEqual(stats.misses, 0)
    }
}
