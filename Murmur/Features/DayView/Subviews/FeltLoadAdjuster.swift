//
//  FeltLoadAdjuster.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 04/12/2025.
//

import SwiftUI

/// Allows users to adjust how the day's load felt compared to the calculated value
/// Uses a multiplier approach: the felt load = calculated load × multiplier
struct FeltLoadAdjuster: View {
    let calculatedLoad: Double
    @Binding var multiplier: Double?
    let tint: Color

    private let options: [(label: String, short: String, value: Double)] = [
        ("Much lighter", "−−", 0.6),
        ("Lighter", "−", 0.8),
        ("About right", "=", 1.0),
        ("Heavier", "+", 1.2),
        ("Much heavier", "++", 1.4)
    ]

    private var feltLoad: Double {
        calculatedLoad * (multiplier ?? 1.0)
    }

    private var hasAdjustment: Bool {
        multiplier != nil && multiplier != 1.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How did today's load feel?")
                .font(.subheadline)
                .foregroundStyle(.primary)

            HStack(spacing: 0) {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    let isSelected = multiplier == option.value

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            multiplier = option.value
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? tint : tint.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(tint.opacity(isSelected ? 0.6 : 0.25), lineWidth: 1.5)
                                    )

                                Text(option.short)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : tint)
                            }
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                            .shadow(color: isSelected ? tint.opacity(0.3) : .clear, radius: 4, y: 2)

                            Text(option.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isSelected ? .primary : .tertiary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            // Load comparison display
            HStack {
                Spacer()

                HStack(spacing: 8) {
                    Text("Calculated: \(Int(calculatedLoad))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if hasAdjustment {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text("Felt: \(Int(feltLoad))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tint)
                    }
                }

                Spacer()
            }
            .padding(.top, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Load adjustment. Calculated load \(Int(calculatedLoad)) percent\(hasAdjustment ? ", felt load \(Int(feltLoad)) percent" : "")")
        .accessibilityHint("Select how today's load felt compared to calculated")
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var multiplier: Double? = 1.0

        var body: some View {
            VStack(spacing: 32) {
                FeltLoadAdjuster(
                    calculatedLoad: 45,
                    multiplier: $multiplier,
                    tint: Color(hex: "#7BA38E")
                )

                FeltLoadAdjuster(
                    calculatedLoad: 72,
                    multiplier: .constant(1.2),
                    tint: Color(hex: "#5B9A8B")
                )

                FeltLoadAdjuster(
                    calculatedLoad: 30,
                    multiplier: .constant(nil),
                    tint: Color(hex: "#6B8E9B")
                )
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
