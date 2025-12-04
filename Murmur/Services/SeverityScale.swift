// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// SeverityScale.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Utility for mapping severity values to display text.
//
import Foundation

struct SeverityScale {
    static func descriptor(for value: Int, isPositive: Bool = false) -> String {
        let level = max(1, min(5, value))

        if isPositive {
            // For positive symptoms (higher is better)
            switch level {
            case 1: return "Very low"
            case 2: return "Low"
            case 3: return "Moderate"
            case 4: return "High"
            default: return "Very high"
            }
        } else {
            // For negative symptoms (lower is better)
            switch level {
            case 1: return "Stable"
            case 2: return "Manageable"
            case 3: return "Challenging"
            case 4: return "Severe"
            default: return "Crisis"
            }
        }
    }
}
