// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DateUtility.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Date calculation and manipulation utilities.
//
import Foundation

/// Thread-safe date formatting and day-bound calculations
///
/// Provides reusable helpers for date formatting and calendar operations to ensure
/// consistency across cache keys, lookback windows, and time zone handling.
///
/// All formatters are created on-demand for thread safety. DateFormatter creation
/// is sufficiently fast that caching adds unnecessary complexity and potential for bugs.
enum DateUtility {
    // MARK: - Current Time

    /// Get the current time, respecting test time overrides
    ///
    /// In UI test mode with `-OverrideTime HH:MM`, returns the override time.
    /// Otherwise returns the actual current time.
    ///
    /// - Returns: The current date/time or the overridden test time
    static func now() -> Date {
        #if targetEnvironment(simulator)
        if let overrideTime = UITestConfiguration.overrideTime {
            print("[DateUtility] Using override time: \(overrideTime)")
            return overrideTime
        } else {
            print("[DateUtility] No override time, using real time")
        }
        #endif
        return Date()
    }

    // MARK: - Formatter Creation

    /// Create a day key formatter (yyyy-MM-dd)
    private static func createDayKeyFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    /// Create a monthly key formatter (yyyy-MM)
    private static func createMonthlyKeyFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    /// Create a backup timestamp formatter (yyyy-MM-dd_HHmm)
    private static func createBackupTimestampFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    // MARK: - Day Key Formatting

    /// Generate a cache-friendly day key for a given date
    ///
    /// Format: `yyyy-MM-dd` (e.g., "2025-10-10")
    ///
    /// - Parameters:
    ///   - date: The date to format
    ///   - timeZone: The time zone to use (defaults to current)
    /// - Returns: A string key in format "yyyy-MM-dd"
    ///
    /// - Note: Creates a new DateFormatter for thread safety
    static func dayKey(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = createDayKeyFormatter(timeZone: timeZone)
        return formatter.string(from: date)
    }

    /// Generate a monthly key for a given date
    ///
    /// Format: `yyyy-MM` (e.g., "2025-10")
    ///
    /// - Parameters:
    ///   - date: The date to format
    ///   - timeZone: The time zone to use (defaults to current)
    /// - Returns: A string key in format "yyyy-MM"
    static func monthlyKey(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = createMonthlyKeyFormatter(timeZone: timeZone)
        return formatter.string(from: date)
    }

    /// Generate a backup timestamp for a given date
    ///
    /// Format: `yyyy-MM-dd_HHmm` (e.g., "2025-10-10_1430")
    ///
    /// - Parameters:
    ///   - date: The date to format
    ///   - timeZone: The time zone to use (defaults to current)
    /// - Returns: A string timestamp in format "yyyy-MM-dd_HHmm"
    static func backupTimestamp(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = createBackupTimestampFormatter(timeZone: timeZone)
        return formatter.string(from: date)
    }

    // MARK: - Day Bounds Calculation

    /// Calculate the start and end of a calendar day
    ///
    /// Returns a tuple with:
    /// - `start`: The start of the day (00:00:00)
    /// - `end`: The start of the next day (00:00:00 next day)
    ///
    /// - Parameters:
    ///   - date: The date to calculate bounds for
    ///   - calendar: The calendar to use (defaults to current)
    /// - Returns: A tuple containing the start and end dates
    ///
    /// - Note: This is DST-safe and handles all edge cases
    static func dayBounds(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return (start, end)
    }

    // MARK: - Lookback Windows

    /// Calculate a date N days before the given date
    ///
    /// - Parameters:
    ///   - date: The reference date (defaults to now)
    ///   - days: Number of days to look back (must be positive)
    ///   - calendar: The calendar to use (defaults to current)
    /// - Returns: The date N days before the reference date, or the reference date if calculation fails
    ///
    /// - Note: This handles DST changes and month boundaries correctly
    static func lookbackDate(from date: Date = Date(), days: Int, calendar: Calendar = .current) -> Date {
        guard days > 0 else { return date }
        return calendar.date(byAdding: .day, value: -days, to: date) ?? date
    }

    /// Calculate a date N hours before the given date
    ///
    /// - Parameters:
    ///   - date: The reference date (defaults to now)
    ///   - hours: Number of hours to look back (must be positive)
    ///   - calendar: The calendar to use (defaults to current)
    /// - Returns: The date N hours before the reference date, or the reference date if calculation fails
    static func lookbackDate(from date: Date = Date(), hours: Int, calendar: Calendar = .current) -> Date {
        guard hours > 0 else { return date }
        return calendar.date(byAdding: .hour, value: -hours, to: date) ?? date
    }

    /// Calculate a time interval in seconds for a lookback period
    ///
    /// - Parameter days: Number of days
    /// - Returns: TimeInterval in seconds
    static func lookbackInterval(days: Int) -> TimeInterval {
        Double(days) * 24 * 3600
    }

    /// Calculate a time interval in seconds for a lookback period
    ///
    /// - Parameter hours: Number of hours
    /// - Returns: TimeInterval in seconds
    static func lookbackInterval(hours: Int) -> TimeInterval {
        Double(hours) * 3600
    }
}
