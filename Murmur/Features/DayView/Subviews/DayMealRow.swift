// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DayMealRow.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Row component displaying a meal event in day view.
//
import SwiftUI

/// A row displaying a meal event with time and description
struct DayMealRow: View {
    let meal: MealEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(meal.mealType?.capitalized ?? "Meal", systemImage: "fork.knife")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.orange)
                Spacer()
            }
            HStack(spacing: 12) {
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let description = meal.mealDescription, !description.isEmpty {
                Text(description)
                    .font(.callout)
            }
            if let note = meal.note, !note.isEmpty {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Swipe left to delete this meal")
    }

    private var timeLabel: String {
        let reference = meal.backdatedAt ?? meal.createdAt ?? Date()
        return DateFormatters.shortTime.string(from: reference)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append("\(meal.mealType?.capitalized ?? "Meal") at \(timeLabel)")
        if let description = meal.mealDescription, !description.isEmpty {
            parts.append("Description: \(description)")
        }
        if let note = meal.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }
        return parts.joined(separator: ". ")
    }
}
