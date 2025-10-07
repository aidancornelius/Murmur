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
    func recentHRV() async -> Double?
    func recentRestingHR() async -> Double?
    func recentSleepHours() async -> Double?
    func recentWorkoutMinutes() async -> Double?
    func recentCycleDay() async -> Int?
    func recentFlowLevel() async -> String?
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
final class RealHealthKitDataProvider: HealthKitDataProvider {
    private let store = HKHealthStore()
    private var activeQueries: [HKQuery] = []

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

            // Get the most recent sleep session
            guard let lastSession = sessions.last, !lastSession.isEmpty else { return nil }

            let bedTime = lastSession.first?.startDate
            let wakeTime = lastSession.last?.endDate

            let totalSeconds = lastSession.reduce(0.0) { total, sample in
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
            return
        }
        do {
            let samples = try await fetchQuantitySamples(for: restingHeartType, limit: AppConstants.HealthKit.restingHeartRateSampleLimit)
            if let latest = samples.first {
                let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                latestRestingHR = latest.quantity.doubleValue(for: unit)
                lastRestingSampleDate = latest.endDate
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

            let samples = try await withTimeout { [self] in
                try await self.dataProvider.fetchCategorySamples(
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

            let samples = try await withTimeout { [self] in
                try await self.dataProvider.fetchWorkouts(
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

            let samples = try await withTimeout { [self] in
                try await self.dataProvider.fetchCategorySamples(
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
        return try await withTimeout { [self] in
            try await self.dataProvider.fetchQuantitySamples(
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

            let samples = try await withTimeout { [self] in
                try await self.dataProvider.fetchQuantitySamples(
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

            let samples = try await withTimeout { [self] in
                try await self.dataProvider.fetchQuantitySamples(
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
