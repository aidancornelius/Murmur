//
//  NaturalLanguageParserTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 05/10/2025.
//

import XCTest
@testable import Murmur

final class NaturalLanguageParserTests: XCTestCase {

    // MARK: - Time Parsing Tests

    func testParseSimpleTime12Hour() {
        let input = "Went for a walk at 3pm"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Went for a walk")
        XCTAssertNotNil(result.timestamp)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result.timestamp!)
        XCTAssertEqual(hour, 15)
    }

    func testParseTime24Hour() {
        let input = "Meeting at 14:30"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Meeting")
        XCTAssertNotNil(result.timestamp)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result.timestamp!)
        let minute = calendar.component(.minute, from: result.timestamp!)
        XCTAssertEqual(hour, 14)
        XCTAssertEqual(minute, 30)
    }

    func testParseTimeWithAtSymbol() {
        let input = "Gym @8am"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Gym")
        XCTAssertNotNil(result.timestamp)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result.timestamp!)
        XCTAssertEqual(hour, 8)
    }

    func testParseMidnight() {
        let input = "Night shift at 12am"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Night shift")
        XCTAssertNotNil(result.timestamp)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result.timestamp!)
        XCTAssertEqual(hour, 0)
    }

    func testParseNoon() {
        let input = "Lunch at 12pm"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Lunch")
        XCTAssertNotNil(result.timestamp)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result.timestamp!)
        XCTAssertEqual(hour, 12)
    }

    // MARK: - Date Parsing Tests

    func testParseYesterday() {
        let input = "Walk yesterday"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Walk")
        XCTAssertNotNil(result.timestamp)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let parsedDay = calendar.startOfDay(for: result.timestamp!)

        XCTAssertEqual(parsedDay, yesterday)
    }

    func testParseTomorrow() {
        let input = "Appointment tomorrow"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Appointment")
        XCTAssertNotNil(result.timestamp)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let parsedDay = calendar.startOfDay(for: result.timestamp!)

        XCTAssertEqual(parsedDay, tomorrow)
    }

    func testParseYesterdayWithTime() {
        let input = "Gym yesterday at 6pm"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Gym")
        XCTAssertNotNil(result.timestamp)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result.timestamp!)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let parsedDay = calendar.startOfDay(for: result.timestamp!)

        XCTAssertEqual(hour, 18)
        XCTAssertEqual(parsedDay, yesterday)
    }

    // MARK: - Duration Parsing Tests

    func testParseDurationInHours() {
        let input = "Meeting for 2 hours"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Meeting")
        XCTAssertEqual(result.durationMinutes, 120)
    }

    func testParseDurationInMinutes() {
        let input = "Call for 30 minutes"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Call")
        XCTAssertEqual(result.durationMinutes, 30)
    }

    func testParseDurationShortForm() {
        let input = "Workout for 45min"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Workout")
        XCTAssertEqual(result.durationMinutes, 45)
    }

    func testParseDurationHoursAndMinutes() {
        let input = "Trip for 2 hours 30 minutes"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Trip")
        XCTAssertEqual(result.durationMinutes, 150)
    }

    func testParseDurationShortFormCombined() {
        let input = "Hike for 1h 45m"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Hike")
        XCTAssertEqual(result.durationMinutes, 105)
    }

    // MARK: - Combined Parsing Tests

    func testParseTimeAndDuration() {
        let input = "Gym at 6pm for 1 hour"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Gym")
        XCTAssertNotNil(result.timestamp)
        XCTAssertEqual(result.durationMinutes, 60)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result.timestamp!)
        XCTAssertEqual(hour, 18)
    }

    func testParseDateAndTime() {
        let input = "Doctor yesterday at 10am"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Doctor")
        XCTAssertNotNil(result.timestamp)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result.timestamp!)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let parsedDay = calendar.startOfDay(for: result.timestamp!)

        XCTAssertEqual(hour, 10)
        XCTAssertEqual(parsedDay, yesterday)
    }

    func testParseAllThree() {
        let input = "Lunch yesterday at 1pm for 30min"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Lunch")
        XCTAssertNotNil(result.timestamp)
        XCTAssertEqual(result.durationMinutes, 30)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result.timestamp!)
        XCTAssertEqual(hour, 13)
    }

    // MARK: - Edge Cases

    func testParseNoTimeInfo() {
        let input = "Just a regular activity"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Just a regular activity")
        XCTAssertNil(result.timestamp)
        XCTAssertNil(result.durationMinutes)
    }

    func testParseEmptyString() {
        let input = ""
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "")
        XCTAssertNil(result.timestamp)
        XCTAssertNil(result.durationMinutes)
    }

    func testParseOnlyTime() {
        let input = "at 3pm"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "")
        XCTAssertNotNil(result.timestamp)
    }

    func testParseMultipleSpaces() {
        let input = "Walk    yesterday    at    3pm"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Walk")
        XCTAssertNotNil(result.timestamp)
    }

    func testParseCaseInsensitive() {
        let input = "Meeting AT 3PM YESTERDAY FOR 2 HOURS"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Meeting")
        XCTAssertNotNil(result.timestamp)
        XCTAssertEqual(result.durationMinutes, 120)
    }

    // MARK: - Real World Examples

    func testRealWorldExample1() {
        let input = "Morning walk for 30 minutes"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Morning walk")
        XCTAssertEqual(result.durationMinutes, 30)
    }

    func testRealWorldExample2() {
        let input = "Team meeting yesterday at 2pm for 1 hour"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Team meeting")
        XCTAssertNotNil(result.timestamp)
        XCTAssertEqual(result.durationMinutes, 60)
    }

    func testRealWorldExample3() {
        let input = "Gym @6am for 45min"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Gym")
        XCTAssertNotNil(result.timestamp)
        XCTAssertEqual(result.durationMinutes, 45)

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: result.timestamp!)
        XCTAssertEqual(hour, 6)
    }

    func testRealWorldExample4() {
        let input = "Lunch at noon"
        let result = NaturalLanguageParser.parse(input)

        XCTAssertEqual(result.cleanedText, "Lunch at noon")
        // "noon" is not currently parsed as a time, but "12pm" would be
    }
}
