//
//  LoadScoreCard.swift
//  Murmur
//
//  Extracted from DayDetailView.swift on 10/10/2025.
//

import SwiftUI

/// Instrument cluster layout: load gauge (left, larger) + intensity gauge (right, smaller)
struct LoadScoreCard: View {
    let loadScore: LoadScore
    var feltLoadMultiplier: Double?
    var intensity: Double?
    var entryCount: Int?

    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    private var displayLoad: Double {
        if let feltLoad = loadScore.feltLoad { return feltLoad }
        if let multiplier = feltLoadMultiplier { return loadScore.decayedLoad * multiplier }
        return loadScore.decayedLoad
    }

    private var hasFeltAdjustment: Bool {
        loadScore.feltLoad != nil || (feltLoadMultiplier != nil && feltLoadMultiplier != 1.0)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Instrument cluster
            HStack(alignment: .bottom, spacing: 16) {
                // Left gauge: Load (larger)
                LoadGauge(
                    value: displayLoad,
                    maxValue: 100,
                    label: "load",
                    status: riskLevelForDisplay.description.lowercased(),
                    color: colorForRisk,
                    size: 140,
                    strokeWidth: 8,
                    showPercent: true
                )

                // Right gauge: Intensity (smaller)
                if let intensity {
                    IntensityGauge(
                        value: intensity,
                        maxValue: 5,
                        label: "avg",
                        color: palette.accentColor,
                        size: 100,
                        strokeWidth: 6
                    )
                }
            }

            // Supporting info
            HStack(spacing: 16) {
                if let count = entryCount, count > 0 {
                    Label("\(count) logged", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if hasFeltAdjustment {
                    Label("\(Int(loadScore.decayedLoad))% calc", systemImage: "function")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var riskLevelForDisplay: LoadScore.RiskLevel {
        if loadScore.feltLoad != nil { return loadScore.effectiveRiskLevel }
        if hasFeltAdjustment { return LoadScore.riskLevel(for: displayLoad) }
        return loadScore.riskLevel
    }

    private var colorForRisk: Color {
        riskLevelForDisplay.displayColor
    }

    private var accessibilityDescription: String {
        var desc = "Activity load: \(Int(displayLoad)) percent. \(riskLevelForDisplay.description)."
        if let intensity { desc += " Intensity: \(String(format: "%.1f", intensity))." }
        if let count = entryCount { desc += " \(count) entries logged." }
        return desc
    }
}

// MARK: - Load gauge

private struct LoadGauge: View {
    let value: Double
    let maxValue: Double
    let label: String
    let status: String
    let color: Color
    let size: CGFloat
    let strokeWidth: CGFloat
    var showPercent: Bool = false

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.15), lineWidth: strokeWidth)
                .frame(width: size, height: size)

            // Progress
            Circle()
                .trim(from: 0, to: min(value, maxValue) / maxValue)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int(value))")
                        .font(.system(size: size * 0.28, weight: .ultraLight, design: .rounded))
                        .foregroundStyle(color)
                        .contentTransition(.numericText())

                    if showPercent {
                        Text("%")
                            .font(.system(size: size * 0.12, weight: .light, design: .rounded))
                            .foregroundStyle(color.opacity(0.6))
                            .offset(y: -2)
                    }
                }

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text(status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
                    .padding(.top, 2)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Intensity gauge

private struct IntensityGauge: View {
    let value: Double
    let maxValue: Double
    let label: String
    let color: Color
    let size: CGFloat
    let strokeWidth: CGFloat

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.15), lineWidth: strokeWidth)
                .frame(width: size, height: size)

            // Progress
            Circle()
                .trim(from: 0, to: min(value, maxValue) / maxValue)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 1) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: size * 0.28, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(color)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Metric pill

private struct MetricPill: View {
    let icon: String
    let value: String
    var label: String?
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(.primary)
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
