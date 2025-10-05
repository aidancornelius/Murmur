//
//  NaturalLanguageParser.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 05/10/2025.
//

import Foundation

struct ParsedActivityInput {
    var cleanedText: String
    var timestamp: Date?
    var durationMinutes: Int?
}

struct NaturalLanguageParser {

    /// Parses natural language input for time, date, and duration hints
    static func parse(_ input: String) -> ParsedActivityInput {
        var cleanedText = input
        var timestamp: Date? = nil
        var durationMinutes: Int? = nil

        let calendar = Calendar.current
        let now = Date()

        // Parse time patterns (e.g., "at 3pm", "at 15:00", "@3pm")
        let timePatterns = [
            // 12-hour format with am/pm
            #"(?:at|@)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#,
            // 24-hour format
            #"(?:at|@)\s*(\d{1,2}):(\d{2})"#,
            // Just hour with am/pm
            #"(\d{1,2})\s*(am|pm)"#
        ]

        for pattern in timePatterns {
            if let match = input.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchedString = String(input[match])
                if let parsedDate = parseTime(from: matchedString, baseDate: timestamp ?? now) {
                    timestamp = parsedDate
                    cleanedText = cleanedText.replacingOccurrences(of: matchedString, with: "", options: [.regularExpression, .caseInsensitive])
                }
                break
            }
        }

        // Parse date patterns (e.g., "yesterday", "today", "tomorrow")
        let datePatterns: [(pattern: String, dayOffset: Int)] = [
            ("yesterday", -1),
            ("today", 0),
            ("tomorrow", 1)
        ]

        for (pattern, dayOffset) in datePatterns {
            if input.range(of: "\\b\(pattern)\\b", options: [.regularExpression, .caseInsensitive]) != nil {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: now) {
                    if let existingTimestamp = timestamp {
                        // Combine the parsed time with the new date
                        let timeComponents = calendar.dateComponents([.hour, .minute], from: existingTimestamp)
                        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                        var combined = DateComponents()
                        combined.year = dateComponents.year
                        combined.month = dateComponents.month
                        combined.day = dateComponents.day
                        combined.hour = timeComponents.hour
                        combined.minute = timeComponents.minute
                        timestamp = calendar.date(from: combined)
                    } else {
                        timestamp = date
                    }
                    cleanedText = cleanedText.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
                }
                break
            }
        }

        // Parse duration patterns (e.g., "for 2 hours", "30min", "1h 30m", "90 minutes")
        let durationPatterns = [
            // "for X hours/minutes/hrs/mins"
            #"(?:for\s+)?(\d+)\s*(?:hours?|hrs?|h)\s*(?:(\d+)\s*(?:minutes?|mins?|m))?"#,
            // "for X minutes/mins"
            #"(?:for\s+)?(\d+)\s*(?:minutes?|mins?|m)(?!\s*(?:hours?|hrs?|h))"#
        ]

        for (index, pattern) in durationPatterns.enumerated() {
            if let match = input.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchedString = String(input[match])
                if let duration = parseDuration(from: matchedString, patternIndex: index) {
                    durationMinutes = duration
                    cleanedText = cleanedText.replacingOccurrences(of: matchedString, with: "", options: [.regularExpression, .caseInsensitive])
                }
                break
            }
        }

        // Clean up extra whitespace
        cleanedText = cleanedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return ParsedActivityInput(
            cleanedText: cleanedText,
            timestamp: timestamp,
            durationMinutes: durationMinutes
        )
    }

    private static func parseTime(from string: String, baseDate: Date) -> Date? {
        let calendar = Calendar.current
        let cleanString = string.lowercased()
            .replacingOccurrences(of: "at", with: "")
            .replacingOccurrences(of: "@", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Try to extract hour, minute, and am/pm
        let regex = try? NSRegularExpression(pattern: #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"#, options: .caseInsensitive)
        guard let match = regex?.firstMatch(in: cleanString, range: NSRange(cleanString.startIndex..., in: cleanString)) else {
            return nil
        }

        guard let hourRange = Range(match.range(at: 1), in: cleanString),
              let hour = Int(cleanString[hourRange]) else {
            return nil
        }

        var minute = 0
        if match.range(at: 2).location != NSNotFound,
           let minuteRange = Range(match.range(at: 2), in: cleanString),
           let parsedMinute = Int(cleanString[minuteRange]) {
            minute = parsedMinute
        }

        var adjustedHour = hour
        if match.range(at: 3).location != NSNotFound,
           let amPmRange = Range(match.range(at: 3), in: cleanString) {
            let amPm = String(cleanString[amPmRange]).lowercased()
            if amPm == "pm" && hour != 12 {
                adjustedHour = hour + 12
            } else if amPm == "am" && hour == 12 {
                adjustedHour = 0
            }
        }

        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = adjustedHour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components)
    }

    private static func parseDuration(from string: String, patternIndex: Int) -> Int? {
        let cleanString = string.lowercased()
            .replacingOccurrences(of: "for", with: "")
            .trimmingCharacters(in: .whitespaces)

        if patternIndex == 0 {
            // Pattern: hours (and optionally minutes)
            let regex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:hours?|hrs?|h)\s*(?:(\d+)\s*(?:minutes?|mins?|m))?"#, options: .caseInsensitive)
            guard let match = regex?.firstMatch(in: cleanString, range: NSRange(cleanString.startIndex..., in: cleanString)) else {
                return nil
            }

            guard let hoursRange = Range(match.range(at: 1), in: cleanString),
                  let hours = Int(cleanString[hoursRange]) else {
                return nil
            }

            var totalMinutes = hours * 60

            if match.range(at: 2).location != NSNotFound,
               let minutesRange = Range(match.range(at: 2), in: cleanString),
               let minutes = Int(cleanString[minutesRange]) {
                totalMinutes += minutes
            }

            return totalMinutes
        } else {
            // Pattern: just minutes
            let regex = try? NSRegularExpression(pattern: #"(\d+)"#, options: .caseInsensitive)
            guard let match = regex?.firstMatch(in: cleanString, range: NSRange(cleanString.startIndex..., in: cleanString)) else {
                return nil
            }

            guard let minutesRange = Range(match.range, in: cleanString),
                  let minutes = Int(cleanString[minutesRange]) else {
                return nil
            }

            return minutes
        }
    }
}
