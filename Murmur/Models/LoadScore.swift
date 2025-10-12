//
//  LoadScore.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import Foundation

/// Represents the accumulated activity load with symptom-aware decay
struct LoadScore: Hashable {
    let date: Date
    let rawLoad: Double
    let decayedLoad: Double
    let riskLevel: RiskLevel

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
