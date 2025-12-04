// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// HealthKitBaselineCalculator.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Calculator for HealthKit metric baselines.
//
import Foundation
import HealthKit
import os.log

// MARK: - Protocols

/// Service responsible for calculating baseline health metrics from historical data
protocol HealthKitBaselineCalculatorProtocol: Sendable {
    /// Update all health metric baselines from historical data (typically 30 days)
    func updateBaselines() async

    /// Update HRV baseline from historical data
    func updateHRVBaseline() async

    /// Update resting heart rate baseline from historical data
    func updateRestingHRBaseline() async
}

// MARK: - Implementation

/// Calculates baseline metrics for HRV and resting heart rate from 30-day historical data
@MainActor
final class HealthKitBaselineCalculator: HealthKitBaselineCalculatorProtocol {
    private let logger = Logger(subsystem: "app.murmur", category: "HealthKitBaseline")
    private let queryService: HealthKitQueryServiceProtocol

    private lazy var hrvType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
    private lazy var restingHeartType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)

    init(queryService: HealthKitQueryServiceProtocol) {
        self.queryService = queryService
    }

    // MARK: - Baseline Calculation

    func updateBaselines() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.updateHRVBaseline() }
            group.addTask { await self.updateRestingHRBaseline() }
        }
    }

    func updateHRVBaseline() async {
        guard let hrvType else {
            logger.warning("HRV type not available on this device")
            return
        }

        do {
            // Fetch 30 days of HRV data
            let start = DateUtility.now().addingTimeInterval(-30 * 24 * 3600)
            let end = DateUtility.now()
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let samples = try await queryService.fetchQuantitySamples(
                for: hrvType,
                start: start,
                end: end,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            )

            let values = samples.map { $0.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)) }
            if !values.isEmpty {
                HealthMetricBaselines.shared.updateHRVBaseline(from: values)
                logger.info("Updated HRV baseline with \(values.count) samples")
            }
        } catch {
            logger.error("Failed to update HRV baseline: \(error.localizedDescription)")
        }
    }

    func updateRestingHRBaseline() async {
        guard let restingHeartType else {
            logger.warning("Resting heart rate type not available on this device")
            return
        }

        do {
            // Fetch 30 days of resting HR data
            let start = DateUtility.now().addingTimeInterval(-30 * 24 * 3600)
            let end = DateUtility.now()
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let samples = try await queryService.fetchQuantitySamples(
                for: restingHeartType,
                start: start,
                end: end,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            )

            let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let values = samples.map { $0.quantity.doubleValue(for: unit) }
            if !values.isEmpty {
                HealthMetricBaselines.shared.updateRestingHRBaseline(from: values)
                logger.info("Updated resting HR baseline with \(values.count) samples")
            }
        } catch {
            logger.error("Failed to update resting HR baseline: \(error.localizedDescription)")
        }
    }
}
