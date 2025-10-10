//
//  CalendarEventRow.swift
//  Murmur
//
//  Extracted from UnifiedEventView.swift on 10/10/2025.
//

import EventKit
import SwiftUI

/// A row displaying a calendar event with status indicators
struct CalendarEventRow: View {
    let event: EKEvent
    let onSelect: () -> Void
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    private var eventStatus: EventStatus {
        let now = Date()
        guard let startDate = event.startDate, let endDate = event.endDate else { return .other }

        if startDate <= now && endDate >= now {
            return .happening
        } else if endDate >= now.addingTimeInterval(-30 * 60) && endDate < now {
            return .justEnded
        } else if startDate > now && startDate <= now.addingTimeInterval(15 * 60) {
            return .upcoming
        }
        return .other
    }

    private func colorForStatus(_ status: EventStatus) -> Color {
        switch status {
        case .happening: return palette.color(for: "severity2") // Safe/green equivalent
        case .justEnded: return palette.color(for: "severity3") // Caution/orange equivalent
        case .upcoming: return palette.accentColor
        case .other: return palette.accentColor.opacity(0.5)
        }
    }

    private enum EventStatus {
        case happening
        case justEnded
        case upcoming
        case other

        var icon: String {
            switch self {
            case .happening: return "circle.fill"
            case .justEnded: return "checkmark.circle.fill"
            case .upcoming: return "clock.fill"
            case .other: return "calendar"
            }
        }

        var label: String {
            switch self {
            case .happening: return "Now"
            case .justEnded: return "Just ended"
            case .upcoming: return "Soon"
            case .other: return ""
            }
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(colorForStatus(eventStatus).opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: eventStatus.icon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(colorForStatus(eventStatus))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(event.title ?? "Untitled event")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        if !eventStatus.label.isEmpty {
                            Text(eventStatus.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(colorForStatus(eventStatus))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(colorForStatus(eventStatus).opacity(0.15))
                                )
                        }
                    }

                    HStack(spacing: 4) {
                        if let startDate = event.startDate {
                            Text(startDate, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let endDate = event.endDate, let startDate = event.startDate {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            let duration = Int(endDate.timeIntervalSince(startDate) / 60)
                            Text("\(duration) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
