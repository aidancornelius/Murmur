// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// LoadScore.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Load score calculation model with component breakdowns.
//
import Foundation

/// Represents the accumulated activity load with symptom-aware decay
struct LoadScore: Hashable {
    let date: Date
    let rawLoad: Double
    let decayedLoad: Double
    let riskLevel: RiskLevel

    /// The felt load after applying reflection multiplier (nil if no reflection)
    let feltLoad: Double?

    /// The reflection multiplier applied (nil if no reflection)
    let reflectionMultiplier: Double?

    /// The effective load used for subsequent day calculations
    /// Uses felt load if available, otherwise calculated decayed load
    var effectiveLoad: Double {
        feltLoad ?? decayedLoad
    }

    /// Risk level based on felt load if available
    @MainActor
    var effectiveRiskLevel: RiskLevel {
        guard let felt = feltLoad else { return riskLevel }
        return LoadScore.riskLevel(for: felt)
    }

    /// Convenience initialiser for backwards compatibility (no reflection)
    init(date: Date, rawLoad: Double, decayedLoad: Double, riskLevel: RiskLevel) {
        self.date = date
        self.rawLoad = rawLoad
        self.decayedLoad = decayedLoad
        self.riskLevel = riskLevel
        self.feltLoad = nil
        self.reflectionMultiplier = nil
    }

    /// Full initialiser with reflection support
    init(date: Date, rawLoad: Double, decayedLoad: Double, riskLevel: RiskLevel,
         reflectionMultiplier: Double?) {
        self.date = date
        self.rawLoad = rawLoad
        self.decayedLoad = decayedLoad
        self.riskLevel = riskLevel
        self.reflectionMultiplier = reflectionMultiplier
        if let multiplier = reflectionMultiplier {
            self.feltLoad = decayedLoad * multiplier
        } else {
            self.feltLoad = nil
        }
    }

    /// Calculate risk level for a given load value using default thresholds
    /// For custom thresholds, use the overload with explicit thresholds parameter
    @MainActor
    static func riskLevel(for load: Double) -> RiskLevel {
        let config = LoadCapacityManager.shared.configuration.thresholds
        return riskLevel(for: load, thresholds: config)
    }

    /// Calculate risk level for a given load value with explicit thresholds
    static func riskLevel(for load: Double, thresholds: LoadThresholds) -> RiskLevel {
        if load < thresholds.safe {
            return .safe
        } else if load < thresholds.caution {
            return .caution
        } else if load < thresholds.high {
            return .high
        } else {
            return .critical
        }
    }

    enum RiskLevel: Int, Comparable, Hashable {
        case safe = 0
        case caution = 1
        case high = 2
        case critical = 3

        var description: String {
            switch self {
            case .safe: return "Safe"
            case .caution: return "Caution"
            case .high: return "High risk"
            case .critical: return "Rest needed"
            }
        }

        static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

}
