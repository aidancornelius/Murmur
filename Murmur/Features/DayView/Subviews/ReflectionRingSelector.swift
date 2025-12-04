// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ReflectionRingSelector.swift
// Created by Aidan Cornelius-Bell on 04/12/2025.
// Ring-style selector for felt-load adjustment.
//
import SwiftUI

/// A ring-based selector for reflection levels (1-5 scale) with progressive fill
/// Unlike ExertionRingSelector, this fills dots up to the selected value to indicate "how much"
struct ReflectionRingSelector: View {
    let label: String
    let lowLabel: String
    let highLabel: String
    @Binding var value: Int?
    let tint: Color

    private let levels = [1, 2, 3, 4, 5]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)

            HStack(spacing: 0) {
                Text(lowLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 56, alignment: .leading)

                Spacer()

                HStack(spacing: 14) {
                    ForEach(levels, id: \.self) { level in
                        ReflectionDot(
                            level: level,
                            isFilled: (value ?? 0) >= level,
                            isSelected: value == level,
                            tint: tint
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                value = level
                            }
                        }
                    }
                }

                Spacer()

                Text(highLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value.map { "\($0) out of 5" } ?? "not set")")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if let current = value, current < 5 {
                    value = current + 1
                } else if value == nil {
                    value = 1
                }
            case .decrement:
                if let current = value, current > 1 {
                    value = current - 1
                }
            @unknown default:
                break
            }
        }
    }
}

/// A single dot in the reflection selector
private struct ReflectionDot: View {
    let level: Int
    let isFilled: Bool
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    private var accessibilityLabel: String {
        switch level {
        case 1: return "Not at all"
        case 2: return "A little"
        case 3: return "Somewhat"
        case 4: return "Quite a bit"
        case 5: return "Very much"
        default: return "Level \(level)"
        }
    }

    var body: some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Circle()
                .fill(isFilled ? tint : tint.opacity(0.12))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(tint.opacity(isFilled ? 0.6 : 0.25), lineWidth: 1.5)
                )
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .shadow(color: isSelected ? tint.opacity(0.3) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isFilled ? .isSelected : [])
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var value: Int? = 3

        var body: some View {
            VStack(spacing: 24) {
                ReflectionRingSelector(
                    label: "Body colouring mood",
                    lowLabel: "Not at all",
                    highLabel: "Very much",
                    value: $value,
                    tint: Color(hex: "#7BA38E")
                )

                ReflectionRingSelector(
                    label: "Mind showing up in body",
                    lowLabel: "Not at all",
                    highLabel: "Very much",
                    value: .constant(2),
                    tint: Color(hex: "#5B9A8B")
                )

                ReflectionRingSelector(
                    label: "Space given for self",
                    lowLabel: "None",
                    highLabel: "Plenty",
                    value: .constant(nil),
                    tint: Color(hex: "#6B8E9B")
                )
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
