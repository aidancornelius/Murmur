//
//  HealthKitAssistant.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import HealthKit
import os.log

/// Wraps all HealthKit interactions and caches recent context for symptom entries.
@MainActor
final class HealthKitAssistant: ObservableObject {
    private let logger = Logger(subsystem: "app.murmur", category: "HealthKit")
    private let store = HKHealthStore()

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

    func bootstrapAuthorizations() async {
        guard isHealthDataAvailable else { return }
        do {
            try await requestPermissions()
            await refreshContext()
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
        try await store.requestAuthorization(toShare: [], read: readTypes)
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

            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
                let query = HKSampleQuery(sampleType: sleepType, predicate: combinedPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
                store.execute(query)
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

            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
                let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
                }
                store.execute(query)
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

            let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCategorySample], Error>) in
                let query = HKSampleQuery(sampleType: menstrualFlowType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
                store.execute(query)
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
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: quantitySamples)
            }
            store.execute(query)
        }
    }

}
