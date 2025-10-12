//
//  SleepEvent+LoadContributor.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/12/2025.
//

import Foundation

// MARK: - LoadContributor Conformance

extension SleepEvent: RecoveryModifier {
    /// Effective date for load calculations (use wake time for when sleep impacts the day)
    public var effectiveDate: Date {
        // Use wake time as the effective date since that's when sleep quality impacts the day
        return wakeTime ?? backdatedAt ?? createdAt ?? Date()
    }

    /// Sleep quality as Double (converting from Int16)
    public var quality: Double {
        return Double(self.quality)
    }

    /// Duration in hours calculated from bed and wake times
    public var durationHours: Double {
        guard let bedTime = bedTime, let wakeTime = wakeTime else {
            // If times are missing, return a default
            return 0.0
        }
        return wakeTime.timeIntervalSince(bedTime) / 3600.0
    }

    /// Determine if this is a main sleep block (>3 hours) vs a nap
    public var isMainRecoveryPeriod: Bool {
        return durationHours > 3.0
    }

    /// Recovery modifier based on sleep quality and duration
    /// Override the default implementation to provide sleep-specific logic
    public var recoveryModifier: Double? {
        if isMainRecoveryPeriod {
            // Main sleep block significantly impacts recovery
            switch Int(quality) {
            case 1: return 0.5  // Very poor sleep - 50% slower recovery
            case 2: return 0.7  // Poor sleep - 30% slower recovery
            case 3: return 1.0  // Normal recovery
            case 4: return 1.2  // Good sleep - 20% faster recovery
            case 5: return 1.4  // Excellent sleep - 40% faster recovery
            default: return 1.0
            }
        } else {
            // Naps have minor impact on recovery
            // Good nap slightly helps, poor nap slightly hinders
            return quality >= 4 ? 1.1 : 0.95
        }
    }

    /// Poor quality main sleep adds load burden to the day
    /// Override the default implementation to provide sleep-specific logic
    public var loadContribution: Double {
        // Only very poor main sleep adds load burden
        if isMainRecoveryPeriod && quality <= 2 {
            // Quality 1 = 10 load points (significant impact)
            // Quality 2 = 5 load points (moderate impact)
            return (3.0 - quality) * 5.0
        }
        return 0.0
    }
}

// MARK: - Computed Properties

extension SleepEvent {
    /// Get a formatted duration string
    public var formattedDuration: String {
        let hours = Int(durationHours)
        let minutes = Int((durationHours - Double(hours)) * 60)

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    /// Check if this represents poor quality sleep
    public var isPoorQuality: Bool {
        return quality <= 2
    }

    /// Check if this represents good quality sleep
    public var isGoodQuality: Bool {
        return quality >= 4
    }

    /// Get a description of the sleep type
    public var sleepTypeDescription: String {
        if durationHours < 0.5 {
            return "Rest"
        } else if durationHours <= 3.0 {
            return "Nap"
        } else if durationHours <= 5.0 {
            return "Short sleep"
        } else if durationHours <= 9.0 {
            return "Full sleep"
        } else {
            return "Extended sleep"
        }
    }

    /// Get a quality description
    public var qualityDescription: String {
        switch Int(quality) {
        case 1: return "Very poor"
        case 2: return "Poor"
        case 3: return "Fair"
        case 4: return "Good"
        case 5: return "Excellent"
        default: return "Unknown"
        }
    }

    /// Calculate the impact score (combines load contribution and recovery modification)
    public var sleepImpactScore: Double {
        let loadImpact = loadContribution
        let recoveryImpact = (1.0 - (recoveryModifier ?? 1.0)) * 20.0  // Convert to similar scale
        return loadImpact + abs(recoveryImpact)
    }

    /// Check if HealthKit data is available
    public var hasHealthKitData: Bool {
        return hkSleepHours != nil || hkHRV != nil || hkRestingHR != nil
    }
}