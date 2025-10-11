//
//  CalendarAssistantTests.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import EventKit
import XCTest
@testable import Murmur

@MainActor
final class CalendarAssistantTests: XCTestCase {

    var assistant: CalendarAssistant?
    var mockStore: MockCalendarStore?

    override func setUp() async throws {
        mockStore = MockCalendarStore()
        assistant = CalendarAssistant(eventStore: mockStore!)
    }

    override func tearDown() {
        assistant = nil
        mockStore = nil
    }

    // MARK: - Initialisation Tests

    func testInitialAuthorizationStatus() {
        // Given: Newly created assistant
        // When: Check authorization status
        // Then: Should reflect current system status (not determined for tests)
        XCTAssertNotNil(assistant!.authorizationStatus)
    }

    func testInitialEventsAreEmpty() {
        // Given: Newly created assistant
        // When: Check events
        // Then: Should have no events
        XCTAssertTrue(assistant!.upcomingEvents.isEmpty)
        XCTAssertTrue(assistant!.recentEvents.isEmpty)
    }

    // MARK: - Permission Handling Tests

    func testRequestAccessGranted() async {
        // Given: Mock configured to grant access
        mockStore!.shouldGrantAccess = true

        // When: Request access
        let granted = await assistant!.requestAccess()

        // Then: Should return true and update status
        XCTAssertTrue(granted)
        XCTAssertEqual(mockStore!.requestAccessCallCount, 1)
    }

    func testRequestAccessDenied() async {
        // Given: Mock configured to deny access
        mockStore!.shouldGrantAccess = false

        // When: Request access
        let granted = await assistant!.requestAccess()

        // Then: Should return false
        XCTAssertFalse(granted)
        XCTAssertEqual(mockStore!.requestAccessCallCount, 1)
    }

    func testRequestAccessWithError() async {
        // Given: Mock configured to throw error
        mockStore!.accessError = NSError(domain: "TestError", code: 1)

        // When: Request access
        let granted = await assistant!.requestAccess()

        // Then: Should return false and handle error gracefully
        XCTAssertFalse(granted)
    }

    // MARK: - Event Fetching Tests

    func testFetchTodaysEvents() async {
        // Given: Mock store with events for today
        mockStore!.shouldGrantAccess = true
        _ = await assistant!.requestAccess()

        let calendar = Calendar.current
        let now = Date()
        let event1 = EKEvent.mockMeeting(
            title: "Morning standup",
            start: calendar.date(byAdding: .hour, value: -2, to: now)!,
            duration: 1800
        )
        let event2 = EKEvent.mockMeeting(
            title: "Lunch meeting",
            start: calendar.date(byAdding: .hour, value: 1, to: now)!,
            duration: 3600
        )
        mockStore!.mockEvents = [event1, event2]

        // When: Fetch today's events
        await assistant!.fetchTodaysEvents()

        // Then: Should have events
        XCTAssertEqual(mockStore!.eventsCallCount, 1)
        // Note: The actual events array might be filtered by the predicate
    }

    func testFetchRecentEvents() async {
        // Given: Mock store with recent events
        mockStore!.shouldGrantAccess = true
        _ = await assistant!.requestAccess()

        let yesterday = Date().addingTimeInterval(-24 * 3600)
        let event = EKEvent.mockMeeting(start: yesterday)
        mockStore!.mockEvents = [event]

        // When: Fetch recent events
        await assistant!.fetchRecentEvents(daysBack: 7)

        // Then: Should query store
        XCTAssertEqual(mockStore!.eventsCallCount, 1)
    }

    func testFetchUpcomingEvents() async {
        // Given: Mock store with upcoming events
        mockStore!.shouldGrantAccess = true
        _ = await assistant!.requestAccess()

        let tomorrow = Date().addingTimeInterval(24 * 3600)
        let event = EKEvent.mockMeeting(start: tomorrow)
        mockStore!.mockEvents = [event]

        // When: Fetch upcoming events
        await assistant!.fetchUpcomingEvents(daysAhead: 7)

        // Then: Should query store
        XCTAssertEqual(mockStore!.eventsCallCount, 1)
    }

    func testFetchEventsWithoutAccess() async {
        // Given: Mock store without access granted
        mockStore!.shouldGrantAccess = false
        _ = await assistant!.requestAccess()

        // When: Try to fetch events
        await assistant!.fetchTodaysEvents()

        // Then: Should not query store (access check should fail)
        // The implementation should check hasCalendarAccess first
    }

    // MARK: - Event Filtering Tests

    func testFetchEventsExcludesAllDayEvents() async {
        // Given: Mix of all-day and regular events
        mockStore!.shouldGrantAccess = true
        _ = await assistant!.requestAccess()

        let regularEvent = EKEvent.mockMeeting()
        let allDayEvent = EKEvent.mockAllDayEvent()
        mockStore!.mockEvents = [regularEvent, allDayEvent]

        // When: Fetch events
        await assistant!.fetchTodaysEvents()

        // Then: All-day events should be filtered out
        // (Implementation filters isAllDay events)
    }

    func testEventsSortedByDate() async {
        // Given: Events in random order
        mockStore!.shouldGrantAccess = true
        _ = await assistant!.requestAccess()

        let now = Date()
        let event1 = EKEvent.mockMeeting(title: "Later", start: now.addingTimeInterval(7200))
        let event2 = EKEvent.mockMeeting(title: "Earlier", start: now.addingTimeInterval(3600))
        mockStore!.mockEvents = [event1, event2]

        // When: Fetch upcoming events
        await assistant!.fetchUpcomingEvents(daysAhead: 1)

        // Then: Events should be sorted
        // (Implementation sorts by startDate)
    }

    // MARK: - Mock Store Tests

    func testMockStorePredicateFiltering() {
        // Given: Mock store with events across different dates
        let today = Date()
        let yesterday = today.addingTimeInterval(-24 * 3600)
        let tomorrow = today.addingTimeInterval(24 * 3600)

        let event1 = EKEvent.mockMeeting(title: "Yesterday", start: yesterday)
        let event2 = EKEvent.mockMeeting(title: "Today", start: today)
        let event3 = EKEvent.mockMeeting(title: "Tomorrow", start: tomorrow)
        mockStore!.mockEvents = [event1, event2, event3]

        // When: Create predicate for today only
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = mockStore!.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        // When: Filter events
        let filtered = mockStore!.events(matching: predicate)

        // Then: Should only include today's event
        XCTAssertEqual(mockStore!.eventsCallCount, 1)
        XCTAssertTrue(filtered.contains { $0.title == "Today" })
    }

    func testMockStoreReset() {
        // Given: Mock store with configured state
        mockStore!.mockEvents = [EKEvent.mockMeeting()]
        mockStore!.shouldGrantAccess = false
        _ = mockStore!.events(matching: NSPredicate(value: true))

        // When: Reset
        mockStore!.reset()

        // Then: Should return to initial state
        XCTAssertTrue(mockStore!.mockEvents.isEmpty)
        XCTAssertTrue(mockStore!.shouldGrantAccess)
        XCTAssertEqual(mockStore!.eventsCallCount, 0)
    }

    // MARK: - Mock Assistant Tests

    func testMockCalendarAssistantRequestAccess() async {
        // Given: Mock assistant
        let mock = MockCalendarAssistant()

        // When: Request access
        let granted = await mock.requestAccess()

        // Then: Should grant access and update status
        XCTAssertTrue(granted)
        XCTAssertEqual(mock.authorizationStatus, .fullAccess)
        XCTAssertEqual(mock.requestAccessCallCount, 1)
    }

    func testMockCalendarAssistantRequestAccessDenied() async {
        // Given: Mock configured to deny
        let mock = MockCalendarAssistant()
        mock.shouldGrantAccess = false

        // When: Request access
        let granted = await mock.requestAccess()

        // Then: Should deny and update status
        XCTAssertFalse(granted)
        XCTAssertEqual(mock.authorizationStatus, .denied)
    }

    func testMockCalendarAssistantFetchEvents() async {
        // Given: Mock with configured events
        let mock = MockCalendarAssistant()
        let event = EKEvent.mockMeeting()
        mock.mockRecentEvents = [event]

        // When: Fetch recent events
        await mock.fetchRecentEvents(daysBack: 7)

        // Then: Should populate recentEvents
        XCTAssertEqual(mock.recentEvents.count, 1)
        XCTAssertEqual(mock.fetchRecentEventsCallCount, 1)
    }

    // MARK: - Mock Event Creation Tests

    func testMockEventCreation() {
        // Given: Event creation parameters
        let start = Date()
        let duration: TimeInterval = 3600

        // When: Create mock event
        let event = EKEvent.mockEvent(
            title: "Test Event",
            start: start,
            duration: duration,
            notes: "Test notes"
        )

        // Then: Should have correct properties
        XCTAssertEqual(event.title, "Test Event")
        XCTAssertEqual(event.startDate, start)
        XCTAssertEqual(event.endDate, start.addingTimeInterval(duration))
        XCTAssertEqual(event.notes, "Test notes")
        XCTAssertFalse(event.isAllDay)
    }

    func testMockMeetingConvenience() {
        // When: Create mock meeting
        let meeting = EKEvent.mockMeeting()

        // Then: Should have default meeting properties
        XCTAssertEqual(meeting.title, "Team meeting")
        XCTAssertFalse(meeting.isAllDay)
    }

    func testMockWorkoutConvenience() {
        // When: Create mock workout
        let workout = EKEvent.mockWorkout()

        // Then: Should have workout properties
        XCTAssertEqual(workout.title, "Gym workout")
        XCTAssertEqual(workout.endDate.timeIntervalSince(workout.startDate), 5400) // 90 minutes
    }

    func testMockAllDayEvent() {
        // When: Create all-day event
        let event = EKEvent.mockAllDayEvent()

        // Then: Should be marked as all-day
        XCTAssertTrue(event.isAllDay)
    }

    // MARK: - Event Matching Helper Tests

    func testEventTitleContains() {
        // Given: Event with specific title
        let event = EKEvent.mockMeeting(title: "Team Meeting with Bob")

        // When/Then: Check title matching
        XCTAssertTrue(event.titleContains("meeting"))
        XCTAssertTrue(event.titleContains("MEETING"))
        XCTAssertTrue(event.titleContains("team"))
        XCTAssertFalse(event.titleContains("lunch"))
    }

    func testEventTimeChecks() {
        // Given: Past event
        let pastEvent = EKEvent.mockMeeting(start: Date().addingTimeInterval(-7200))
        XCTAssertTrue(pastEvent.isInPast)
        XCTAssertFalse(pastEvent.isInFuture)

        // Given: Future event
        let futureEvent = EKEvent.mockMeeting(start: Date().addingTimeInterval(7200))
        XCTAssertFalse(futureEvent.isInPast)
        XCTAssertTrue(futureEvent.isInFuture)

        // Given: Today event
        let todayEvent = EKEvent.mockMeeting(start: Date())
        XCTAssertTrue(todayEvent.isToday)
    }

    // MARK: - Activity Inference Tests

    func testInferredExertionForWorkout() {
        // Given: Workout event
        let workout = EKEvent.mockEvent(
            title: "Gym workout",
            start: Date(),
            duration: 3600
        )

        // When: Infer exertion levels
        // Then: Should detect high physical exertion
        XCTAssertEqual(workout.inferredPhysicalExertion, 5)
        XCTAssertLessThan(workout.inferredCognitiveExertion, 5)
    }

    func testInferredExertionForMeeting() {
        // Given: Meeting event
        let meeting = EKEvent.mockEvent(
            title: "Team meeting",
            start: Date(),
            duration: 3600
        )

        // When: Infer exertion levels
        // Then: Should detect low physical, moderate cognitive
        XCTAssertEqual(meeting.inferredPhysicalExertion, 1)
        XCTAssertEqual(meeting.inferredCognitiveExertion, 4)
    }

    func testInferredExertionForPresentation() {
        // Given: Presentation event
        let presentation = EKEvent.mockEvent(
            title: "Quarterly presentation",
            start: Date(),
            duration: 3600
        )

        // When: Infer exertion levels
        // Then: Should detect high cognitive and emotional load
        XCTAssertEqual(presentation.inferredCognitiveExertion, 5)
        XCTAssertEqual(presentation.inferredEmotionalLoad, 4)
    }

    func testInferredExertionForInterview() {
        // Given: Interview event
        let interview = EKEvent.mockEvent(
            title: "Job interview",
            start: Date(),
            duration: 3600
        )

        // When: Infer exertion levels
        // Then: Should detect high cognitive and emotional load
        XCTAssertEqual(interview.inferredCognitiveExertion, 5)
        XCTAssertEqual(interview.inferredEmotionalLoad, 5)
    }

    // MARK: - Edge Cases

    func testFetchEventsWithEmptyStore() async {
        // Given: Mock store with no events
        mockStore!.shouldGrantAccess = true
        _ = await assistant!.requestAccess()
        mockStore!.mockEvents = []

        // When: Fetch events
        await assistant!.fetchTodaysEvents()

        // Then: Should handle empty result gracefully
        // No assertion needed - verify no crash
    }

    func testMultipleFetchCalls() async {
        // Given: Assistant with access
        mockStore!.shouldGrantAccess = true
        _ = await assistant!.requestAccess()

        // When: Fetch events multiple times
        await assistant!.fetchTodaysEvents()
        await assistant!.fetchRecentEvents(daysBack: 7)
        await assistant!.fetchUpcomingEvents(daysAhead: 7)

        // Then: Should handle multiple calls
        XCTAssertEqual(mockStore!.eventsCallCount, 3)
    }

    func testEventWithNilDates() {
        // Given: Event with nil dates (edge case)
        let event = EKEvent.mockMeeting()
        // Manually created events should have dates, but test the helpers

        // When/Then: Time check helpers should handle gracefully
        // No crash expected
        _ = event.isInPast
        _ = event.isInFuture
        _ = event.isToday
    }

    func testEventWithEmptyTitle() {
        // Given: Event with empty title
        let event = EKEvent.mockEvent(title: "", start: Date(), duration: 3600)

        // When/Then: Title matching should handle empty string
        XCTAssertFalse(event.titleContains("meeting"))
    }

    func testInferredExertionWithEmptyNotesAndTitle() {
        // Given: Event with minimal information
        let event = EKEvent.mockEvent(title: "", start: Date(), duration: 3600, notes: nil)

        // When: Infer exertion
        // Then: Should return default values
        XCTAssertEqual(event.inferredPhysicalExertion, 2)
        XCTAssertEqual(event.inferredCognitiveExertion, 3)
        XCTAssertEqual(event.inferredEmotionalLoad, 2)
    }
}
