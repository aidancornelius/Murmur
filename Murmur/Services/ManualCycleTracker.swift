import CoreData
import Foundation
import os.log

/// Manages manual cycle tracking for users who can't or don't want to use HealthKit
@MainActor
final class ManualCycleTracker: ObservableObject {
    private let logger = Logger(subsystem: "app.murmur", category: "ManualCycleTracker")
    private let context: NSManagedObjectContext

    @Published private(set) var latestCycleDay: Int?
    @Published private(set) var latestFlowLevel: String?
    @Published private(set) var isEnabled: Bool

    private let enabledKey = "ManualCycleTrackingEnabled"

    init(context: NSManagedObjectContext) {
        self.context = context
        self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        Task {
            await refreshCycleData()
        }
    }

    /// Enable or disable manual cycle tracking
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: enabledKey)

        if enabled {
            Task {
                await refreshCycleData()
            }
        } else {
            latestCycleDay = nil
            latestFlowLevel = nil
        }
    }

    /// Add a manual cycle entry
    func addEntry(date: Date, flowLevel: String) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Check if entry already exists for this date
        let request = ManualCycleEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            calendar.date(byAdding: .day, value: 1, to: startOfDay)! as NSDate
        )

        let existing = try context.fetch(request)
        if let existingEntry = existing.first {
            existingEntry.flowLevel = flowLevel
        } else {
            _ = ManualCycleEntry.create(date: startOfDay, flowLevel: flowLevel, in: context)
        }

        try context.save()

        Task {
            await refreshCycleData()
        }
    }

    /// Remove a manual cycle entry
    func removeEntry(date: Date) throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        let request = ManualCycleEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            calendar.date(byAdding: .day, value: 1, to: startOfDay)! as NSDate
        )

        let entries = try context.fetch(request)
        for entry in entries {
            context.delete(entry)
        }

        try context.save()

        Task {
            await refreshCycleData()
        }
    }

    /// Get the flow level for a specific date
    func flowLevel(for date: Date) -> String? {
        guard isEnabled else { return nil }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        let request = ManualCycleEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            calendar.date(byAdding: .day, value: 1, to: startOfDay)! as NSDate
        )
        request.fetchLimit = 1

        return try? context.fetch(request).first?.flowLevel
    }

    /// Refresh cycle day and flow level calculations
    func refreshCycleData() async {
        guard isEnabled else {
            latestCycleDay = nil
            latestFlowLevel = nil
            return
        }

        do {
            // Get entries from last 45 days
            let endDate = Date()
            let startDate = endDate.addingTimeInterval(-45 * 24 * 3600)
            let entries = try ManualCycleEntry.fetch(from: startDate, to: endDate, in: context)

            // Find most recent period start
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // Get today's flow level
            let todayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: today) }
            latestFlowLevel = todayEntries.first?.flowLevel

            // Calculate cycle day
            if let firstPeriodEntry = entries.first {
                let daysSinceStart = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: firstPeriodEntry.date),
                    to: today
                ).day ?? 0
                latestCycleDay = daysSinceStart + 1
            } else {
                latestCycleDay = nil
            }
        } catch {
            logger.error("Failed to refresh manual cycle data: \(error.localizedDescription)")
        }
    }

    /// Get all manual cycle entries
    func allEntries() throws -> [ManualCycleEntry] {
        try ManualCycleEntry.fetchAll(in: context)
    }
}
