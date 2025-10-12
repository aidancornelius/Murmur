//
//  HealthKitCacheServiceTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import XCTest
@testable import Murmur

final class HealthKitCacheServiceTests: XCTestCase {

    var cacheService: HealthKitCacheService!

    override func setUp() {
        super.setUp()
        cacheService = HealthKitCacheService()
    }

    override func tearDown() {
        cacheService = nil
        super.tearDown()
    }

    // MARK: - Last Sample Date Tests

    func testGetLastSampleDate_InitiallyNil() async {
        // When
        let date = await cacheService.getLastSampleDate(for: .hrv)

        // Then
        XCTAssertNil(date)
    }

    func testSetAndGetLastSampleDate() async {
        // Given
        let now = Date()

        // When
        await cacheService.setLastSampleDate(now, for: .hrv)
        let retrieved = await cacheService.getLastSampleDate(for: .hrv)

        // Then
        XCTAssertNotNil(retrieved)
        if let retrieved = retrieved {
            XCTAssertEqual(retrieved.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
        }
    }

    func testLastSampleDate_IndependentPerMetric() async {
        // Given
        let hrvDate = Date()
        let hrDate = Date().addingTimeInterval(-3600)

        // When
        await cacheService.setLastSampleDate(hrvDate, for: .hrv)
        await cacheService.setLastSampleDate(hrDate, for: .restingHR)

        // Then
        let retrievedHRV = await cacheService.getLastSampleDate(for: .hrv)
        let retrievedHR = await cacheService.getLastSampleDate(for: .restingHR)

        if let retrievedHRV = retrievedHRV {
            XCTAssertEqual(retrievedHRV.timeIntervalSince1970, hrvDate.timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail("HRV date should not be nil")
        }
        if let retrievedHR = retrievedHR {
            XCTAssertEqual(retrievedHR.timeIntervalSince1970, hrDate.timeIntervalSince1970, accuracy: 0.001)
        } else {
            XCTFail("HR date should not be nil")
        }
    }

    // MARK: - Should Refresh Tests

    func testShouldRefresh_NoCacheReturnsTrue() async {
        // When
        let shouldRefresh = await cacheService.shouldRefresh(metric: .hrv, cacheDuration: 300, force: false)

        // Then
        XCTAssertTrue(shouldRefresh)
    }

    func testShouldRefresh_ForceAlwaysReturnsTrue() async {
        // Given
        await cacheService.setLastSampleDate(Date(), for: .hrv)

        // When
        let shouldRefresh = await cacheService.shouldRefresh(metric: .hrv, cacheDuration: 300, force: true)

        // Then
        XCTAssertTrue(shouldRefresh)
    }

    func testShouldRefresh_WithinDurationReturnsFalse() async {
        // Given
        await cacheService.setLastSampleDate(Date(), for: .hrv)

        // When
        let shouldRefresh = await cacheService.shouldRefresh(metric: .hrv, cacheDuration: 300, force: false)

        // Then
        XCTAssertFalse(shouldRefresh)
    }

    func testShouldRefresh_ExpiredReturnsTrue() async {
        // Given
        let oldDate = Date().addingTimeInterval(-600) // 10 minutes ago
        await cacheService.setLastSampleDate(oldDate, for: .hrv)

        // When
        let shouldRefresh = await cacheService.shouldRefresh(metric: .hrv, cacheDuration: 300, force: false) // 5 min cache

        // Then
        XCTAssertTrue(shouldRefresh)
    }

    // MARK: - Historical Cache Tests

    func testGetCachedValue_InitiallyNil() async {
        // When
        let value: Double? = await cacheService.getCachedValue(for: .hrv, date: Date())

        // Then
        XCTAssertNil(value)
    }

    func testSetAndGetCachedValue_Double() async {
        // Given
        let date = Date()
        let hrvValue = 45.2

        // When
        await cacheService.setCachedValue(hrvValue, for: .hrv, date: date)
        let retrieved: Double? = await cacheService.getCachedValue(for: .hrv, date: date)

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, hrvValue)
    }

    func testSetAndGetCachedValue_Int() async {
        // Given
        let date = Date()
        let cycleDayValue = 14

        // When
        await cacheService.setCachedValue(cycleDayValue, for: .cycleDay, date: date)
        let retrieved: Int? = await cacheService.getCachedValue(for: .cycleDay, date: date)

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, cycleDayValue)
    }

    func testSetAndGetCachedValue_String() async {
        // Given
        let date = Date()
        let flowValue = "light"

        // When
        await cacheService.setCachedValue(flowValue, for: .flowLevel, date: date)
        let retrieved: String? = await cacheService.getCachedValue(for: .flowLevel, date: date)

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, flowValue)
    }

    func testCachedValue_IndependentPerMetric() async {
        // Given
        let date = Date()

        // When
        await cacheService.setCachedValue(45.2, for: .hrv, date: date)
        await cacheService.setCachedValue(65.0, for: .restingHR, date: date)

        // Then
        let hrv: Double? = await cacheService.getCachedValue(for: .hrv, date: date)
        let hr: Double? = await cacheService.getCachedValue(for: .restingHR, date: date)

        XCTAssertEqual(hrv, 45.2)
        XCTAssertEqual(hr, 65.0)
    }

    func testCachedValue_IndependentPerDate() async {
        // Given
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        // When
        await cacheService.setCachedValue(45.2, for: .hrv, date: today)
        await cacheService.setCachedValue(50.0, for: .hrv, date: yesterday)

        // Then
        let todayValue: Double? = await cacheService.getCachedValue(for: .hrv, date: today)
        let yesterdayValue: Double? = await cacheService.getCachedValue(for: .hrv, date: yesterday)

        XCTAssertEqual(todayValue, 45.2)
        XCTAssertEqual(yesterdayValue, 50.0)
    }

    func testCachedValue_SameDayReturnsSameValue() async {
        // Given
        let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let evening = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!

        // When
        await cacheService.setCachedValue(45.2, for: .hrv, date: morning)
        let retrievedEvening: Double? = await cacheService.getCachedValue(for: .hrv, date: evening)

        // Then
        XCTAssertEqual(retrievedEvening, 45.2, "Same day should return cached value")
    }

    // MARK: - Clear Cache Tests

    func testClearCache_ClearsRecentData() async {
        // Given
        await cacheService.setLastSampleDate(Date(), for: .hrv)
        await cacheService.setLastSampleDate(Date(), for: .restingHR)

        // When
        await cacheService.clearCache()

        // Then
        let hrvDate = await cacheService.getLastSampleDate(for: .hrv)
        let hrDate = await cacheService.getLastSampleDate(for: .restingHR)
        XCTAssertNil(hrvDate)
        XCTAssertNil(hrDate)
    }

    func testClearCache_ClearsHistoricalData() async {
        // Given
        let date = Date()
        await cacheService.setCachedValue(45.2, for: .hrv, date: date)
        await cacheService.setCachedValue(65.0, for: .restingHR, date: date)

        // When
        await cacheService.clearCache()

        // Then
        let hrv: Double? = await cacheService.getCachedValue(for: .hrv, date: date)
        let hr: Double? = await cacheService.getCachedValue(for: .restingHR, date: date)

        XCTAssertNil(hrv)
        XCTAssertNil(hr)
    }

    // MARK: - Type Safety Tests

    func testCachedValue_WrongTypeReturnsNil() async {
        // Given
        let date = Date()
        await cacheService.setCachedValue(45.2, for: .hrv, date: date)

        // When - Try to retrieve as wrong type
        let wrongType: Int? = await cacheService.getCachedValue(for: .hrv, date: date)

        // Then
        XCTAssertNil(wrongType, "Should return nil when retrieving with wrong type")
    }

    // MARK: - All Metrics Tests

    func testAllMetricTypes() async {
        // Given
        let date = Date()
        let metrics: [(HealthMetric, Any)] = [
            (.hrv, 45.2),
            (.restingHR, 65.0),
            (.sleep, 7.5),
            (.workout, 30.0),
            (.cycleDay, 14),
            (.flowLevel, "light")
        ]

        // When
        for (metric, value) in metrics {
            if let doubleValue = value as? Double {
                await cacheService.setCachedValue(doubleValue, for: metric, date: date)
            } else if let intValue = value as? Int {
                await cacheService.setCachedValue(intValue, for: metric, date: date)
            } else if let stringValue = value as? String {
                await cacheService.setCachedValue(stringValue, for: metric, date: date)
            }
        }

        // Then
        let hrv: Double? = await cacheService.getCachedValue(for: .hrv, date: date)
        let restingHR: Double? = await cacheService.getCachedValue(for: .restingHR, date: date)
        let sleep: Double? = await cacheService.getCachedValue(for: .sleep, date: date)
        let workout: Double? = await cacheService.getCachedValue(for: .workout, date: date)
        let cycleDay: Int? = await cacheService.getCachedValue(for: .cycleDay, date: date)
        let flowLevel: String? = await cacheService.getCachedValue(for: .flowLevel, date: date)

        XCTAssertEqual(hrv, 45.2)
        XCTAssertEqual(restingHR, 65.0)
        XCTAssertEqual(sleep, 7.5)
        XCTAssertEqual(workout, 30.0)
        XCTAssertEqual(cycleDay, 14)
        XCTAssertEqual(flowLevel, "light")
    }
}
