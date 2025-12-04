// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// BuildConfig.swift
// Created by Aidan Cornelius-Bell on 06/10/2025.
// Build configuration and environment detection.
//
import Foundation

enum BuildConfig {
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static var description: String {
        """
        Build Configuration:
        - Debug: \(isDebug)
        - Simulator: \(isSimulator)
        """
    }
}
