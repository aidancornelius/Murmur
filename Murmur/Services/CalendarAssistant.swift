// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// CalendarAssistant.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Service for interacting with the system calendar.
//
import Combine
import EventKit
import Foundation
import os.log

// MARK: - Protocols

/// Protocol for calendar services to enable dependency injection and testing
@MainActor
protocol CalendarAssistantProtocol: AnyObject {
    var authorizationStatus: EKAuthorizationStatus { get }
    var upcomingEvents: [EKEvent] { get }
    var recentEvents: [EKEvent] { get }
    func requestAccess() async -> Bool
    func fetchRecentEvents(daysBack: Int) async
    func fetchUpcomingEvents(daysAhead: Int) async
    func fetchTodaysEvents() async
}

/// Protocol abstraction for EKEventStore to enable testing with mock implementations
@MainActor
protocol CalendarStoreProtocol {
    var authorizationStatus: EKAuthorizationStatus { get }
    func requestAccess() async throws -> Bool
    func events(matching predicate: NSPredicate) -> [EKEvent]
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate
}

/// Wrapper for EKEventStore that conforms to CalendarStoreProtocol
@MainActor
final class EventStoreWrapper: CalendarStoreProtocol {
    private let store = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async throws -> Bool {
        return try await store.requestFullAccessToEvents()
    }

    func events(matching predicate: NSPredicate) -> [EKEvent] {
        store.events(matching: predicate)
    }

    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate {
        store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
    }
}

// MARK: - Implementation

@MainActor
final class CalendarAssistant: CalendarAssistantProtocol, ObservableObject {
    private let logger = Logger(subsystem: "app.murmur", category: "Calendar")
    private let eventStore: CalendarStoreProtocol

    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var upcomingEvents: [EKEvent] = []
    @Published private(set) var recentEvents: [EKEvent] = []

    init(eventStore: CalendarStoreProtocol? = nil) {
        self.eventStore = eventStore ?? EventStoreWrapper()
        updateAuthorizationStatus()
    }

    private func updateAuthorizationStatus() {
        authorizationStatus = eventStore.authorizationStatus
    }

    private var hasCalendarAccess: Bool {
        return authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestAccess()
            updateAuthorizationStatus()
            return granted
        } catch {
            logger.error("Calendar access request failed: \(error.localizedDescription)")
            return false
        }
    }

    func fetchRecentEvents(daysBack: Int = 7) async {
        guard hasCalendarAccess else {
            logger.warning("Calendar access not granted")
            return
        }

        let calendar = Calendar.current
        let endDate = DateUtility.now()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }

        recentEvents = events.sorted { ($0.startDate ?? Date.distantPast) > ($1.startDate ?? Date.distantPast) }
    }

    func fetchUpcomingEvents(daysAhead: Int = 1) async {
        guard hasCalendarAccess else {
            logger.warning("Calendar access not granted")
            return
        }

        let calendar = Calendar.current
        let startDate = DateUtility.now()
        guard let endDate = calendar.date(byAdding: .day, value: daysAhead, to: startDate) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }

        upcomingEvents = events.sorted { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
    }

    func fetchTodaysEvents() async {
        guard hasCalendarAccess else {
            logger.warning("Calendar access not granted")
            return
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: DateUtility.now())
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }

        recentEvents = events.sorted { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
    }
}

// MARK: - ResourceManageable conformance

extension CalendarAssistant: ResourceManageable {
    nonisolated func start() async throws {
        // Event store is initialised in init, no additional work required
    }

    nonisolated func cleanup() {
        Task { @MainActor in
            _cleanup()
        }
    }

    @MainActor
    private func _cleanup() {
        // Clear cached event data
        upcomingEvents.removeAll()
        recentEvents.removeAll()

        // Note: EKEventStore doesn't require explicit cleanup
        // but we clear references to allow memory reclamation
    }
}
