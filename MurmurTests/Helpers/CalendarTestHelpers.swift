//
//  CalendarTestHelpers.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import EventKit
import XCTest
@testable import Murmur

// MARK: - Mock CalendarStore

/// Mock implementation of CalendarStoreProtocol for testing
@MainActor
final class MockCalendarStore: CalendarStoreProtocol {

    // MARK: - Mock Configuration

    var mockEvents: [EKEvent] = []
    var shouldGrantAccess = true
    var accessError: Error?
    private var _authorizationStatus: EKAuthorizationStatus = .notDetermined

    // MARK: - CalendarStoreProtocol Properties

    var authorizationStatus: EKAuthorizationStatus {
        return _authorizationStatus
    }

    // MARK: - Tracking

    private(set) var requestAccessCallCount = 0
    private(set) var eventsCallCount = 0
    private(set) var lastPredicate: NSPredicate?
    private(set) var lastStartDate: Date?
    private(set) var lastEndDate: Date?

    // MARK: - CalendarStoreProtocol Implementation

    func requestAccess() async throws -> Bool {
        requestAccessCallCount += 1

        if let error = accessError {
            throw error
        }

        // Update authorization status based on whether access was granted
        if shouldGrantAccess {
            _authorizationStatus = .fullAccess
        } else {
            _authorizationStatus = .denied
        }

        return shouldGrantAccess
    }

    func events(matching predicate: NSPredicate) -> [EKEvent] {
        eventsCallCount += 1
        lastPredicate = predicate

        // Since we can't easily inspect block-based predicates,
        // use the stored date range from predicateForEvents
        if let start = lastStartDate, let end = lastEndDate {
            return mockEvents.filter { event in
                guard let eventStart = event.startDate, let eventEnd = event.endDate else {
                    return false
                }
                // Check if event overlaps with the requested range
                return eventEnd >= start && eventStart < end
            }
        }

        // Fallback: return all events if no date range was set
        return mockEvents
    }

    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate {
        // Store the date range for use in events(matching:)
        lastStartDate = startDate
        lastEndDate = endDate

        // Create a predicate that checks if event overlaps with date range
        // Note: This predicate won't actually be evaluated in tests since
        // we use the stored date range directly in events(matching:)
        return NSPredicate { object, _ in
            guard let event = object as? EKEvent else { return false }

            // Check if event overlaps with the requested range
            let eventStart = event.startDate ?? Date.distantPast
            let eventEnd = event.endDate ?? eventStart

            return eventEnd >= startDate && eventStart < endDate
        }
    }

    // MARK: - Reset

    func reset() {
        mockEvents.removeAll()
        shouldGrantAccess = true
        accessError = nil
        _authorizationStatus = .notDetermined
        requestAccessCallCount = 0
        eventsCallCount = 0
        lastPredicate = nil
        lastStartDate = nil
        lastEndDate = nil
    }
}

// MARK: - Mock CalendarAssistant

/// Mock implementation of CalendarAssistantProtocol for testing
@MainActor
final class MockCalendarAssistant: CalendarAssistantProtocol {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var upcomingEvents: [EKEvent] = []
    @Published private(set) var recentEvents: [EKEvent] = []

    var shouldGrantAccess = true
    var mockRecentEvents: [EKEvent] = []
    var mockUpcomingEvents: [EKEvent] = []

    private(set) var requestAccessCallCount = 0
    private(set) var fetchRecentEventsCallCount = 0
    private(set) var fetchUpcomingEventsCallCount = 0
    private(set) var fetchTodaysEventsCallCount = 0

    func requestAccess() async -> Bool {
        requestAccessCallCount += 1

        if shouldGrantAccess {
            authorizationStatus = .fullAccess
            return true
        } else {
            authorizationStatus = .denied
            return false
        }
    }

    func fetchRecentEvents(daysBack: Int) async {
        fetchRecentEventsCallCount += 1
        recentEvents = mockRecentEvents
    }

    func fetchUpcomingEvents(daysAhead: Int) async {
        fetchUpcomingEventsCallCount += 1
        upcomingEvents = mockUpcomingEvents
    }

    func fetchTodaysEvents() async {
        fetchTodaysEventsCallCount += 1
        recentEvents = mockRecentEvents
    }

    func reset() {
        authorizationStatus = .notDetermined
        upcomingEvents = []
        recentEvents = []
        shouldGrantAccess = true
        mockRecentEvents = []
        mockUpcomingEvents = []
        requestAccessCallCount = 0
        fetchRecentEventsCallCount = 0
        fetchUpcomingEventsCallCount = 0
        fetchTodaysEventsCallCount = 0
    }
}

// MARK: - Mock EKEvent Creation

extension EKEvent {
    /// Create a mock calendar event for testing
    /// Note: EKEvent is difficult to mock due to being part of EventKit
    /// This uses a real EKEventStore for creation but events won't be persisted
    static func mockEvent(
        title: String,
        start: Date,
        duration: TimeInterval,
        notes: String? = nil,
        isAllDay: Bool = false,
        eventID: String? = nil
    ) -> EKEvent {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(duration)
        event.notes = notes
        event.isAllDay = isAllDay

        // Note: EKEvent.eventIdentifier is read-only and generated by the store
        // We can't set it directly, so tests should use title-based matching

        return event
    }

    /// Convenience method for creating a meeting event
    static func mockMeeting(
        title: String = "Team meeting",
        start: Date = Date(),
        duration: TimeInterval = 3600
    ) -> EKEvent {
        mockEvent(title: title, start: start, duration: duration)
    }

    /// Convenience method for creating a workout event
    static func mockWorkout(
        title: String = "Gym workout",
        start: Date = Date(),
        duration: TimeInterval = 5400 // 90 minutes
    ) -> EKEvent {
        mockEvent(title: title, start: start, duration: duration)
    }

    /// Convenience method for creating an all-day event
    static func mockAllDayEvent(
        title: String = "All day event",
        date: Date = Date()
    ) -> EKEvent {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return mockEvent(title: title, start: startOfDay, duration: 24 * 3600, isAllDay: true)
    }

    /// Convenience method for creating a recurring meeting
    static func mockRecurringMeeting(
        title: String = "Weekly standup",
        start: Date = Date()
    ) -> EKEvent {
        let event = mockEvent(title: title, start: start, duration: 1800) // 30 minutes
        // Note: EKRecurrenceRule would require more complex setup
        // For testing purposes, we can create multiple events instead
        return event
    }
}

// MARK: - Event Matching Helpers

extension EKEvent {
    /// Check if event title contains a keyword (case insensitive)
    func titleContains(_ keyword: String) -> Bool {
        title?.localizedCaseInsensitiveContains(keyword) ?? false
    }

    /// Check if event is in the past
    var isInPast: Bool {
        guard let end = endDate else { return false }
        return end < Date()
    }

    /// Check if event is in the future
    var isInFuture: Bool {
        guard let start = startDate else { return false }
        return start > Date()
    }

    /// Check if event is happening today
    var isToday: Bool {
        guard let start = startDate else { return false }
        return Calendar.current.isDateInToday(start)
    }
}

// MARK: - Activity Event Category Inference (for testing)

extension EKEvent {
    /// Infer physical exertion level based on title/notes keywords
    var inferredPhysicalExertion: Int16 {
        let content = "\(title ?? "") \(notes ?? "")".lowercased()

        if content.contains("workout") || content.contains("gym") || content.contains("run") || content.contains("exercise") {
            return 5
        } else if content.contains("walk") || content.contains("yoga") {
            return 3
        } else if content.contains("meeting") || content.contains("call") {
            return 1
        }

        return 2 // Default
    }

    /// Infer cognitive exertion level based on title/notes keywords
    var inferredCognitiveExertion: Int16 {
        let content = "\(title ?? "") \(notes ?? "")".lowercased()

        if content.contains("presentation") || content.contains("interview") || content.contains("exam") {
            return 5
        } else if content.contains("meeting") || content.contains("planning") {
            return 4
        } else if content.contains("workout") || content.contains("gym") {
            return 2
        }

        return 3 // Default
    }

    /// Infer emotional load based on title/notes keywords
    var inferredEmotionalLoad: Int16 {
        let content = "\(title ?? "") \(notes ?? "")".lowercased()

        if content.contains("interview") || content.contains("performance review") || content.contains("conflict") {
            return 5
        } else if content.contains("presentation") || content.contains("deadline") {
            return 4
        } else if content.contains("social") || content.contains("party") {
            return 3
        }

        return 2 // Default
    }
}
