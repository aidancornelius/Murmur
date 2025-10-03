//
//  SeverityBadge.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI

struct SeverityBadge: View {
    enum Precision {
        case integer
        case oneDecimal
    }

    let value: Double
    var precision: Precision
    var isPositive: Bool

    @Environment(\.colorScheme) private var colorScheme

    init(value: Double, precision: Precision = .oneDecimal, isPositive: Bool = false) {
        self.value = value
        self.precision = precision
        self.isPositive = isPositive
    }

    var body: some View {
        Text(formattedValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.severityColor(for: value, colorScheme: colorScheme).opacity(0.2), in: Capsule())
            .foregroundStyle(Color.severityColor(for: value, colorScheme: colorScheme).opacity(0.9))
            .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let level = Int(round(value))
        return SeverityScale.descriptor(for: level, isPositive: isPositive)
    }

    private var formattedValue: String {
        switch precision {
        case .integer:
            return "\(Int(round(value)))"
        case .oneDecimal:
            return String(format: "%.1f", value)
        }
    }
}
