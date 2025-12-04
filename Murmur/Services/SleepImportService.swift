// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// SleepImportService.swift
// Created by Aidan Cornelius-Bell on 04/12/2025.
// Service for importing sleep data from HealthKit.
//
import CoreData
import Foundation
@preconcurrency import HealthKit
import os.log

/// Service responsible for automatically importing sleep data from HealthKit
@MainActor
class SleepImportService: ObservableObject {
    private let logger = Logger(subsystem: "app.murmur", category: "SleepImport")

    /// The HealthKit assistant used for fetching sleep data
    private weak var healthKit: HealthKitAssistant?

    /// Whether automatic sleep import is enabled
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: UserDefaultsKeys.autoImportSleepEnabled)
            if isEnabled {
                // Trigger initial import when enabled
                Task {
                    await performImport()
                }
            }
        }
    }

    /// Date of last successful import
    private var lastImportDate: Date? {
        get {
            UserDefaults.standard.object(forKey: UserDefaultsKeys.lastSleepImportDate) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.lastSleepImportDate)
        }
    }

    /// Number of days to look back on first import
    private let initialBackfillDays: Int = 7

    /// Minimum time between imports (to avoid excessive queries)
    private let minimumImportInterval: TimeInterval = 3600 // 1 hour

    init(healthKit: HealthKitAssistant? = nil) {
        self.healthKit = healthKit
        self.isEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.autoImportSleepEnabled)
    }

    /// Set the HealthKit assistant (called after init when available)
    func setHealthKit(_ healthKit: HealthKitAssistant) {
        self.healthKit = healthKit
    }

    /// Perform sleep import if enabled and conditions are met
    func performImportIfNeeded() async {
        guard isEnabled else {
            logger.debug("Sleep import disabled, skipping")
            return
        }

        // Check if enough time has passed since last import
        if let lastImport = lastImportDate,
           DateUtility.now().timeIntervalSince(lastImport) < minimumImportInterval {
            logger.debug("Skipping import, last import was \(lastImport)")
            return
        }

        await performImport()
    }

    /// Force a sleep import regardless of timing
    func performImport() async {
        guard isEnabled else { return }

        guard let healthKit = healthKit else {
            logger.warning("HealthKit assistant not available, skipping sleep import")
            return
        }

        let context = CoreDataStack.shared.context

        guard healthKit.isHealthDataAvailable else {
            logger.warning("HealthKit not available, skipping sleep import")
            return
        }

        do {
            // Determine the date range to query
            let endDate = DateUtility.now()
            let startDate: Date

            if lastImportDate == nil {
                // First import: go back 7 days
                startDate = Calendar.current.date(byAdding: .day, value: -initialBackfillDays, to: endDate) ?? endDate
                logger.info("First sleep import, fetching \(self.initialBackfillDays) days of data")
            } else {
                // Subsequent imports: go back 2 days to catch any late-arriving data
                startDate = Calendar.current.date(byAdding: .day, value: -2, to: endDate) ?? endDate
            }

            // Fetch sleep sessions from HealthKit
            let sleepSessions = try await fetchSleepSessions(from: startDate, to: endDate, healthKit: healthKit)
            logger.info("Found \(sleepSessions.count) sleep sessions from HealthKit")

            // Import each session, checking for duplicates
            var importedCount = 0
            for session in sleepSessions {
                let wasImported = try await importSleepSession(session, context: context)
                if wasImported {
                    importedCount += 1
                }
            }

            if importedCount > 0 {
                try context.save()
                logger.info("Imported \(importedCount) new sleep entries")
            }

            lastImportDate = endDate

        } catch {
            logger.error("Failed to import sleep data: \(error.localizedDescription)")
        }
    }

    /// Fetch sleep sessions from HealthKit and group into discrete sleep periods
    private func fetchSleepSessions(
        from startDate: Date,
        to endDate: Date,
        healthKit: HealthKitAssistant
    ) async throws -> [SleepSession] {
        // Fetch all sleep samples in the date range
        let samples = try await healthKit.fetchSleepSamples(from: startDate, to: endDate)

        guard !samples.isEmpty else { return [] }

        // Sort samples by start date
        let sortedSamples = samples.sorted { $0.startDate < $1.startDate }

        // Group samples into sleep sessions (gaps > 2 hours indicate separate sessions)
        var sessions: [SleepSession] = []
        var currentSessionSamples: [HKCategorySample] = []

        for sample in sortedSamples {
            if let lastSample = currentSessionSamples.last {
                let gap = sample.startDate.timeIntervalSince(lastSample.endDate)
                if gap > 7200 { // 2 hour gap means new session
                    if let session = createSession(from: currentSessionSamples) {
                        sessions.append(session)
                    }
                    currentSessionSamples = [sample]
                } else {
                    currentSessionSamples.append(sample)
                }
            } else {
                currentSessionSamples.append(sample)
            }
        }

        // Don't forget the last session
        if let session = createSession(from: currentSessionSamples) {
            sessions.append(session)
        }

        return sessions
    }

    /// Create a SleepSession from a group of HKCategorySamples
    private func createSession(from samples: [HKCategorySample]) -> SleepSession? {
        guard let firstSample = samples.first,
              let lastSample = samples.last else { return nil }

        let bedTime = firstSample.startDate
        let wakeTime = lastSample.endDate

        // Calculate total sleep duration (sum of all sample durations)
        let totalSeconds = samples.reduce(0.0) { total, sample in
            total + sample.endDate.timeIntervalSince(sample.startDate)
        }
        let totalHours = totalSeconds / 3600.0

        // Only include sessions with reasonable duration (at least 30 minutes)
        guard totalHours >= 0.5 else { return nil }

        // Collect unique HK UUIDs for deduplication
        let uuids = samples.map { $0.uuid.uuidString }

        return SleepSession(
            bedTime: bedTime,
            wakeTime: wakeTime,
            totalHours: totalHours,
            healthKitUUIDs: uuids
        )
    }

    /// Import a single sleep session, returning true if it was imported (not a duplicate)
    private func importSleepSession(
        _ session: SleepSession,
        context: NSManagedObjectContext
    ) async throws -> Bool {
        // Check if we already have this sleep session
        if try existingSleepEvent(for: session, in: context) != nil {
            logger.debug("Skipping duplicate sleep session at \(session.bedTime)")
            return false
        }

        // Create new SleepEvent
        let sleepEvent = SleepEvent(context: context)
        sleepEvent.id = UUID()
        sleepEvent.createdAt = DateUtility.now()
        sleepEvent.backdatedAt = session.wakeTime // Associate with wake date
        sleepEvent.bedTime = session.bedTime
        sleepEvent.wakeTime = session.wakeTime
        sleepEvent.quality = 3 // Default quality for imported entries
        sleepEvent.hkSleepHours = NSNumber(value: session.totalHours)
        sleepEvent.source = "healthkit"
        // Store the first UUID as reference (for primary deduplication)
        sleepEvent.healthKitUUID = session.healthKitUUIDs.first

        logger.debug("Imported sleep: \(session.bedTime) to \(session.wakeTime), \(String(format: "%.1f", session.totalHours))h")

        return true
    }

    /// Check if a sleep event already exists for the given session
    private func existingSleepEvent(
        for session: SleepSession,
        in context: NSManagedObjectContext
    ) throws -> SleepEvent? {
        let request = SleepEvent.fetchRequest()

        // Check by HealthKit UUID first (most precise)
        if let uuid = session.healthKitUUIDs.first {
            request.predicate = NSPredicate(format: "healthKitUUID == %@", uuid)
            let results = try context.fetch(request)
            if let existing = results.first {
                return existing
            }
        }

        // Fall back to time-based matching (within 30 minute tolerance)
        let tolerance: TimeInterval = 1800 // 30 minutes
        let bedTimeStart = session.bedTime.addingTimeInterval(-tolerance)
        let bedTimeEnd = session.bedTime.addingTimeInterval(tolerance)
        let wakeTimeStart = session.wakeTime.addingTimeInterval(-tolerance)
        let wakeTimeEnd = session.wakeTime.addingTimeInterval(tolerance)

        request.predicate = NSPredicate(
            format: "bedTime >= %@ AND bedTime <= %@ AND wakeTime >= %@ AND wakeTime <= %@",
            bedTimeStart as NSDate,
            bedTimeEnd as NSDate,
            wakeTimeStart as NSDate,
            wakeTimeEnd as NSDate
        )

        let results = try context.fetch(request)
        return results.first
    }
}

// MARK: - Supporting Types

/// Represents a single sleep session aggregated from HealthKit samples
private struct SleepSession {
    let bedTime: Date
    let wakeTime: Date
    let totalHours: Double
    let healthKitUUIDs: [String]
}
