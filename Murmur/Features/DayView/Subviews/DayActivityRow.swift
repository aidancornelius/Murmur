// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DayActivityRow.swift
// Created by Aidan Cornelius-Bell on 10/10/2025.
// Row component displaying an activity event in day view.
//
import SwiftUI

/// A row displaying an activity event with exertion levels
struct DayActivityRow: View {
    let activity: ActivityEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(activity.name ?? "Unnamed activity", systemImage: "calendar")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.purple)
                Spacer()
            }
            HStack(spacing: 12) {
                Text(timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let duration = activity.durationMinutes?.intValue {
                    Text("\(duration) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Physical")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        Image(systemName: "figure.walk")
                        Text("\(activity.physicalExertion)")
                    }
                    .font(.caption)
                    .foregroundStyle(.purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cognitive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        Image(systemName: "brain.head.profile")
                        Text("\(activity.cognitiveExertion)")
                    }
                    .font(.caption)
                    .foregroundStyle(.purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Emotional")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        Image(systemName: "heart")
                        Text("\(activity.emotionalLoad)")
                    }
                    .font(.caption)
                    .foregroundStyle(.purple)
                }
            }
            if let note = activity.note, !note.isEmpty {
                Text(note)
                    .font(.callout)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Swipe left to delete this activity")
    }

    private var timeLabel: String {
        let reference = activity.backdatedAt ?? activity.createdAt ?? Date()
        return DateFormatters.shortTime.string(from: reference)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append("Activity: \(activity.name ?? "Unnamed") at \(timeLabel)")

        if let duration = activity.durationMinutes?.intValue {
            parts.append("Duration: \(duration) minutes")
        }

        parts.append("Physical exertion: level \(activity.physicalExertion)")
        parts.append("Cognitive exertion: level \(activity.cognitiveExertion)")
        parts.append("Emotional load: level \(activity.emotionalLoad)")

        if let note = activity.note, !note.isEmpty {
            parts.append("Note: \(note)")
        }

        return parts.joined(separator: ". ")
    }
}
