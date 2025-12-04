// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DaySummaryCard.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Card component displaying the day's load and intensity gauges.
//
import SwiftUI

/// A unified day summary - delegates to LoadScoreCard when load data exists,
/// otherwise shows a minimal intensity-only view
struct DaySummaryCard: View {
    let summary: DaySummary
    let comparison: DaySummary?
    let metrics: DayMetrics?
    var feltLoadMultiplier: Double?

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appearanceManager: AppearanceManager

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    private var severityTint: Color {
        summary.dominantColor(for: colorScheme)
    }

    var body: some View {
        if let loadScore = summary.loadScore, shouldShowLoadScore(loadScore) {
            // Integrated view with load as hero
            LoadScoreCard(
                loadScore: loadScore,
                feltLoadMultiplier: feltLoadMultiplier,
                intensity: summary.rawAverageSeverity,
                entryCount: summary.entryCount
            )
        } else {
            // Fallback: intensity-only view when no load data
            IntensityOnlyCard(
                severity: summary.rawAverageSeverity,
                entryCount: summary.entryCount,
                tint: severityTint
            )
        }
    }

    private func shouldShowLoadScore(_ loadScore: LoadScore) -> Bool {
        return loadScore.decayedLoad > 0.1 || loadScore.rawLoad > 0.1
    }
}

// MARK: - Intensity-only card (no load data)

private struct IntensityOnlyCard: View {
    let severity: Double
    let entryCount: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 12) {
            // Intensity as hero when no load
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", severity))
                    .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(tint)

                Text("intensity")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .offset(y: -4)
            }

            if entryCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(entryCount) logged")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Average intensity: \(String(format: "%.1f", severity)). \(entryCount) entries logged.")
    }
}

// MARK: - Legacy support

/// A small tile displaying a metric label and value (retained for compatibility)
struct MetricTile: View {
    let title: String
    let value: String
    var emphasizesTrend: Bool = false
    var secondary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(emphasizesTrend ? .caption.bold() : .body.bold())
                .foregroundStyle(emphasizesTrend ? .orange : .primary)
            if let secondary {
                Text(secondary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
