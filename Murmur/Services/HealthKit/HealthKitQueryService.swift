//
//  HealthKitQueryService.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/10/2025.
//

import Foundation
import HealthKit
import os.log

// MARK: - Protocols

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

    func fetchStatistics(
        quantityType: HKQuantityType,
        predicate: NSPredicate?,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics?

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws
}

/// Service responsible for executing HealthKit queries with timeout handling
/// Encapsulates all direct HKHealthStore interactions
protocol HealthKitQueryServiceProtocol {
    var dataProvider: HealthKitDataProvider { get }
    var isHealthDataAvailable: Bool { get }

    /// Request HealthKit permissions
    func requestPermissions() async throws

    /// Fetch quantity samples with timeout protection
    func fetchQuantitySamples(
        for type: HKQuantityType,
        start: Date,
        end: Date,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKQuantitySample]

    /// Fetch category samples with timeout protection
    func fetchCategorySamples(
        for type: HKCategoryType,
        start: Date,
        end: Date,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKCategorySample]

    /// Fetch workouts with timeout protection
    func fetchWorkouts(
        start: Date,
        end: Date,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKWorkout]

    /// Fetch statistics with timeout protection
    func fetchStatistics(
        quantityType: HKQuantityType,
        start: Date,
        end: Date,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics?

    /// Fetch sleep samples with compound predicates for "asleep" categories
    /// Includes all asleep types: core, deep, REM, unspecified
    func fetchSleepSamples(
        start: Date,
        end: Date
    ) async throws -> [HKCategorySample]

    /// Fetch detailed sleep data including bed time and wake time
    func fetchDetailedSleepData() async -> (bedTime: Date?, wakeTime: Date?, totalHours: Double?)?
}

// MARK: - Real Implementation

/// Real HealthKit data provider that uses HKHealthStore
final class RealHealthKitDataProvider: HealthKitDataProvider, @unchecked Sendable {
    private let store = HKHealthStore()
    private var activeQueries: [HKQuery] = []

    deinit {
        // Clean up any remaining queries as safety net
        activeQueries.forEach { store.stop($0) }
    }

    // MARK: - Generic Query Execution Helper

    /// Generic helper to execute any HKQuery with continuation-based async handling
    /// Encapsulates query lifecycle management (tracking, cleanup) and error handling
    /// Returns optional result - callers handle nil as appropriate (e.g., empty array)
    private func executeQuery<ResultType>(
        _ queryBuilder: @escaping (@escaping (ResultType?, Error?) -> Void) -> HKQuery
    ) async throws -> ResultType? {
        try await withCheckedThrowingContinuation { continuation in
            var queryRef: HKQuery?
            let query = queryBuilder { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self, let queryRef else { return }
                    if let index = self.activeQueries.firstIndex(where: { $0 === queryRef }) {
                        self.activeQueries.remove(at: index)
                    }
                }
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
            queryRef = query
            Task { @MainActor in
                self.activeQueries.append(query)
            }
            store.execute(query)
        }
    }

    func fetchQuantitySamples(
        type: HKQuantityType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKQuantitySample] {
        let samples: [HKSample]? = try await executeQuery { completion in
            HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: sortDescriptors) { _, samples, error in
                completion(samples, error)
            }
        }
        return samples as? [HKQuantitySample] ?? []
    }

    func fetchCategorySamples(
        type: HKCategoryType,
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKCategorySample] {
        let samples: [HKSample]? = try await executeQuery { completion in
            HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: sortDescriptors) { _, samples, error in
                completion(samples, error)
            }
        }
        return samples as? [HKCategorySample] ?? []
    }

    func fetchWorkouts(
        predicate: NSPredicate?,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKWorkout] {
        let samples: [HKSample]? = try await executeQuery { completion in
            HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: limit, sortDescriptors: sortDescriptors) { _, samples, error in
                completion(samples, error)
            }
        }
        return samples as? [HKWorkout] ?? []
    }

    func fetchStatistics(
        quantityType: HKQuantityType,
        predicate: NSPredicate?,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics? {
        try await executeQuery { completion in
            HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: options) { _, statistics, error in
                completion(statistics, error)
            }
        }
    }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {
        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }
}

// MARK: - ResourceManageable conformance for RealHealthKitDataProvider

extension RealHealthKitDataProvider: ResourceManageable {
    func start() async throws {
        // No initialisation required - HKHealthStore is ready on creation
    }

    func cleanup() {
        activeQueries.forEach { store.stop($0) }
        activeQueries.removeAll()
    }
}

/// Service that wraps HealthKit queries with timeout handling and provides high-level data access
final class HealthKitQueryService: HealthKitQueryServiceProtocol {
    private let logger = Logger(subsystem: "app.murmur", category: "HealthKitQuery")
    let dataProvider: HealthKitDataProvider

    private lazy var hrvType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
    private lazy var restingHeartType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
    private lazy var sleepType: HKCategoryType? = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
    private let workoutType = HKObjectType.workoutType()
    private lazy var menstrualFlowType: HKCategoryType? = HKCategoryType.categoryType(forIdentifier: .menstrualFlow)

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    init(dataProvider: HealthKitDataProvider = RealHealthKitDataProvider()) {
        self.dataProvider = dataProvider
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
                    domain: "HealthKitQueryService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "HealthKit query timed out after \(timeout) seconds"]
                )
            }

            guard let result = try await group.next() else {
                throw NSError(
                    domain: "HealthKitQueryService",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Task group returned nil result"]
                )
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Query Methods

    func fetchQuantitySamples(
        for type: HKQuantityType,
        start: Date,
        end: Date,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withTimeout {
            try await self.dataProvider.fetchQuantitySamples(
                type: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
            )
        }
    }

    func fetchCategorySamples(
        for type: HKCategoryType,
        start: Date,
        end: Date,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withTimeout {
            try await self.dataProvider.fetchCategorySamples(
                type: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
            )
        }
    }

    func fetchWorkouts(
        start: Date,
        end: Date,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?
    ) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withTimeout {
            try await self.dataProvider.fetchWorkouts(
                predicate: predicate,
                limit: limit,
                sortDescriptors: sortDescriptors
            )
        }
    }

    func fetchStatistics(
        quantityType: HKQuantityType,
        start: Date,
        end: Date,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withTimeout {
            try await self.dataProvider.fetchStatistics(
                quantityType: quantityType,
                predicate: predicate,
                options: options
            )
        }
    }

    func fetchSleepSamples(
        start: Date,
        end: Date
    ) async throws -> [HKCategorySample] {
        guard let sleepType else {
            logger.warning("Sleep type not available on this device")
            return []
        }

        let timePredicate = HKQuery.predicateForSamples(withStart: start, end: end)

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
        let combinedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, sleepPredicate])

        return try await withTimeout {
            try await self.dataProvider.fetchCategorySamples(
                type: sleepType,
                predicate: combinedPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            )
        }
    }

    func fetchDetailedSleepData() async -> (bedTime: Date?, wakeTime: Date?, totalHours: Double?)? {
        guard let sleepType else {
            logger.warning("Sleep type not available on this device")
            return nil
        }

        do {
            // Get sleep from last 24 hours
            let end = Date()
            let start = end.addingTimeInterval(-AppConstants.HealthKit.dailyMetricsLookback)

            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let samples = try await fetchSleepSamples(start: start, end: end)

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
}

// MARK: - ResourceManageable conformance for HealthKitQueryService

extension HealthKitQueryService: ResourceManageable {
    func start() async throws {
        // No initialisation required - queries are executed on-demand
    }

    func cleanup() {
        if let realProvider = dataProvider as? RealHealthKitDataProvider {
            realProvider.cleanup()
        }
    }
}
