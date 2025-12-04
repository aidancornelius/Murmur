// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ActivityEvent+LoadContributor.swift
// Created by Aidan Cornelius-Bell on 12/10/2025.
// LoadContributor protocol conformance for ActivityEvent.
//
import Foundation

// MARK: - LoadContributor Conformance

@MainActor
extension ActivityEvent: ExertionEvent {
    /// Effective date for load calculations
    public var effectiveDate: Date {
        return backdatedAt ?? createdAt ?? DateUtility.now()
    }

    /// Physical exertion as Double (converting from Int16)
    public var physicalExertionValue: Double {
        return Double(physicalExertion)
    }

    /// Cognitive exertion as Double (converting from Int16)
    public var cognitiveExertionValue: Double {
        return Double(cognitiveExertion)
    }

    /// Emotional load as Double (converting from Int16)
    public var emotionalLoadValue: Double {
        return Double(emotionalLoad)
    }

    /// Duration in minutes as optional Double
    public var durationMinutesValue: Double? {
        return durationMinutes?.doubleValue
    }

    /// Activities have full weight (1.0) for load contribution
    public var exertionWeight: Double {
        return 1.0
    }
}

// MARK: - Computed Properties

@MainActor
extension ActivityEvent {
    /// Convenience property to access the calculated load contribution
    public var calculatedLoad: Double {
        return loadContribution
    }

    /// Check if this activity represents high exertion
    public var isHighExertion: Bool {
        let average = (physicalExertionValue + cognitiveExertionValue + emotionalLoadValue) / 3.0
        return average >= 4.0
    }

    /// Get a formatted description of the activity's exertion levels
    public var exertionSummary: String {
        return "Physical: \(Int(physicalExertion)), Cognitive: \(Int(cognitiveExertion)), Emotional: \(Int(emotionalLoad))"
    }
}