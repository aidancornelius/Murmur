//
//  ManualCycleTracker.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

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

    init(context: NSManagedObjectContext) {
        self.context = context
        self.isEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.manualCycleTrackingEnabled)
        Task {
            await refreshCycleData()
        }
    }

    /// Enable or disable manual cycle tracking
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: UserDefaultsKeys.manualCycleTrackingEnabled)

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

    /// Set the cycle day directly
    func setCycleDay(_ day: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        UserDefaults.standard.set(day, forKey: UserDefaultsKeys.currentCycleDay)
        UserDefaults.standard.set(today, forKey: UserDefaultsKeys.cycleDaySetDate)

        latestCycleDay = day
    }

    /// Clear the manually set cycle day
    func clearCycleDay() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.currentCycleDay)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.cycleDaySetDate)

        Task {
            await refreshCycleData()
        }
    }

    /// Refresh cycle day and flow level calculations
    func refreshCycleData() async {
        guard isEnabled else {
            latestCycleDay = nil
            latestFlowLevel = nil
            return
        }

        do {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // Check if user has manually set a cycle day
            if let setDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.cycleDaySetDate) as? Date,
               UserDefaults.standard.object(forKey: UserDefaultsKeys.currentCycleDay) != nil {
                let setDay = UserDefaults.standard.integer(forKey: UserDefaultsKeys.currentCycleDay)
                let daysSinceSet = calendar.dateComponents([.day], from: calendar.startOfDay(for: setDate), to: today).day ?? 0
                let calculatedDay = setDay + daysSinceSet

                // Validate the cycle day is within reasonable bounds
                if calculatedDay > 0 && calculatedDay <= AppConstants.Validation.maxCycleLength {
                    latestCycleDay = calculatedDay
                } else if calculatedDay > AppConstants.Validation.maxCycleLength {
                    // Reset if cycle exceeds max length
                    logger.warning("Cycle day \(calculatedDay) exceeds max length, resetting")
                    latestCycleDay = nil
                    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.currentCycleDay)
                    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.cycleDaySetDate)
                } else {
                    // Negative days are invalid
                    logger.warning("Invalid negative cycle day \(calculatedDay), resetting")
                    latestCycleDay = nil
                    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.currentCycleDay)
                    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.cycleDaySetDate)
                }
            } else {
                // Fall back to calculating from period entries
                let endDate = Date()
                let startDate = endDate.addingTimeInterval(-45 * 24 * 3600)
                let entries = try ManualCycleEntry.fetch(from: startDate, to: endDate, in: context)

                if let firstPeriodEntry = entries.first {
                    let daysSinceStart = calendar.dateComponents(
                        [.day],
                        from: calendar.startOfDay(for: firstPeriodEntry.date),
                        to: today
                    ).day ?? 0
                    let calculatedDay = daysSinceStart + 1

                    // Validate calculated day
                    if calculatedDay > 0 && calculatedDay <= AppConstants.Validation.maxCycleLength {
                        latestCycleDay = calculatedDay
                    } else {
                        logger.warning("Calculated cycle day \(calculatedDay) is out of bounds")
                        latestCycleDay = nil
                    }
                } else {
                    latestCycleDay = nil
                }
            }

            // Get today's flow level from entries
            let endDate = Date()
            let startDate = endDate.addingTimeInterval(-45 * 24 * 3600)
            let entries = try ManualCycleEntry.fetch(from: startDate, to: endDate, in: context)
            let todayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: today) }
            latestFlowLevel = todayEntries.first?.flowLevel
        } catch {
            logger.error("Failed to refresh manual cycle data: \(error.localizedDescription)")
        }
    }

    /// Get all manual cycle entries
    func allEntries() throws -> [ManualCycleEntry] {
        try ManualCycleEntry.fetchAll(in: context)
    }
}

// MARK: - ResourceManageable conformance

extension ManualCycleTracker: ResourceManageable {
    nonisolated func start() async throws {
        // Initialisation happens in init, data is refreshed there
    }

    nonisolated func cleanup() {
        Task { @MainActor in
            await _cleanup()
        }
    }

    @MainActor
    private func _cleanup() {
        // Clear cached state
        latestCycleDay = nil
        latestFlowLevel = nil

        // Note: Don't clear UserDefaults - that's persistent user data
        // Note: Don't nil out context - it's not owned by this service
    }
}
