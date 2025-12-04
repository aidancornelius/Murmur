// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// NaturalLanguageParser.swift
// Created by Aidan Cornelius-Bell on 05/10/2025.
// Parser for natural language symptom input.
//
import Foundation

enum DetectedEventType {
    case activity
    case sleep
    case meal
    case unknown
}

struct ParsedActivityInput {
    var cleanedText: String
    var timestamp: Date?
    var durationMinutes: Int?
    var detectedType: DetectedEventType = .unknown

    // Sleep-specific
    var bedTime: Date?
    var wakeTime: Date?
    var sleepQuality: Int?

    // Meal-specific
    var mealType: String?

    // Activity-specific
    var physicalExertion: Int?
    var cognitiveExertion: Int?
    var emotionalLoad: Int?
}

struct NaturalLanguageParser {

    // Keywords for event type detection
    private static let sleepKeywords = ["slept", "sleep", "nap", "rest", "bed", "wake", "woke", "awake", "tired", "insomnia", "nightmare", "dream"]
    private static let mealKeywords = ["ate", "eat", "food", "meal", "breakfast", "lunch", "dinner", "snack", "drink", "drank", "coffee", "tea"]
    private static let activityKeywords = ["ran", "run", "walk", "walked", "gym", "workout", "exercise", "yoga", "pilates", "swim", "cycle", "bike", "hike", "stretch", "stretching", "meditation", "meditate", "meeting", "work", "study", "studied", "read", "reading", "watch", "watched", "play", "played", "drive", "drove", "driving", "shopping", "cleaned", "cleaning"]

    // Meal type detection
    private static let breakfastKeywords = ["breakfast", "morning", "cereal", "toast", "eggs", "bacon", "coffee"]
    private static let lunchKeywords = ["lunch", "midday", "sandwich", "salad"]
    private static let dinnerKeywords = ["dinner", "supper", "evening meal"]
    private static let snackKeywords = ["snack", "quick bite", "nibble"]

    // Exertion keywords
    private static let highPhysicalKeywords = ["intense", "exhausting", "vigorous", "hard", "strenuous", "sprint", "heavy"]
    private static let lowPhysicalKeywords = ["light", "easy", "gentle", "relaxed", "slow"]

    /// Detects the type of event from input text
    static func detectEventType(_ input: String, isFromCalendar: Bool = false) -> DetectedEventType {
        let lowercased = input.lowercased()

        // Check for sleep patterns
        if sleepKeywords.contains(where: lowercased.contains) {
            return .sleep
        }

        // Check for meal patterns
        if mealKeywords.contains(where: lowercased.contains) {
            return .meal
        }

        // Check for activity patterns
        if activityKeywords.contains(where: lowercased.contains) {
            return .activity
        }

        // If this is from a calendar event and no specific keywords found,
        // default to activity (most calendar events are activities/meetings)
        if isFromCalendar {
            return .activity
        }

        // Check for time-based hints only if NOT from calendar
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: DateUtility.now())

        // If it mentions morning/night times, might be sleep
        if lowercased.contains("hours") && (hour < 9 || hour > 21) {
            return .sleep
        }

        // Default based on time of day (only when not from calendar)
        // Be much more conservative about meal detection - only at explicit meal times
        switch hour {
        case 4..<8:
            // 4am-8am: Almost certainly logging sleep
            return .sleep
        case 8..<9:
            // 8-9am could be breakfast but default to activity unless meal keywords present
            return .activity
        case 12..<13:
            // Only noon hour suggests meal, not the entire lunch window
            return .meal // Lunch time
        case 18..<19:
            // Only dinner hour suggests meal
            return .meal // Dinner time
        case 21..<24, 0..<4:
            return .sleep // Late night sleep time
        default:
            // Default to activity for all other times
            return .activity
        }
    }

    /// Parses natural language input for time, date, and duration hints
    static func parse(_ input: String, isFromCalendar: Bool = false) -> ParsedActivityInput {
        var cleanedText = input
        var timestamp: Date? = nil
        var durationMinutes: Int? = nil
        var bedTime: Date? = nil
        var wakeTime: Date? = nil
        var sleepQuality: Int? = nil
        var mealType: String? = nil
        var physicalExertion: Int? = nil
        var cognitiveExertion: Int? = nil
        var emotionalLoad: Int? = nil

        let calendar = Calendar.current
        let now = DateUtility.now()

        // Detect event type
        let detectedType = detectEventType(input, isFromCalendar: isFromCalendar)

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

        // Parse sleep-specific patterns
        if detectedType == .sleep {
            // Parse "slept 8 hours" or "slept from 10pm to 6am"
            if let sleepHours = extractSleepHours(from: input) {
                durationMinutes = sleepHours * 60
                // Calculate approximate bed/wake times
                let wake = timestamp ?? now
                wakeTime = wake
                bedTime = calendar.date(byAdding: .minute, value: -(sleepHours * 60), to: wake)
            }

            // Parse sleep quality
            sleepQuality = extractSleepQuality(from: input)
        }

        // Parse meal-specific patterns
        if detectedType == .meal {
            mealType = detectMealType(input)
        }

        // Parse exertion levels for activities
        if detectedType == .activity {
            physicalExertion = extractPhysicalExertion(from: input)
            // Default others to moderate if activity is detected
            cognitiveExertion = 3
            emotionalLoad = 3
        }

        // Clean up extra whitespace
        cleanedText = cleanedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return ParsedActivityInput(
            cleanedText: cleanedText,
            timestamp: timestamp,
            durationMinutes: durationMinutes,
            detectedType: detectedType,
            bedTime: bedTime,
            wakeTime: wakeTime,
            sleepQuality: sleepQuality,
            mealType: mealType,
            physicalExertion: physicalExertion,
            cognitiveExertion: cognitiveExertion,
            emotionalLoad: emotionalLoad
        )
    }

    private static func extractSleepHours(from input: String) -> Int? {
        let patterns = [
            #"slept?\s+(?:for\s+)?(\d+)\s*(?:hours?|hrs?)"#,
            #"(\d+)\s*(?:hours?|hrs?)\s+(?:of\s+)?sleep"#
        ]

        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            if let match = regex?.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
               let range = Range(match.range(at: 1), in: input),
               let hours = Int(input[range]) {
                return hours
            }
        }
        return nil
    }

    private static func extractSleepQuality(from input: String) -> Int? {
        let lowercased = input.lowercased()
        if lowercased.contains("terrible") || lowercased.contains("awful") || lowercased.contains("poor") {
            return 1
        } else if lowercased.contains("bad") || lowercased.contains("restless") {
            return 2
        } else if lowercased.contains("okay") || lowercased.contains("decent") {
            return 3
        } else if lowercased.contains("good") || lowercased.contains("well") {
            return 4
        } else if lowercased.contains("great") || lowercased.contains("excellent") || lowercased.contains("amazing") {
            return 5
        }
        return nil
    }

    private static func detectMealType(_ input: String) -> String {
        let lowercased = input.lowercased()

        if breakfastKeywords.contains(where: lowercased.contains) {
            return "breakfast"
        } else if lunchKeywords.contains(where: lowercased.contains) {
            return "lunch"
        } else if dinnerKeywords.contains(where: lowercased.contains) {
            return "dinner"
        } else if snackKeywords.contains(where: lowercased.contains) {
            return "snack"
        }

        // Default based on time
        let hour = Calendar.current.component(.hour, from: DateUtility.now())
        switch hour {
        case 5..<11: return "breakfast"
        case 11..<16: return "lunch"
        case 16..<22: return "dinner"
        default: return "snack"
        }
    }

    private static func extractPhysicalExertion(from input: String) -> Int? {
        let lowercased = input.lowercased()

        if highPhysicalKeywords.contains(where: lowercased.contains) {
            return 4
        } else if lowPhysicalKeywords.contains(where: lowercased.contains) {
            return 2
        }

        // Activity-specific defaults
        if lowercased.contains("sprint") || lowercased.contains("hiit") {
            return 5
        } else if lowercased.contains("run") || lowercased.contains("gym") {
            return 4
        } else if lowercased.contains("walk") || lowercased.contains("yoga") {
            return 2
        }

        return nil
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
