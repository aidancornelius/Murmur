//
//  LoadScoreCard.swift
//  Murmur
//
//  Extracted from DayDetailView.swift on 10/10/2025.
//

import SwiftUI

/// A card displaying the activity load score with risk level and advice
struct LoadScoreCard: View {
    let loadScore: LoadScore
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .foregroundStyle(colorForRisk)
                Text("Activity load")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(Int(loadScore.decayedLoad))%")
                    .font(.title3.bold())
                    .foregroundStyle(colorForRisk)
            }

            ProgressView(value: min(loadScore.decayedLoad, 100), total: 100)
                .tint(colorForRisk)

            HStack {
                Text(loadScore.riskLevel.description)
                    .font(.caption.bold())
                    .foregroundStyle(colorForRisk)
                Spacer()
                Text(riskAdvice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(colorForRisk.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var colorForRisk: Color {
        loadScore.riskLevel.displayColor
    }

    private var riskAdvice: String {
        switch loadScore.riskLevel {
        case .safe: return "Good capacity"
        case .caution: return "Monitor energy"
        case .high: return "Consider pacing"
        case .critical: return "Prioritise rest"
        }
    }

    private var accessibilityDescription: String {
        "Activity load: \(Int(loadScore.decayedLoad)) percent. Risk level: \(loadScore.riskLevel.description). \(riskAdvice)"
    }
}
