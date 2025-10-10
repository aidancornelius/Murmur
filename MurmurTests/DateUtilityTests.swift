//
//  DateUtilityTests.swift
//  MurmurTests
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import XCTest
@testable import Murmur

final class DateUtilityTests: XCTestCase {

    // MARK: - Day Key Tests

    func testDayKeyFormatting() {
        // Given a specific date
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 10
        components.hour = 14
        components.minute = 30
        components.timeZone = TimeZone(identifier: "Australia/Sydney")

        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        // When generating a day key
        let dayKey = DateUtility.dayKey(for: date, timeZone: TimeZone(identifier: "Australia/Sydney")!)

        // Then it should be formatted correctly
        XCTAssertEqual(dayKey, "2025-10-10")
    }

    func testDayKeyConsistencyAcrossTimezones() {
        // Given a date in UTC
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 10
        components.hour = 0
        components.minute = 0
        components.timeZone = TimeZone(identifier: "UTC")

        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        // When generating day keys for different timezones
        let utcKey = DateUtility.dayKey(for: date, timeZone: TimeZone(identifier: "UTC")!)
        let sydneyKey = DateUtility.dayKey(for: date, timeZone: TimeZone(identifier: "Australia/Sydney")!)
        let laKey = DateUtility.dayKey(for: date, timeZone: TimeZone(identifier: "America/Los_Angeles")!)

        // Then keys should differ based on timezone
        XCTAssertEqual(utcKey, "2025-10-10")
        XCTAssertEqual(sydneyKey, "2025-10-10") // Sydney is ahead, but still same day
        XCTAssertEqual(laKey, "2025-10-09") // LA is behind, so previous day
    }

    func testDayKeyThreadSafety() {
        // Given multiple concurrent operations
        let date = Date()
        let expectation = self.expectation(description: "Thread safety")
        expectation.expectedFulfillmentCount = 100

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        var results: [String] = []
        let resultsQueue = DispatchQueue(label: "test.results")

        // When generating day keys concurrently
        for _ in 0..<100 {
            queue.async {
                let key = DateUtility.dayKey(for: date)
                resultsQueue.sync {
                    results.append(key)
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Then all results should be identical
        let uniqueResults = Set(results)
        XCTAssertEqual(uniqueResults.count, 1)
    }

    // MARK: - Monthly Key Tests

    func testMonthlyKeyFormatting() {
        // Given a specific date
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 15
        components.timeZone = TimeZone(identifier: "UTC")

        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        // When generating a monthly key
        let monthlyKey = DateUtility.monthlyKey(for: date, timeZone: TimeZone(identifier: "UTC")!)

        // Then it should be formatted correctly
        XCTAssertEqual(monthlyKey, "2025-10")
    }

    // MARK: - Backup Timestamp Tests

    func testBackupTimestampFormatting() {
        // Given a specific date
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 10
        components.hour = 14
        components.minute = 30
        components.timeZone = TimeZone(identifier: "UTC")

        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        // When generating a backup timestamp
        let timestamp = DateUtility.backupTimestamp(for: date, timeZone: TimeZone(identifier: "UTC")!)

        // Then it should be formatted correctly
        XCTAssertEqual(timestamp, "2025-10-10_1430")
    }

    // MARK: - Day Bounds Tests

    func testDayBoundsCalculation() {
        // Given a specific date and time
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 10
        components.hour = 14
        components.minute = 30
        components.timeZone = TimeZone(identifier: "Australia/Sydney")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        let date = calendar.date(from: components)!

        // When calculating day bounds
        let (start, end) = DateUtility.dayBounds(for: date, calendar: calendar)

        // Then start should be midnight of that day
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start)
        XCTAssertEqual(startComponents.year, 2025)
        XCTAssertEqual(startComponents.month, 10)
        XCTAssertEqual(startComponents.day, 10)
        XCTAssertEqual(startComponents.hour, 0)
        XCTAssertEqual(startComponents.minute, 0)
        XCTAssertEqual(startComponents.second, 0)

        // And end should be midnight of the next day
        let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: end)
        XCTAssertEqual(endComponents.year, 2025)
        XCTAssertEqual(endComponents.month, 10)
        XCTAssertEqual(endComponents.day, 11)
        XCTAssertEqual(endComponents.hour, 0)
        XCTAssertEqual(endComponents.minute, 0)
        XCTAssertEqual(endComponents.second, 0)
    }

    func testDayBoundsAcrossMonthBoundary() {
        // Given the last day of a month
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 31
        components.hour = 14
        components.minute = 30
        components.timeZone = TimeZone(identifier: "UTC")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: components)!

        // When calculating day bounds
        let (start, end) = DateUtility.dayBounds(for: date, calendar: calendar)

        // Then end should be the first day of the next month
        let endComponents = calendar.dateComponents([.year, .month, .day], from: end)
        XCTAssertEqual(endComponents.year, 2025)
        XCTAssertEqual(endComponents.month, 11)
        XCTAssertEqual(endComponents.day, 1)
    }

    func testDayBoundsHandlesDST() {
        // Given a date during DST transition (Sydney, October 2025)
        // DST starts on October 5, 2025 at 2:00 AM (clocks forward to 3:00 AM)
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 5
        components.hour = 1
        components.minute = 30
        components.timeZone = TimeZone(identifier: "Australia/Sydney")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        let date = calendar.date(from: components)!

        // When calculating day bounds
        let (start, end) = DateUtility.dayBounds(for: date, calendar: calendar)

        // Then bounds should still be correct despite DST
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        XCTAssertEqual(startComponents.year, 2025)
        XCTAssertEqual(startComponents.month, 10)
        XCTAssertEqual(startComponents.day, 5)
        XCTAssertEqual(startComponents.hour, 0)
        XCTAssertEqual(startComponents.minute, 0)

        let endComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: end)
        XCTAssertEqual(endComponents.year, 2025)
        XCTAssertEqual(endComponents.month, 10)
        XCTAssertEqual(endComponents.day, 6)
        XCTAssertEqual(endComponents.hour, 0)
        XCTAssertEqual(endComponents.minute, 0)

        // And the duration should be 23 hours (one hour lost to DST)
        let duration = end.timeIntervalSince(start)
        XCTAssertEqual(duration, 23 * 3600, accuracy: 1.0) // 23 hours
    }

    // MARK: - Lookback Tests

    func testLookbackDateDays() {
        // Given a specific date
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 10
        components.hour = 14
        components.minute = 30
        components.timeZone = TimeZone(identifier: "UTC")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: components)!

        // When calculating lookback
        let lookback = DateUtility.lookbackDate(from: date, days: 5, calendar: calendar)

        // Then it should be 5 days earlier
        let lookbackComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: lookback)
        XCTAssertEqual(lookbackComponents.year, 2025)
        XCTAssertEqual(lookbackComponents.month, 10)
        XCTAssertEqual(lookbackComponents.day, 5)
        XCTAssertEqual(lookbackComponents.hour, 14)
        XCTAssertEqual(lookbackComponents.minute, 30)
    }

    func testLookbackDateHours() {
        // Given a specific date
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 10
        components.hour = 14
        components.minute = 30
        components.timeZone = TimeZone(identifier: "UTC")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: components)!

        // When calculating lookback
        let lookback = DateUtility.lookbackDate(from: date, hours: 48, calendar: calendar)

        // Then it should be 48 hours (2 days) earlier
        let lookbackComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: lookback)
        XCTAssertEqual(lookbackComponents.year, 2025)
        XCTAssertEqual(lookbackComponents.month, 10)
        XCTAssertEqual(lookbackComponents.day, 8)
        XCTAssertEqual(lookbackComponents.hour, 14)
        XCTAssertEqual(lookbackComponents.minute, 30)
    }

    func testLookbackDateAcrossMonthBoundary() {
        // Given the first day of a month
        var components = DateComponents()
        components.year = 2025
        components.month = 11
        components.day = 5
        components.hour = 10
        components.minute = 0
        components.timeZone = TimeZone(identifier: "UTC")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: components)!

        // When calculating lookback that crosses month boundary
        let lookback = DateUtility.lookbackDate(from: date, days: 10, calendar: calendar)

        // Then it should correctly handle the month boundary
        let lookbackComponents = calendar.dateComponents([.year, .month, .day], from: lookback)
        XCTAssertEqual(lookbackComponents.year, 2025)
        XCTAssertEqual(lookbackComponents.month, 10)
        XCTAssertEqual(lookbackComponents.day, 26)
    }

    func testLookbackIntervalDays() {
        // When calculating interval for days
        let interval = DateUtility.lookbackInterval(days: 5)

        // Then it should be correct
        XCTAssertEqual(interval, 5 * 24 * 3600)
    }

    func testLookbackIntervalHours() {
        // When calculating interval for hours
        let interval = DateUtility.lookbackInterval(hours: 24)

        // Then it should be correct
        XCTAssertEqual(interval, 24 * 3600)
    }

    // MARK: - Edge Cases

    func testZeroLookbackReturnsOriginalDate() {
        // Given a date
        let date = Date()

        // When calculating zero lookback
        let lookback = DateUtility.lookbackDate(from: date, days: 0)

        // Then it should return the original date
        XCTAssertEqual(lookback, date)
    }

    func testNegativeLookbackReturnsOriginalDate() {
        // Given a date
        let date = Date()

        // When calculating negative lookback
        let lookback = DateUtility.lookbackDate(from: date, days: -5)

        // Then it should return the original date
        XCTAssertEqual(lookback, date)
    }

    // MARK: - Cache Key Consistency Tests

    func testCacheKeyConsistencyForSameDay() {
        // Given two different times on the same day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!

        var morningComponents = DateComponents()
        morningComponents.year = 2025
        morningComponents.month = 10
        morningComponents.day = 10
        morningComponents.hour = 8
        morningComponents.minute = 0
        morningComponents.timeZone = TimeZone(identifier: "Australia/Sydney")

        var eveningComponents = DateComponents()
        eveningComponents.year = 2025
        eveningComponents.month = 10
        eveningComponents.day = 10
        eveningComponents.hour = 20
        eveningComponents.minute = 30
        eveningComponents.timeZone = TimeZone(identifier: "Australia/Sydney")

        let morningDate = calendar.date(from: morningComponents)!
        let eveningDate = calendar.date(from: eveningComponents)!

        // When generating day keys
        let morningKey = DateUtility.dayKey(for: morningDate, timeZone: TimeZone(identifier: "Australia/Sydney")!)
        let eveningKey = DateUtility.dayKey(for: eveningDate, timeZone: TimeZone(identifier: "Australia/Sydney")!)

        // Then they should be identical
        XCTAssertEqual(morningKey, eveningKey)
        XCTAssertEqual(morningKey, "2025-10-10")
    }
}
