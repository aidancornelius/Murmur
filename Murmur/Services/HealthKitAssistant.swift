//
//  HealthKitAssistant.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import Combine
import HealthKit
import os.log

// MARK: - Protocols

/// Protocol for HealthKit services to enable dependency injection and testing
@MainActor
protocol HealthKitAssistantProtocol: AnyObject {
    // Recent data (last 24-48 hours)
    func recentHRV() async -> Double?
    func recentRestingHR() async -> Double?
    func recentSleepHours() async -> Double?
    func recentWorkoutMinutes() async -> Double?
    func recentCycleDay() async -> Int?
    func recentFlowLevel() async -> String?

    // Historical data for specific dates (for backdating and seeding)
    func hrvForDate(_ date: Date) async -> Double?
    func restingHRForDate(_ date: Date) async -> Double?
    func sleepHoursForDate(_ date: Date) async -> Double?
    func workoutMinutesForDate(_ date: Date) async -> Double?
    func cycleDayForDate(_ date: Date) async -> Int?
    func flowLevelForDate(_ date: Date) async -> String?
}

/// Protocol abstraction for HealthKit data access to enable testing with mock implementations
/// This protocol abstracts the actual data fetching operations rather than the low-level query execution
protocol HealthKitDataProvider {
    func fetchQuantitySamples(
        type: HKQuantityType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKQuantitySample]

    func fetchCategorySamples(
        type: HKCategoryType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKCategorySample]

    func fetchWorkouts(
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKWorkout]

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws
}

/// Real HealthKit data provider that uses HKHealthStore
final class RealHealthKitDataProvider: HealthKitDataProvider, @unchecked Sendable {
    private let store = HKHealthStore()
    private var activeQueries: [HKQuery] = []

    deinit {
        // Clean up any remaining queries as safety net
        activeQueries.forEach { store.stop($0) }
    }

    func fetchQuantitySamples(
        type: HKQuantityType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: sortDescriptors) { [weak self] query, samples, error in
                Task { @MainActor in
                    if let self, let index = self.activeQueries.firstIndex(where: { $0 === query }) {
                        self.activeQueries.remove(at: index)
                    }
                }
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
            }
            Task { @MainActor in
                self.activeQueries.append(query)
            }
            store.execute(query)
        }
    }

    func fetchCategorySamples(
        type: HKCategoryType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: sortDescriptors) { [weak self] query, samples, error in
                Task { @MainActor in
                    if let self, let index = self.activeQueries.firstIndex(where: { $0 === query }) {
                        self.activeQueries.remove(at: index)
                    }
                }
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
            }
            Task { @MainActor in
                self.activeQueries.append(query)
            }
            store.execute(query)
        }
    }

    func fetchWorkouts(
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: limit, sortDescriptors: sortDescriptors) { [weak self] query, samples, error in
                Task { @MainActor in
                    if let self, let index = self.activeQueries.firstIndex(where: { $0 === query }) {
                        self.activeQueries.remove(at: index)
                    }
                }
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
                }
            }
            Task { @MainActor in
                self.activeQueries.append(query)
            }
            store.execute(query)
        }
    }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {
        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    func cleanup() {
        activeQueries.forEach { store.stop($0) }
        activeQueries.removeAll()
    }
}

// MARK: - HealthKit Assistant

/// Wraps all HealthKit interactions and caches recent context for symptom entries.
@MainActor
final class HealthKitAssistant: HealthKitAssistantProtocol, ObservableObject {
    private let logger = Logger(subsystem: "app.murmur", category: "HealthKit")
    private let dataProvider: HealthKitDataProvider

    var manualCycleTracker: ManualCycleTracker?

    private lazy var hrvType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
    private lazy var restingHeartType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
    private lazy var sleepType: HKCategoryType? = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
    private let workoutType = HKObjectType.workoutType()
    private lazy var menstrualFlowType: HKCategoryType? = HKCategoryType.categoryType(forIdentifier: .menstrualFlow)

    @Published private(set) var latestHRV: Double?
    @Published private(set) var latestRestingHR: Double?
    @Published private(set) var latestSleepHours: Double?
    @Published private(set) var latestWorkoutMinutes: Double?
    @Published private(set) var latestCycleDay: Int?
    @Published private(set) var latestFlowLevel: String?

    private var lastHRVSampleDate: Date?
    private var lastRestingSampleDate: Date?
    private var lastSleepSampleDate: Date?
    private var lastWorkoutSampleDate: Date?
    private var lastCycleSampleDate: Date?

    // MARK: - Historical Data Cache
    // Cache historical queries by calendar day to avoid repeated HealthKit queries
    // Key format: "YYYY-MM-DD"
    private var historicalHRVCache: [String: Double] = [:]
    private var historicalRestingHRCache: [String: Double] = [:]
    private var historicalSleepCache: [String: Double] = [:]
    private var historicalWorkoutCache: [String: Double] = [:]
    private var historicalCycleDayCache: [String: Int] = [:]
    private var historicalFlowLevelCache: [String: String] = [:]

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Initialisation

    /// Initialise with dependency-injected data provider (primarily for testing)
    init(dataProvider: HealthKitDataProvider = RealHealthKitDataProvider()) {
        self.dataProvider = dataProvider
    }

    /// Clean up active queries before deallocation
    /// Call this method before deallocating to prevent query leaks
    @MainActor
    func cleanup() {
        if let realProvider = dataProvider as? RealHealthKitDataProvider {
            realProvider.cleanup()
        }
    }

    nonisolated deinit {
        // Queries should have been stopped via cleanup() call
    }

    // MARK: - Debug Helpers (for testing)

    #if DEBUG
    /// Expose cache timestamps for testing purposes
    func _setCacheTimestamp(_ date: Date, for metric: String) {
        switch metric {
        case "hrv": lastHRVSampleDate = date
        case "restingHR": lastRestingSampleDate = date
        case "sleep": lastSleepSampleDate = date
        case "workout": lastWorkoutSampleDate = date
        case "cycle": lastCycleSampleDate = date
        default: break
        }
    }

    /// Expose active queries count for testing (always 0 with new architecture)
    var _activeQueriesCount: Int { 0 }
    #endif

    func bootstrapAuthorizations() async {
        guard isHealthDataAvailable else { return }
        do {
            try await requestPermissions()
            await refreshContext()
            // Update baselines in the background (non-blocking)
            Task {
                await updateBaselines()
            }
        } catch {
            logger.error("HealthKit bootstrap failed: \(error.localizedDescription)")
        }
    }

    func requestPermissions() async throws {
        guard isHealthDataAvailable else { return }
        var readTypes: Set<HKObjectType> = [workoutType]
        if let hrvType { readTypes.insert(hrvType) }
        if let restingHeartType { readTypes.insert(restingHeartType) }
        if let sleepType { readTypes.insert(sleepType) }
        if let menstrualFlowType { readTypes.insert(menstrualFlowType) }
        try await dataProvider.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Timeout Wrapper

    /// Wraps an async operation with a timeout to prevent indefinite hangs
    private func withTimeout<T>(
        _ timeout: TimeInterval = AppConstants.HealthKit.queryTimeout,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NSError(
                    domain: "HealthKitAssistant",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "HealthKit query timed out after \(timeout) seconds"]
                )
            }

            guard let result = try await group.next() else {
                throw NSError(
                    domain: "HealthKitAssistant",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Task group returned nil result"]
                )
            }
            group.cancelAll()
            return result
        }
    }

    func recentHRV() async -> Double? {
        await refreshHRVIfNeeded()
        return latestHRV
    }

    func recentRestingHR() async -> Double? {
        await refreshRestingHRIfNeeded()
        return latestRestingHR
    }

    func recentSleepHours() async -> Double? {
        await refreshSleepIfNeeded()
        return latestSleepHours
    }

    /// Fetches detailed sleep data including bed time and wake time from the last 24 hours
    func fetchDetailedSleepData() async -> (bedTime: Date?, wakeTime: Date?, totalHours: Double?)? {
        guard let sleepType else {
            logger.warning("Sleep type not available on this device")
            return nil
        }

        do {
            // Get sleep from last 24 hours
            let end = Date()
            let start = end.addingTimeInterval(-AppConstants.HealthKit.dailyMetricsLookback)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

            // Include all "asleep" categories
            let sleepValues: [Int] = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]
            let sleepPredicates = sleepValues.map { value in
                HKQuery.predicateForCategorySamples(with: .equalTo, value: value)
            }
            let sleepPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: sleepPredicates)
            let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sleepPredicate])

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let samples = try await dataProvider.fetchCategorySamples(
                type: sleepType,
                predicate: combinedPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            )

            guard !samples.isEmpty else { return nil }

            // Find the earliest bed time and latest wake time for continuous sleep session
            let sortedSamples = samples.sorted { $0.startDate < $1.startDate }

            // Group samples into sleep sessions (gaps > 1 hour indicate separate sessions)
            var sessions: [[HKCategorySample]] = []
            var currentSession: [HKCategorySample] = []

            for sample in sortedSamples {
                if let lastSample = currentSession.last {
                    let gap = sample.startDate.timeIntervalSince(lastSample.endDate)
                    if gap > 3600 { // 1 hour gap means new session
                        if !currentSession.isEmpty {
                            sessions.append(currentSession)
                        }
                        currentSession = [sample]
                    } else {
                        currentSession.append(sample)
                    }
                } else {
                    currentSession.append(sample)
                }
            }
            if !currentSession.isEmpty {
                sessions.append(currentSession)
            }

            guard !sessions.isEmpty else { return nil }

            // Find the most recent session
            guard let mostRecentSession = sessions.last else { return nil }
            guard let mostRecentWakeTime = mostRecentSession.last?.endDate else { return nil }

            // Include all sessions that are part of "tonight's sleep":
            // - Within 8 hours before the most recent wake time (to catch broken sleep)
            // - Started during sleep hours (after 6pm or before 2pm)
            let calendar = Calendar.current
            let sleepWindowStart = mostRecentWakeTime.addingTimeInterval(-8 * 3600) // 8 hours before wake

            let tonightsSessions = sessions.filter { session in
                guard let sessionStart = session.first?.startDate,
                      let sessionEnd = session.last?.endDate else { return false }

                // Must end after the sleep window start (within 12 hours of most recent wake)
                guard sessionEnd >= sleepWindowStart else { return false }

                // Must start during typical sleep hours (after 6pm or before 2pm)
                let hour = calendar.component(.hour, from: sessionStart)
                let isDuringSleepHours = hour >= 18 || hour < 14

                return isDuringSleepHours
            }

            guard !tonightsSessions.isEmpty else { return nil }

            // Combine all qualifying sessions
            let bedTime = tonightsSessions.first?.first?.startDate
            let wakeTime = tonightsSessions.last?.last?.endDate

            let totalSeconds = tonightsSessions.flatMap { $0 }.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            let totalHours = totalSeconds / 3600.0

            return (bedTime: bedTime, wakeTime: wakeTime, totalHours: totalHours)
        } catch {
            logger.error("Failed to fetch detailed sleep data: \(error.localizedDescription)")
            return nil
        }
    }

    func recentWorkoutMinutes() async -> Double? {
        await refreshWorkoutIfNeeded()
        return latestWorkoutMinutes
    }

    func recentCycleDay() async -> Int? {
        // Prefer manual tracking if enabled
        if let manualCycleTracker, manualCycleTracker.isEnabled {
            await manualCycleTracker.refreshCycleData()
            return manualCycleTracker.latestCycleDay
        }
        await refreshCycleIfNeeded()
        return latestCycleDay
    }

    func recentFlowLevel() async -> String? {
        // Prefer manual tracking if enabled
        if let manualCycleTracker, manualCycleTracker.isEnabled {
            await manualCycleTracker.refreshCycleData()
            return manualCycleTracker.latestFlowLevel
        }
        await refreshCycleIfNeeded()
        return latestFlowLevel
    }

    // MARK: - Historical Data Queries

    /// Get HRV for a specific date (cached per calendar day)
    func hrvForDate(_ date: Date) async -> Double? {
        let cacheKey = dayKey(for: date)
        if let cached = historicalHRVCache[cacheKey] {
            return cached
        }

        guard let hrvType else {
            logger.warning("HRV type not available on this device")
            return nil
        }

        do {
            let (start, end) = dayBounds(for: date)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let samples = try await withTimeout { [weak self] in
                guard let self else {
                    throw NSError(
                        domain: "HealthKitAssistant",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                    )
                }
                return try await self.dataProvider.fetchQuantitySamples(
                    type: hrvType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sort]
                )
            }

            if let sample = samples.first {
                let value = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                historicalHRVCache[cacheKey] = value
                return value
            }
        } catch {
            logger.error("Failed to fetch HRV for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    /// Get resting heart rate for a specific date (cached per calendar day)
    func restingHRForDate(_ date: Date) async -> Double? {
        let cacheKey = dayKey(for: date)
        if let cached = historicalRestingHRCache[cacheKey] {
            return cached
        }

        guard let restingHeartType else {
            logger.warning("Resting heart rate type not available on this device")
            return nil
        }

        do {
            let (start, end) = dayBounds(for: date)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let samples = try await withTimeout { [weak self] in
                guard let self else {
                    throw NSError(
                        domain: "HealthKitAssistant",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                    )
                }
                return try await self.dataProvider.fetchQuantitySamples(
                    type: restingHeartType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sort]
                )
            }

            if let sample = samples.first {
                let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let value = sample.quantity.doubleValue(for: unit)
                historicalRestingHRCache[cacheKey] = value
                return value
            }
        } catch {
            logger.error("Failed to fetch resting HR for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    /// Get sleep hours for a specific date (cached per calendar day)
    /// Looks for sleep ending on the given date (i.e., sleep from the night before)
    func sleepHoursForDate(_ date: Date) async -> Double? {
        let cacheKey = dayKey(for: date)
        if let cached = historicalSleepCache[cacheKey] {
            return cached
        }

        guard let sleepType else {
            logger.warning("Sleep type not available on this device")
            return nil
        }

        do {
            // Look for sleep that ended on this day (sleep from night before)
            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date

            // Extend backwards to catch sleep that started the night before
            let searchStart = calendar.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart

            let predicate = HKQuery.predicateForSamples(withStart: searchStart, end: dayEnd)

            // Include all "asleep" categories
            let sleepValues: [Int] = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]
            let sleepPredicates = sleepValues.map { value in
                HKQuery.predicateForCategorySamples(with: .equalTo, value: value)
            }
            let sleepPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: sleepPredicates)
            let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sleepPredicate])

            let samples = try await withTimeout { [weak self] in
                guard let self else {
                    throw NSError(
                        domain: "HealthKitAssistant",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                    )
                }
                return try await self.dataProvider.fetchCategorySamples(
                    type: sleepType,
                    predicate: combinedPredicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                )
            }

            // Sum all sleep samples for this day
            let totalSeconds = samples.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }

            let hours = totalSeconds / 3600.0
            if hours > 0 {
                historicalSleepCache[cacheKey] = hours
                return hours
            }
        } catch {
            logger.error("Failed to fetch sleep for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    /// Get workout minutes for a specific date (cached per calendar day)
    func workoutMinutesForDate(_ date: Date) async -> Double? {
        let cacheKey = dayKey(for: date)
        if let cached = historicalWorkoutCache[cacheKey] {
            return cached
        }

        do {
            let (start, end) = dayBounds(for: date)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

            let samples = try await withTimeout { [weak self] in
                guard let self else {
                    throw NSError(
                        domain: "HealthKitAssistant",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                    )
                }
                return try await self.dataProvider.fetchWorkouts(
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                )
            }

            let totalSeconds = samples.reduce(0.0) { total, workout in
                total + workout.duration
            }

            let minutes = totalSeconds / 60.0
            if minutes > 0 {
                historicalWorkoutCache[cacheKey] = minutes
                return minutes
            }
        } catch {
            logger.error("Failed to fetch workouts for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    /// Get cycle day for a specific date (cached per calendar day)
    func cycleDayForDate(_ date: Date) async -> Int? {
        let cacheKey = dayKey(for: date)
        if let cached = historicalCycleDayCache[cacheKey] {
            return cached
        }

        guard let menstrualFlowType else {
            logger.warning("Menstrual flow type not available on this device")
            return nil
        }

        do {
            // Look back 45 days to find the most recent period start before this date
            let calendar = Calendar.current
            let searchEnd = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let searchStart = calendar.date(byAdding: .day, value: -45, to: date) ?? date

            let predicate = HKQuery.predicateForSamples(withStart: searchStart, end: searchEnd)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let samples = try await withTimeout { [weak self] in
                guard let self else {
                    throw NSError(
                        domain: "HealthKitAssistant",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                    )
                }
                return try await self.dataProvider.fetchCategorySamples(
                    type: menstrualFlowType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sort]
                )
            }

            // Find most recent period start before or on this date
            let periodStarts = samples.filter { sample in
                let value = HKCategoryValueVaginalBleeding(rawValue: sample.value)
                return value != .unspecified && value != Optional<HKCategoryValueVaginalBleeding>.none &&
                       sample.startDate <= searchEnd
            }

            if let mostRecentPeriodStart = periodStarts.first {
                let daysSinceStart = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: mostRecentPeriodStart.startDate),
                    to: calendar.startOfDay(for: date)
                ).day ?? 0
                let cycleDay = daysSinceStart + 1
                historicalCycleDayCache[cacheKey] = cycleDay
                return cycleDay
            }
        } catch {
            logger.error("Failed to fetch cycle day for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    /// Get menstrual flow level for a specific date (cached per calendar day)
    func flowLevelForDate(_ date: Date) async -> String? {
        let cacheKey = dayKey(for: date)
        if let cached = historicalFlowLevelCache[cacheKey] {
            return cached
        }

        guard let menstrualFlowType else {
            logger.warning("Menstrual flow type not available on this device")
            return nil
        }

        do {
            let (start, end) = dayBounds(for: date)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

            let samples = try await withTimeout { [weak self] in
                guard let self else {
                    throw NSError(
                        domain: "HealthKitAssistant",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                    )
                }
                return try await self.dataProvider.fetchCategorySamples(
                    type: menstrualFlowType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                )
            }

            if let sample = samples.first {
                let flowValue = HKCategoryValueVaginalBleeding(rawValue: sample.value)
                let flowLevel: String?
                switch flowValue {
                case .light: flowLevel = "light"
                case .medium: flowLevel = "medium"
                case .heavy: flowLevel = "heavy"
                case .unspecified: flowLevel = "spotting"
                default: flowLevel = nil
                }

                if let flowLevel {
                    historicalFlowLevelCache[cacheKey] = flowLevel
                    return flowLevel
                }
            }
        } catch {
            logger.error("Failed to fetch flow level for date \(date): \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - Historical Query Helpers

    /// Generate a cache key for a specific day (format: "YYYY-MM-DD")
    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    /// Get the start and end of a calendar day for a given date
    private func dayBounds(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return (start, end)
    }

    func refreshContext() async {
        guard isHealthDataAvailable else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshHRVIfNeeded(force: true) }
            group.addTask { await self.refreshRestingHRIfNeeded(force: true) }
            group.addTask { await self.refreshSleepIfNeeded(force: true) }
            group.addTask { await self.refreshWorkoutIfNeeded(force: true) }
            group.addTask { await self.refreshCycleIfNeeded(force: true) }
        }
    }

    /// Force refresh all HealthKit data, useful for pull-to-refresh scenarios
    @MainActor
    public func forceRefreshAll() async {
        await refreshContext()
    }


    private func refreshHRVIfNeeded(force: Bool = false) async {
        guard let hrvType else {
            logger.warning("HRV type not available on this device")
            return
        }
        if !force, let lastHRVSampleDate, Date().timeIntervalSince(lastHRVSampleDate) < AppConstants.HealthKit.hrvCacheDuration {
            return
        }
        do {
            let samples = try await fetchQuantitySamples(for: hrvType, limit: AppConstants.HealthKit.hrvSampleLimit)
            if let latest = samples.first {
                latestHRV = latest.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                lastHRVSampleDate = latest.endDate
            }
        } catch {
            logger.error("Failed to refresh HRV: \(error.localizedDescription)")
        }
    }

    private func refreshRestingHRIfNeeded(force: Bool = false) async {
        guard let restingHeartType else {
            logger.warning("Resting heart rate type not available on this device")
            return
        }
        if !force, let lastRestingSampleDate, Date().timeIntervalSince(lastRestingSampleDate) < AppConstants.HealthKit.restingHeartRateCacheDuration {
            logger.debug("Using cached resting heart rate from \(lastRestingSampleDate)")
            return
        }
        do {
            logger.debug("Fetching resting heart rate samples from last \(AppConstants.HealthKit.quantitySampleLookback / 3600) hours")
            let samples = try await fetchQuantitySamples(for: restingHeartType, limit: AppConstants.HealthKit.restingHeartRateSampleLimit)
            logger.debug("Retrieved \(samples.count) resting heart rate samples")
            if let latest = samples.first {
                let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                latestRestingHR = latest.quantity.doubleValue(for: unit)
                lastRestingSampleDate = latest.endDate
                logger.debug("Updated resting heart rate to \(self.latestRestingHR ?? 0) bpm from \(latest.endDate)")
            } else {
                logger.warning("No resting heart rate samples found in the last \(AppConstants.HealthKit.quantitySampleLookback / 3600) hours")
                latestRestingHR = nil
            }
        } catch {
            logger.error("Failed to refresh resting heart rate: \(error.localizedDescription)")
        }
    }

    private func refreshSleepIfNeeded(force: Bool = false) async {
        guard let sleepType else {
            logger.warning("Sleep type not available on this device")
            return
        }
        if !force, let lastSleepSampleDate, Date().timeIntervalSince(lastSleepSampleDate) < AppConstants.HealthKit.sleepCacheDuration {
            return
        }
        do {
            // Get sleep from last 24 hours
            let end = Date()
            let start = end.addingTimeInterval(-AppConstants.HealthKit.dailyMetricsLookback)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            // Include all "asleep" categories (core, deep, REM, unspecified)
            let sleepValues: [Int] = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]
            let sleepPredicates = sleepValues.map { value in
                HKQuery.predicateForCategorySamples(with: .equalTo, value: value)
            }
            let sleepPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: sleepPredicates)
            let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, sleepPredicate])

            let samples = try await withTimeout { [weak self] in
                guard let self else {
                    throw NSError(
                        domain: "HealthKitAssistant",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                    )
                }
                return try await self.dataProvider.fetchCategorySamples(
                    type: sleepType,
                    predicate: combinedPredicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                )
            }

            let totalSeconds = samples.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            latestSleepHours = totalSeconds / 3600.0
            lastSleepSampleDate = end
        } catch {
            logger.error("Failed to refresh sleep: \(error.localizedDescription)")
        }
    }

    private func refreshWorkoutIfNeeded(force: Bool = false) async {
        if !force, let lastWorkoutSampleDate, Date().timeIntervalSince(lastWorkoutSampleDate) < AppConstants.HealthKit.workoutCacheDuration {
            return
        }
        do {
            // Get workouts from last 24 hours
            let end = Date()
            let start = end.addingTimeInterval(-AppConstants.HealthKit.dailyMetricsLookback)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

            let samples = try await withTimeout { [weak self] in
                guard let self else {
                    throw NSError(
                        domain: "HealthKitAssistant",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                    )
                }
                return try await self.dataProvider.fetchWorkouts(
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                )
            }

            let totalSeconds = samples.reduce(0.0) { total, workout in
                total + workout.duration
            }
            latestWorkoutMinutes = totalSeconds / 60.0
            lastWorkoutSampleDate = end
        } catch {
            logger.error("Failed to refresh workout: \(error.localizedDescription)")
        }
    }

    private func refreshCycleIfNeeded(force: Bool = false) async {
        guard let menstrualFlowType else {
            logger.warning("Menstrual flow type not available on this device")
            return
        }
        if !force, let lastCycleSampleDate, Date().timeIntervalSince(lastCycleSampleDate) < AppConstants.HealthKit.cycleCacheDuration {
            return
        }
        do {
            // Get menstrual flow from last 45 days to calculate cycle day
            let end = Date()
            let start = end.addingTimeInterval(-AppConstants.HealthKit.menstrualCycleLookback)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let samples = try await withTimeout { [weak self] in
                guard let self else {
                    throw NSError(
                        domain: "HealthKitAssistant",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                    )
                }
                return try await self.dataProvider.fetchCategorySamples(
                    type: menstrualFlowType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sort]
                )
            }

            // Find most recent period start (flow not unspecified)
            let periodStarts = samples.filter { sample in
                let value = HKCategoryValueVaginalBleeding(rawValue: sample.value)
                return value != .unspecified && value != Optional<HKCategoryValueVaginalBleeding>.none
            }

            if let mostRecentPeriodStart = periodStarts.first {
                let calendar = Calendar.current
                let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: mostRecentPeriodStart.startDate), to: calendar.startOfDay(for: Date())).day ?? 0
                latestCycleDay = daysSinceStart + 1
            } else {
                latestCycleDay = nil
            }

            // Get today's flow level
            let todayStart = Calendar.current.startOfDay(for: Date())
            let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) ?? Date()
            let todaySamples = samples.filter { $0.startDate >= todayStart && $0.startDate < todayEnd }

            if let todayFlow = todaySamples.first {
                let flowValue = HKCategoryValueVaginalBleeding(rawValue: todayFlow.value)
                switch flowValue {
                case .light: latestFlowLevel = "light"
                case .medium: latestFlowLevel = "medium"
                case .heavy: latestFlowLevel = "heavy"
                case .unspecified: latestFlowLevel = "spotting"
                default: latestFlowLevel = nil
                }
            } else {
                latestFlowLevel = nil
            }

            lastCycleSampleDate = end
        } catch {
            logger.error("Failed to refresh cycle data: \(error.localizedDescription)")
        }
    }

    private func fetchQuantitySamples(for type: HKQuantityType, limit: Int) async throws -> [HKQuantitySample] {
        let start = Date().addingTimeInterval(-AppConstants.HealthKit.quantitySampleLookback)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withTimeout { [weak self] in
            guard let self else {
                throw NSError(
                    domain: "HealthKitAssistant",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                )
            }
            return try await self.dataProvider.fetchQuantitySamples(
                type: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort]
            )
        }
    }

    // MARK: - Baseline Calculation

    /// Update health metric baselines from historical data (30 days)
    func updateBaselines() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.updateHRVBaseline() }
            group.addTask { await self.updateRestingHRBaseline() }
        }
    }

    private func updateHRVBaseline() async {
        guard let hrvType else {
            logger.warning("HRV type not available on this device")
            return
        }

        do {
            // Fetch 30 days of HRV data
            let start = Date().addingTimeInterval(-30 * 24 * 3600)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let samples = try await withTimeout { [weak self] in
                guard let self else {
                    throw NSError(
                        domain: "HealthKitAssistant",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                    )
                }
                return try await self.dataProvider.fetchQuantitySamples(
                    type: hrvType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sort]
                )
            }

            let values = samples.map { $0.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)) }
            if !values.isEmpty {
                await MainActor.run {
                    HealthMetricBaselines.shared.updateHRVBaseline(from: values)
                }
                logger.info("Updated HRV baseline with \(values.count) samples")
            }
        } catch {
            logger.error("Failed to update HRV baseline: \(error.localizedDescription)")
        }
    }

    private func updateRestingHRBaseline() async {
        guard let restingHeartType else {
            logger.warning("Resting heart rate type not available on this device")
            return
        }

        do {
            // Fetch 30 days of resting HR data
            let start = Date().addingTimeInterval(-30 * 24 * 3600)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let samples = try await withTimeout { [weak self] in
                guard let self else {
                    throw NSError(
                        domain: "HealthKitAssistant",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKitAssistant deallocated during operation"]
                    )
                }
                return try await self.dataProvider.fetchQuantitySamples(
                    type: restingHeartType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [sort]
                )
            }

            let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let values = samples.map { $0.quantity.doubleValue(for: unit) }
            if !values.isEmpty {
                await MainActor.run {
                    HealthMetricBaselines.shared.updateRestingHRBaseline(from: values)
                }
                logger.info("Updated resting HR baseline with \(values.count) samples")
            }
        } catch {
            logger.error("Failed to update resting HR baseline: \(error.localizedDescription)")
        }
    }

}
