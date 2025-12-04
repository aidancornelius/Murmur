// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Color+Severity.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// SwiftUI Color extension for severity-based colours.
//
import SwiftUI
import UIKit

extension Color {
    /// Returns theme colors that represent a severity bucket.
    static func severityColor(for value: Double, colorScheme: ColorScheme) -> Color {
        let level = max(1, min(5, Int(round(value))))
        let palette = AppearanceManager.palette(for: colorScheme)

        switch level {
        case 1: return palette.color(for: "severity1")
        case 2: return palette.color(for: "severity2")
        case 3: return palette.color(for: "severity3")
        case 4: return palette.color(for: "severity4")
        case 5: return palette.color(for: "severity5")
        default: return palette.color(for: "accent")
        }
    }
}
