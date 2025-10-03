//
//  HapticFeedback.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import UIKit

/// Provides light haptic feedback for user interactions throughout the app
enum HapticFeedback {
    /// Selection changed (e.g., toggling switches, selecting items)
    case selection

    /// Light impact (e.g., button taps)
    case light

    /// Medium impact (e.g., slider changes, value adjustments)
    case medium

    /// Success feedback (e.g., saving data)
    case success

    /// Warning feedback (e.g., validation errors)
    case warning

    /// Error feedback (e.g., failed operations)
    case error

    /// Triggers the haptic feedback
    func trigger() {
        switch self {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()

        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)

        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)

        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
