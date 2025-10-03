import EventKit
import Foundation
import os.log

@MainActor
final class CalendarAssistant: ObservableObject {
    private let logger = Logger(subsystem: "app.murmur", category: "Calendar")
    private let eventStore = EKEventStore()

    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var upcomingEvents: [EKEvent] = []
    @Published private(set) var recentEvents: [EKEvent] = []

    init() {
        updateAuthorizationStatus()
    }

    private func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    private var hasCalendarAccess: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
        } else {
            return authorizationStatus == .authorized
        }
    }

    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                updateAuthorizationStatus()
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                updateAuthorizationStatus()
                return granted
            }
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
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        recentEvents = events.sorted { ($0.startDate ?? Date.distantPast) > ($1.startDate ?? Date.distantPast) }
    }

    func fetchUpcomingEvents(daysAhead: Int = 1) async {
        guard hasCalendarAccess else {
            logger.warning("Calendar access not granted")
            return
        }

        let calendar = Calendar.current
        let startDate = Date()
        guard let endDate = calendar.date(byAdding: .day, value: daysAhead, to: startDate) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        upcomingEvents = events.sorted { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
    }

    func fetchTodaysEvents() async {
        guard hasCalendarAccess else {
            logger.warning("Calendar access not granted")
            return
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        recentEvents = events.sorted { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
    }
}
