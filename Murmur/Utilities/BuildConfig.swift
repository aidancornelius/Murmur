//
//  BuildConfig.swift
//  Murmur
//
//  Quick utility to check build configuration at runtime
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
