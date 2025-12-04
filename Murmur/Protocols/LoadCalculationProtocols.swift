// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// LoadCalculationProtocols.swift
// Created by Aidan Cornelius-Bell on 12/10/2025.
// Protocols defining the load calculation interface.
//
import Foundation

// MARK: - Base Protocol

/// Base protocol for any event that contributes to or modifies load calculations
@MainActor
protocol LoadContributor {
    /// The effective date for this contribution (backdatedAt or createdAt)
    var effectiveDate: Date { get }

    /// Direct load contribution (0 for events that only modify recovery)
    var loadContribution: Double { get }

    /// Optional impact on recovery rate (1.0 = normal, <1.0 = slower, >1.0 = faster)
    var recoveryModifier: Double? { get }
}

// MARK: - Exertion Protocol

/// Protocol for events with physical, cognitive, and emotional exertion properties
@MainActor
protocol ExertionEvent: LoadContributor {
    /// Physical exertion level (1-5 scale)
    var physicalExertionValue: Double { get }

    /// Cognitive exertion level (1-5 scale)
    var cognitiveExertionValue: Double { get }

    /// Emotional load level (1-5 scale)
    var emotionalLoadValue: Double { get }

    /// Optional duration in minutes (for activities)
    var durationMinutesValue: Double? { get }

    /// Weight multiplier for this type of event (e.g., 1.0 for activities, 0.5 for meals)
    var exertionWeight: Double { get }
}

// MARK: - Default Implementations

extension ExertionEvent {
    /// Default load contribution calculation for exertion-based events
    var loadContribution: Double {
        // Average the three exertion types
        let averageExertion = (physicalExertionValue + cognitiveExertionValue + emotionalLoadValue) / 3.0

        // Apply duration weight if available
        let durationWeight: Double
        if let minutes = durationMinutesValue {
            // Cap duration weight at 2 hours for scaling
            durationWeight = min(minutes / 60.0, 2.0)
        } else {
            // Default to 1 hour equivalent if no duration specified
            durationWeight = 1.0
        }

        // Calculate load: exertion × duration × type weight × base multiplier
        // Base multiplier of 6.0 keeps scale consistent with existing calculations
        return averageExertion * durationWeight * exertionWeight * 6.0
    }

    /// Exertion events don't modify recovery by default
    var recoveryModifier: Double? {
        return nil
    }
}

// MARK: - Recovery Protocol

/// Protocol for events that primarily affect recovery rate (like sleep)
@MainActor
protocol RecoveryModifier: LoadContributor {
    /// Quality or effectiveness rating (1-5 scale)
    var qualityValue: Double { get }

    /// Duration in hours
    var durationHours: Double { get }

    /// Whether this is a main recovery period (e.g., main sleep vs nap)
    var isMainRecoveryPeriod: Bool { get }
}

// MARK: - Recovery Default Implementations

extension RecoveryModifier {
    /// Calculate recovery impact based on quality and duration
    var recoveryModifier: Double? {
        if isMainRecoveryPeriod {
            // Main sleep/recovery periods have significant impact
            switch Int(qualityValue) {
            case 1: return 0.5  // Very poor - 50% slower recovery
            case 2: return 0.7  // Poor - 30% slower recovery
            case 3: return 1.0  // Normal recovery
            case 4: return 1.2  // Good - 20% faster recovery
            case 5: return 1.4  // Excellent - 40% faster recovery
            default: return 1.0
            }
        } else {
            // Naps and short recovery periods have minor impact
            return qualityValue >= 4 ? 1.1 : 0.95
        }
    }

    /// Poor quality main recovery periods add load burden
    var loadContribution: Double {
        // Only very poor main sleep/recovery adds load
        if isMainRecoveryPeriod && qualityValue <= 2 {
            // Quality 1 = 10 load points, Quality 2 = 5 load points
            return (3.0 - qualityValue) * 5.0
        }
        return 0
    }
}

// MARK: - Event Type Enum

/// Categorises different types of load contributors for processing
enum LoadContributorType {
    case activity
    case meal
    case sleep
    case symptom
    case other
}

// MARK: - Type Identification

extension LoadContributor {
    /// Identify the type of contributor (used for analytics and configuration)
    var contributorType: LoadContributorType {
        switch self {
        case is ActivityEvent:
            return .activity
        case is MealEvent:
            return .meal
        case is SleepEvent:
            return .sleep
        case is SymptomEntry:
            return .symptom
        default:
            return .other
        }
    }
}