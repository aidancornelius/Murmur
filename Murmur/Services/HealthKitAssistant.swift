// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// HealthKitAssistant.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Main service coordinating HealthKit data access.
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

// MARK: - HealthKit Assistant Facade

/// Facade that orchestrates HealthKit operations through specialised services
/// Responsibilities: coordination, public API, manual tracking integration
/// Delegates to: HealthKitQueryService, HealthKitCacheService, HealthKitBaselineCalculator
@MainActor
final class HealthKitAssistant: HealthKitAssistantProtocol, ObservableObject {
    private let logger = Logger(subsystem: "app.murmur", category: "HealthKit")

    // MARK: - Service Dependencies
    private let queryService: HealthKitQueryServiceProtocol
    private let cacheService: HealthKitCacheServiceProtocol
    private let baselineCalculator: HealthKitBaselineCalculatorProtocol
    private let historicalService: HealthKitHistoricalServiceProtocol

    // MARK: - Manual Tracking
    var manualCycleTracker: ManualCycleTracker?

    // MARK: - Published State
    @Published private(set) var latestHRV: Double?
    @Published private(set) var latestRestingHR: Double?
    @Published private(set) var latestSleepHours: Double?
    @Published private(set) var latestWorkoutMinutes: Double?
    @Published private(set) var latestCycleDay: Int?
    @Published private(set) var latestFlowLevel: String?

    // MARK: - Type References
    private lazy var hrvType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
    private lazy var restingHeartType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)
    private lazy var sleepType: HKCategoryType? = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
    private let workoutType = HKObjectType.workoutType()
    private lazy var menstrualFlowType: HKCategoryType? = HKCategoryType.categoryType(forIdentifier: .menstrualFlow)

    nonisolated var isHealthDataAvailable: Bool { queryService.isHealthDataAvailable }

    // MARK: - Initialisation

    init(
        queryService: HealthKitQueryServiceProtocol,
        cacheService: HealthKitCacheServiceProtocol,
        baselineCalculator: HealthKitBaselineCalculatorProtocol,
        historicalService: HealthKitHistoricalServiceProtocol
    ) {
        self.queryService = queryService
        self.cacheService = cacheService
        self.baselineCalculator = baselineCalculator
        self.historicalService = historicalService
    }

    /// Convenience initialiser with default services
    convenience init(dataProvider: HealthKitDataProvider = RealHealthKitDataProvider()) {
        let queryService = HealthKitQueryService(dataProvider: dataProvider)
        let cacheService = HealthKitCacheService()
        let baselineCalculator = HealthKitBaselineCalculator(queryService: queryService)
        let historicalService = HealthKitHistoricalService(queryService: queryService, cacheService: cacheService)
        self.init(queryService: queryService, cacheService: cacheService, baselineCalculator: baselineCalculator, historicalService: historicalService)
    }

    nonisolated deinit {
        // Queries should have been stopped via cleanup() call
    }
}

// MARK: - ResourceManageable conformance

extension HealthKitAssistant: ResourceManageable {
    nonisolated func start() async throws {
        // Services are initialised in init, but we can bootstrap here
        await bootstrapAuthorizations()
    }

    nonisolated func cleanup() {
        Task { @MainActor in
            _cleanup()
        }
    }

    @MainActor
    private func _cleanup() {
        if let queryService = queryService as? HealthKitQueryService {
            queryService.cleanup()
        }

        // Clear cached state
        latestHRV = nil
        latestRestingHR = nil
        latestSleepHours = nil
        latestWorkoutMinutes = nil
        latestCycleDay = nil
        latestFlowLevel = nil

        // Clear manual tracker reference
        manualCycleTracker = nil
    }

    // MARK: - Debug Helpers (for testing)

    #if DEBUG
    /// Expose cache timestamps for testing purposes
    func _setCacheTimestamp(_ date: Date, for metric: String) async {
        let healthMetric: HealthMetric
        switch metric {
        case "hrv": healthMetric = .hrv
        case "restingHR": healthMetric = .restingHR
        case "sleep": healthMetric = .sleep
        case "workout": healthMetric = .workout
        case "cycle": healthMetric = .cycleDay
        default: return
        }
        await cacheService.setLastSampleDate(date, for: healthMetric)
    }

    /// Expose active queries count for testing (always 0 with new architecture)
    var _activeQueriesCount: Int { 0 }
    #endif

    // MARK: - Bootstrapping

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

    /// Request HealthKit permissions (delegates to query service)
    func requestPermissions() async throws {
        try await queryService.requestPermissions()
    }

    /// Update health metric baselines (delegates to baseline calculator)
    func updateBaselines() async {
        await baselineCalculator.updateBaselines()
    }

    // MARK: - Context Refresh

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

    // MARK: - Recent Data (24-48 hours)

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

    // MARK: - Recent Data Refresh Methods

    private func refreshHRVIfNeeded(force: Bool = false) async {
        guard let hrvType else {
            logger.warning("HRV type not available on this device")
            return
        }
        guard await cacheService.shouldRefresh(metric: .hrv, cacheDuration: AppConstants.HealthKit.hrvCacheDuration, force: force) else {
            return
        }
        do {
            let start = DateUtility.now().addingTimeInterval(-AppConstants.HealthKit.quantitySampleLookback)
            let end = DateUtility.now()
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let samples = try await queryService.fetchQuantitySamples(
                for: hrvType,
                start: start,
                end: end,
                limit: AppConstants.HealthKit.hrvSampleLimit,
                sortDescriptors: [sort]
            )
            if let latest = samples.first {
                latestHRV = latest.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                await cacheService.setLastSampleDate(latest.endDate, for: .hrv)
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
        guard await cacheService.shouldRefresh(metric: .restingHR, cacheDuration: AppConstants.HealthKit.restingHeartRateCacheDuration, force: force) else {
            let lastSampleDate = await cacheService.getLastSampleDate(for: .restingHR) ?? DateUtility.now()
            logger.debug("Using cached resting heart rate from \(lastSampleDate)")
            return
        }
        do {
            logger.debug("Fetching resting heart rate samples from last \(AppConstants.HealthKit.quantitySampleLookback / 3600) hours")
            let start = DateUtility.now().addingTimeInterval(-AppConstants.HealthKit.quantitySampleLookback)
            let end = DateUtility.now()
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let samples = try await queryService.fetchQuantitySamples(
                for: restingHeartType,
                start: start,
                end: end,
                limit: AppConstants.HealthKit.restingHeartRateSampleLimit,
                sortDescriptors: [sort]
            )
            logger.debug("Retrieved \(samples.count) resting heart rate samples")
            if let latest = samples.first {
                let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                latestRestingHR = latest.quantity.doubleValue(for: unit)
                await cacheService.setLastSampleDate(latest.endDate, for: .restingHR)
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
        guard await cacheService.shouldRefresh(metric: .sleep, cacheDuration: AppConstants.HealthKit.sleepCacheDuration, force: force) else {
            return
        }
        do {
            // Get sleep from last 24 hours
            let end = DateUtility.now()
            let start = end.addingTimeInterval(-AppConstants.HealthKit.dailyMetricsLookback)

            let samples = try await queryService.fetchSleepSamples(start: start, end: end)

            let totalSeconds = samples.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            latestSleepHours = totalSeconds / 3600.0
            await cacheService.setLastSampleDate(end, for: .sleep)
        } catch {
            logger.error("Failed to refresh sleep: \(error.localizedDescription)")
        }
    }

    private func refreshWorkoutIfNeeded(force: Bool = false) async {
        guard await cacheService.shouldRefresh(metric: .workout, cacheDuration: AppConstants.HealthKit.workoutCacheDuration, force: force) else {
            return
        }
        do {
            // Get workouts from last 24 hours
            let end = DateUtility.now()
            let start = end.addingTimeInterval(-AppConstants.HealthKit.dailyMetricsLookback)

            let samples = try await queryService.fetchWorkouts(
                start: start,
                end: end,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            )

            let totalSeconds = samples.reduce(0.0) { total, workout in
                total + workout.duration
            }
            latestWorkoutMinutes = totalSeconds / 60.0
            await cacheService.setLastSampleDate(end, for: .workout)
        } catch {
            logger.error("Failed to refresh workout: \(error.localizedDescription)")
        }
    }

    private func refreshCycleIfNeeded(force: Bool = false) async {
        guard let menstrualFlowType else {
            logger.warning("Menstrual flow type not available on this device")
            return
        }
        guard await cacheService.shouldRefresh(metric: .cycleDay, cacheDuration: AppConstants.HealthKit.cycleCacheDuration, force: force) else {
            return
        }
        do {
            // Get menstrual flow from last 45 days to calculate cycle day
            let end = DateUtility.now()
            let start = end.addingTimeInterval(-AppConstants.HealthKit.menstrualCycleLookback)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let samples = try await queryService.fetchCategorySamples(
                for: menstrualFlowType,
                start: start,
                end: end,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            )

            // Find most recent period start (flow not unspecified)
            let periodStarts = samples.filter { sample in
                let value = HKCategoryValueVaginalBleeding(rawValue: sample.value)
                return value != .unspecified && value != Optional<HKCategoryValueVaginalBleeding>.none
            }

            if let mostRecentPeriodStart = periodStarts.first {
                let calendar = Calendar.current
                let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: mostRecentPeriodStart.startDate), to: calendar.startOfDay(for: DateUtility.now())).day ?? 0
                latestCycleDay = daysSinceStart + 1
            } else {
                latestCycleDay = nil
            }

            // Get today's flow level
            let (todayStart, todayEnd) = DateUtility.dayBounds(for: DateUtility.now(), calendar: Calendar.current)
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

            await cacheService.setLastSampleDate(end, for: .cycleDay)
        } catch {
            logger.error("Failed to refresh cycle data: \(error.localizedDescription)")
        }
    }

    // MARK: - Historical Data (Specific Dates)

    /// Get HRV for a specific date (cached per calendar day)
    func hrvForDate(_ date: Date) async -> Double? {
        await historicalService.hrvForDate(date)
    }

    /// Get resting heart rate for a specific date (cached per calendar day)
    func restingHRForDate(_ date: Date) async -> Double? {
        await historicalService.restingHRForDate(date)
    }

    /// Get sleep hours for a specific date (cached per calendar day)
    func sleepHoursForDate(_ date: Date) async -> Double? {
        await historicalService.sleepHoursForDate(date)
    }

    /// Get workout minutes for a specific date (cached per calendar day)
    func workoutMinutesForDate(_ date: Date) async -> Double? {
        await historicalService.workoutMinutesForDate(date)
    }

    /// Get cycle day for a specific date (cached per calendar day)
    func cycleDayForDate(_ date: Date) async -> Int? {
        await historicalService.cycleDayForDate(date)
    }

    /// Get menstrual flow level for a specific date (cached per calendar day)
    func flowLevelForDate(_ date: Date) async -> String? {
        await historicalService.flowLevelForDate(date)
    }

    // MARK: - Detailed Sleep Data

    /// Fetches detailed sleep data including bed time and wake time from the last 24 hours
    func fetchDetailedSleepData() async -> (bedTime: Date?, wakeTime: Date?, totalHours: Double?)? {
        await queryService.fetchDetailedSleepData()
    }

    // MARK: - Sleep Import Support

    /// Fetches raw sleep samples for a date range (used by SleepImportService)
    func fetchSleepSamples(from startDate: Date, to endDate: Date) async throws -> [HKCategorySample] {
        try await queryService.fetchSleepSamples(start: startDate, end: endDate)
    }
}
