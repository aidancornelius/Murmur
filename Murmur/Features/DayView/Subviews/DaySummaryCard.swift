//
//  DaySummaryCard.swift
//  Murmur
//
//  Extracted from DayDetailView.swift on 10/10/2025.
//

import SwiftUI

/// A card displaying a summary of the day's symptoms with metrics
struct DaySummaryCard: View {
    let summary: DaySummary
    let comparison: DaySummary?
    let metrics: DayMetrics?

    @Environment(\.colorScheme) private var colorScheme

    private var severityTint: Color {
        summary.dominantColor(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average intensity")
                        .font(.headline)
                    ProgressView(value: min(summary.rawAverageSeverity, 5), total: 5)
                        .tint(severityTint)
                }
                Spacer()
                SeverityBadge(value: summary.rawAverageSeverity)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Average intensity: \(SeverityScale.descriptor(for: Int(summary.rawAverageSeverity)))")

            HStack(spacing: 16) {
                MetricTile(title: "Logged", value: "\(summary.entryCount)")
                MetricTile(title: "Different symptoms", value: "\(summary.uniqueSymptoms)")
                if let comparison, let delta = delta(from: comparison) {
                    MetricTile(title: "vs yesterday", value: delta, emphasizesTrend: true)
                }
            }

            if let metrics, (metrics.predominantState != nil || metrics.cycleDay != nil || (metrics.averageHRV ?? 0) > 0 || (metrics.averageRestingHR ?? 0) > 0 || metrics.primaryLocation != nil) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        if let state = metrics.predominantState {
                            MetricTile(title: "Feeling", value: state.displayText)
                        }
                        if let cycleDay = metrics.cycleDay, cycleDay > 0 {
                            MetricTile(title: "Cycle day", value: "Day \(cycleDay)")
                        }
                        if let hrv = metrics.averageHRV, hrv > 0 {
                            MetricTile(title: "HRV", value: String(format: "%.0f ms", hrv))
                        }
                        if let resting = metrics.averageRestingHR, resting > 0 {
                            MetricTile(title: "Heart rate", value: String(format: "%.0f bpm", resting))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())

                    if let location = metrics.primaryLocation {
                        Label(location, systemImage: "location.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let loadScore = summary.loadScore, shouldShowLoadScore(loadScore) {
                LoadScoreCard(loadScore: loadScore)
            }
        }
        .padding(.vertical, 8)
    }

    private func shouldShowLoadScore(_ loadScore: LoadScore) -> Bool {
        // Only show if there's meaningful load (> 0) or activities have been logged
        return loadScore.decayedLoad > 0.1 || loadScore.rawLoad > 0.1
    }

    private func delta(from comparison: DaySummary) -> String? {
        let difference = summary.averageSeverity - comparison.averageSeverity
        guard abs(difference) >= 0.1 else { return "∙" }
        let symbol = difference >= 0 ? "▲" : "▼"
        return "\(symbol) \(String(format: "%.1f", abs(difference)))"
    }
}

/// A small tile displaying a metric label and value
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
