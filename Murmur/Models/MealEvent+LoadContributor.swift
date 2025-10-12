//
//  MealEvent+LoadContributor.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 10/12/2025.
//

import Foundation

// MARK: - LoadContributor Conformance

@MainActor
extension MealEvent: ExertionEvent {
    /// Effective date for load calculations
    public var effectiveDate: Date {
        return backdatedAt ?? createdAt ?? Date()
    }

    /// Physical exertion as Double (converting from optional NSNumber)
    public var physicalExertionValue: Double {
        // Default to 1 (minimal) if no exertion data provided
        return physicalExertion?.doubleValue ?? 1.0
    }

    /// Cognitive exertion as Double (converting from optional NSNumber)
    public var cognitiveExertionValue: Double {
        // Default to 1 (minimal) if no exertion data provided
        return cognitiveExertion?.doubleValue ?? 1.0
    }

    /// Emotional load as Double (converting from optional NSNumber)
    public var emotionalLoadValue: Double {
        // Default to 1 (minimal) if no exertion data provided
        return emotionalLoad?.doubleValue ?? 1.0
    }

    /// Meals don't have explicit duration - return nil
    public var durationMinutesValue: Double? {
        return nil
    }

    /// Meals have half weight (0.5) compared to activities for load contribution
    /// This reflects that meal-related exertion is typically less impactful than activity exertion
    public var exertionWeight: Double {
        return 0.5
    }

    /// Override load contribution to handle optional exertion values
    public var loadContribution: Double {
        // Only contribute load if at least one exertion value is explicitly set
        let hasExertionData = physicalExertion != nil || cognitiveExertion != nil || emotionalLoad != nil

        if !hasExertionData {
            // No exertion data means no load contribution
            return 0.0
        }

        // Use the default calculation from the protocol extension
        let averageExertion = (physicalExertionValue + cognitiveExertionValue + emotionalLoadValue) / 3.0

        // Meals don't have duration, so we use a fixed equivalent (30 minutes)
        let durationWeight = 0.5  // Equivalent to 30 minutes of activity

        // Calculate load: exertion × duration × type weight × base multiplier
        return averageExertion * durationWeight * exertionWeight * 6.0
    }
}

// MARK: - Computed Properties

@MainActor
extension MealEvent {
    /// Check if this meal has any exertion data
    public var hasExertionData: Bool {
        return physicalExertion != nil || cognitiveExertion != nil || emotionalLoad != nil
    }

    /// Check if this meal represents high exertion (e.g., difficult to digest, stressful meal)
    public var isHighExertion: Bool {
        guard hasExertionData else { return false }
        let average = (physicalExertionValue + cognitiveExertionValue + emotionalLoadValue) / 3.0
        return average >= 4.0
    }

    /// Get the meal type as a readable string
    public var mealTypeDescription: String {
        return mealType ?? "Unknown meal"
    }

    /// Get a formatted description of the meal's exertion levels if available
    public var exertionSummary: String? {
        guard hasExertionData else { return nil }
        return "Physical: \(Int(physicalExertionValue)), Cognitive: \(Int(cognitiveExertionValue)), Emotional: \(Int(emotionalLoadValue))"
    }

    /// Calculate the effective load impact for this meal
    public var calculatedLoad: Double {
        return loadContribution
    }
}