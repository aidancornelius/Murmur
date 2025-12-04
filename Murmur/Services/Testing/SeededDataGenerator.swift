// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// SeededDataGenerator.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Generator for creating deterministic test data.
//
import Foundation

// MARK: - Deterministic Random Number Generator

/// Deterministic pseudo-random number generator using Linear Congruential Generator (LCG)
/// Ensures reproducible random values when seeded consistently
struct SeededRandom {
    private var state: UInt64

    init(seed: Int) {
        // Use non-zero seed (LCG requires non-zero state)
        self.state = UInt64(max(1, seed))
    }

    /// Generate next random value in [0, 1) range
    mutating func next() -> Double {
        // LCG parameters from Numerical Recipes
        state = state &* 1664525 &+ 1013904223
        return Double(state % 1000000) / 1000000.0
    }

    /// Generate random value in specified Double range
    mutating func next(in range: ClosedRange<Double>) -> Double {
        let normalized = next()
        return range.lowerBound + normalized * (range.upperBound - range.lowerBound)
    }

    /// Generate random integer in specified range
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let normalized = next()
        let rangeSize = Double(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(normalized * rangeSize)
    }
}

// MARK: - Day Type Classification

/// Day type classification for generating appropriate fallback values
enum DayType {
    case pem
    case flare
    case menstrual
    case rest
    case better
    case normal
}

// MARK: - Data Generator

/// Generates deterministic fallback health values for testing and seeding
struct SeededDataGenerator {
    /// Generate fallback HRV value based on day type
    static func getFallbackHRV(for dayType: DayType, seed: Int) -> Double {
        // Use different seed offsets for each day type to ensure unique values
        let dayOffset: Int
        switch dayType {
        case .pem: dayOffset = 0
        case .flare: dayOffset = 100
        case .menstrual: dayOffset = 200
        case .rest: dayOffset = 300
        case .better: dayOffset = 400
        case .normal: dayOffset = 500
        }

        var rng = SeededRandom(seed: seed + dayOffset)

        switch dayType {
        case .pem, .flare:
            return 22.0 + rng.next(in: -5...5)
        case .better:
            return 55.0 + rng.next(in: -8...8)
        case .normal, .menstrual, .rest:
            return 38.0 + rng.next(in: -8...8)
        }
    }

    /// Generate fallback resting heart rate based on day type
    static func getFallbackRestingHR(for dayType: DayType, seed: Int) -> Double {
        // Use different seed offsets for each day type to ensure unique values
        let dayOffset: Int
        switch dayType {
        case .pem: dayOffset = 0
        case .flare: dayOffset = 100
        case .menstrual: dayOffset = 200
        case .rest: dayOffset = 300
        case .better: dayOffset = 400
        case .normal: dayOffset = 500
        }

        var rng = SeededRandom(seed: seed + 1 + dayOffset) // +1 for different base from HRV

        switch dayType {
        case .pem, .flare:
            return 78.0 + rng.next(in: -4...4)
        case .better:
            return 58.0 + rng.next(in: -4...4)
        case .normal, .menstrual, .rest:
            return 65.0 + rng.next(in: -4...4)
        }
    }

    /// Generate fallback sleep hours based on day type
    static func getFallbackSleepHours(for dayType: DayType, seed: Int) -> Double {
        var rng = SeededRandom(seed: seed + 2)

        switch dayType {
        case .pem, .flare:
            return 5.5 + rng.next(in: -1.5...1.5)
        case .menstrual, .rest:
            return 6.5 + rng.next(in: -1.0...1.0)
        case .better:
            return 8.0 + rng.next(in: -0.5...0.5)
        case .normal:
            return 7.5 + rng.next(in: -1.0...1.0)
        }
    }

    /// Generate fallback workout minutes based on day type
    static func getFallbackWorkoutMinutes(for dayType: DayType, seed: Int) -> Double {
        var rng = SeededRandom(seed: seed + 3)

        switch dayType {
        case .pem, .flare:
            return rng.next(in: 0...10)
        case .menstrual, .rest:
            return rng.next(in: 5...20)
        case .better:
            return rng.next(in: 25...50)
        case .normal:
            return rng.next(in: 15...35)
        }
    }
}
