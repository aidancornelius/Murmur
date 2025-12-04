// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// UserDefaultsKeys.swift
// Created by Aidan Cornelius-Bell on 06/10/2025.
// UserDefaults key constants.
//
import Foundation

/// Centralised UserDefaults keys to prevent typos and improve maintainability
enum UserDefaultsKeys {
    // MARK: - Onboarding
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let hasGeneratedSampleData = "hasGeneratedSampleData"
    static let hasSeenUnifiedEventHints = "hasSeenUnifiedEventHints"

    // MARK: - Load Capacity
    static let conditionPreset = "conditionPreset"
    static let loadCapacity = "loadCapacity"
    static let sensitivityProfile = "sensitivityProfile"
    static let recoveryWindow = "recoveryWindow"
    static let personalBaseline = "personalBaseline"
    static let isCalibrating = "isCalibrating"
    static let calibrationDays = "calibrationDays"

    // MARK: - Manual Cycle Tracking
    static let manualCycleTrackingEnabled = "ManualCycleTrackingEnabled"
    static let currentCycleDay = "ManualCycleDay"
    static let cycleDaySetDate = "ManualCycleDaySetDate"

    // MARK: - Appearance
    static let lightPaletteId = "lightPaletteId"
    static let darkPaletteId = "darkPaletteId"

    // MARK: - Security
    static let appLockEnabled = "appLockEnabled"

    // MARK: - Health Metric Baselines
    static let hrvBaseline = "hrvBaseline"
    static let restingHRBaseline = "restingHRBaseline"

    // MARK: - Data Management
    static let symptomSeedVersion = "symptomSeedVersion"

    // MARK: - UI Testing
    static let hasSeededHealthKitData = "hasSeededHealthKitData"

    // MARK: - Sleep import
    static let autoImportSleepEnabled = "autoImportSleepEnabled"
    static let lastSleepImportDate = "lastSleepImportDate"
}