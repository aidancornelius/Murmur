// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ExertionRingSelector.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Ring-style selector for exertion level.
//
import SwiftUI

extension View {
    /// Applies a transformation if a condition is true
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

/// A ring-based selector for exertion levels (1-5 scale)
struct ExertionRingSelector: View {
    let label: String
    @Binding var value: Int
    let color: Color
    var showScale: Bool = true
    var accessibilityId: String? = nil

    private let levels = [1, 2, 3, 4, 5]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !label.isEmpty {
                HStack {
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .if(accessibilityId != nil) { view in
                            view.accessibilityIdentifier(accessibilityId!)
                        }

                    Spacer()

                    if showScale {
                        HStack(spacing: 4) {
                            Text("Low")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("High")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                ForEach(levels, id: \.self) { level in
                    RingButton(
                        level: level,
                        isSelected: value == level,
                        color: color
                    ) {
                        value = level
                    }
                }
            }
            // Add an invisible accessibility element when label is empty
            .if(label.isEmpty && accessibilityId != nil) { view in
                view.accessibilityElement(children: .contain)
                    .accessibilityIdentifier(accessibilityId!)
            }
        }
    }

    struct RingButton: View {
        let level: Int
        let isSelected: Bool
        let color: Color
        let action: () -> Void

        var label: String {
            switch level {
            case 1: return "Very low"
            case 2: return "Low"
            case 3: return "Moderate"
            case 4: return "High"
            case 5: return "Very high"
            default: return ""
            }
        }

        var body: some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .stroke(
                            color.opacity(isSelected ? 1 : 0.3),
                            lineWidth: isSelected ? 4 : 2
                        )

                    if isSelected {
                        Circle()
                            .fill(color.opacity(0.15))
                    }

                    Text("\(level)")
                        .font(.caption.bold())
                        .foregroundStyle(isSelected ? color : .secondary)
                }
                .frame(width: 44, height: 44)
                .scaleEffect(isSelected ? 1.1 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label), level \(level)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}
