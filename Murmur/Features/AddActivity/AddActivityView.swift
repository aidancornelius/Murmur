//
//  AddActivityView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CoreData
import EventKit
import Foundation
import SwiftUI

struct AddActivityView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var calendarAssistant: CalendarAssistant

    @State private var name: String = ""
    @State private var note: String = ""
    @State private var timestamp = Date()
    @State private var physicalExertion: Double = 3
    @State private var cognitiveExertion: Double = 3
    @State private var emotionalLoad: Double = 3
    @State private var durationMinutes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedCalendarEvent: EKEvent?
    @State private var calendarEventID: String?
    @FocusState private var isNameFieldFocused: Bool
    @State private var parsedData: ParsedActivityInput?
    @State private var userEditedTimestamp = false
    @State private var userEditedDuration = false
    @State private var calendarEventsExpanded = true

    var allFilteredEvents: [EKEvent] {
        guard calendarAssistant.authorizationStatus == .fullAccess else {
            return []
        }

        let searchText = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if searchText.isEmpty {
            return calendarAssistant.recentEvents
        }

        return calendarAssistant.recentEvents.filter { event in
            (event.title?.lowercased().contains(searchText) ?? false) ||
            (event.location?.lowercased().contains(searchText) ?? false) ||
            (event.notes?.lowercased().contains(searchText) ?? false)
        }
    }

    var currentlyOccurringEvents: [EKEvent] {
        let now = Date()
        return allFilteredEvents.filter { event in
            guard let startDate = event.startDate, let endDate = event.endDate else { return false }
            return startDate <= now && endDate >= now
        }
    }

    var recentlyOccurredEvents: [EKEvent] {
        let now = Date()
        let fortyFiveMinutesAgo = now.addingTimeInterval(-45 * 60)
        return allFilteredEvents.filter { event in
            guard let endDate = event.endDate else { return false }
            return endDate >= fortyFiveMinutesAgo && endDate < now
        }
    }

    var earlierTodayEvents: [EKEvent] {
        let now = Date()
        let fortyFiveMinutesAgo = now.addingTimeInterval(-45 * 60)
        return allFilteredEvents.filter { event in
            guard let endDate = event.endDate else { return false }
            return endDate < fortyFiveMinutesAgo
        }
    }

    var upcomingTodayEvents: [EKEvent] {
        let now = Date()
        return allFilteredEvents.filter { event in
            guard let startDate = event.startDate else { return false }
            return startDate > now
        }
    }

    var hasAnyEvents: Bool {
        !allFilteredEvents.isEmpty
    }

    var shouldCollapseCalendar: Bool {
        !name.isEmpty || selectedCalendarEvent != nil
    }

    var body: some View {
        Form {
            Section {
                TextField("What happened? (Event name)", text: $name, axis: .vertical)
                    .focused($isNameFieldFocused)
                    .lineLimit(1...3)
                    .accessibilityHint("Enter the name of the activity or event")
                    .onChange(of: name) { oldValue, newValue in
                        parseNaturalLanguage(newValue)
                        // Auto-collapse when user starts typing
                        if !newValue.isEmpty && oldValue.isEmpty {
                            withAnimation {
                                calendarEventsExpanded = false
                            }
                        }
                    }

                if calendarAssistant.authorizationStatus == .notDetermined {
                    Button(action: {
                        Task {
                            let granted = await calendarAssistant.requestAccess()
                            if granted {
                                await calendarAssistant.fetchTodaysEvents()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(.secondary)
                            Text("Connect calendar")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                    .accessibilityHint("Requests permission to access your calendar")
                }

                // Collapsed calendar button
                if hasAnyEvents && !calendarEventsExpanded && shouldCollapseCalendar {
                    Button(action: {
                        withAnimation {
                            calendarEventsExpanded = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Or choose from today's events")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .themedFormSection()

            // Expanded calendar events
            if hasAnyEvents && calendarEventsExpanded {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Currently occurring events
                        if !currentlyOccurringEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Now")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                ForEach(currentlyOccurringEvents, id: \.eventIdentifier) { event in
                                    CalendarEventButton(event: event, onSelect: {
                                        populateFromCalendarEvent(event)
                                        withAnimation {
                                            calendarEventsExpanded = false
                                        }
                                    })
                                }
                            }
                        }

                        // Recently occurred events
                        if !recentlyOccurredEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                ForEach(recentlyOccurredEvents, id: \.eventIdentifier) { event in
                                    CalendarEventButton(event: event, onSelect: {
                                        populateFromCalendarEvent(event)
                                        withAnimation {
                                            calendarEventsExpanded = false
                                        }
                                    })
                                }
                            }
                        }

                        // Earlier today events (for searching old events like gym at 8am when it's 4pm)
                        if !earlierTodayEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Earlier today")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                ForEach(earlierTodayEvents, id: \.eventIdentifier) { event in
                                    CalendarEventButton(event: event, onSelect: {
                                        populateFromCalendarEvent(event)
                                        withAnimation {
                                            calendarEventsExpanded = false
                                        }
                                    })
                                }
                            }
                        }

                        // Upcoming events
                        if !upcomingTodayEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Later today")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                ForEach(upcomingTodayEvents, id: \.eventIdentifier) { event in
                                    CalendarEventButton(event: event, onSelect: {
                                        populateFromCalendarEvent(event)
                                        withAnimation {
                                            calendarEventsExpanded = false
                                        }
                                    })
                                }
                            }
                        }
                    }
                }
                .themedFormSection()
            }

            Section {
                VStack(alignment: .leading, spacing: 16) {
                    ExertionSlider(
                        title: "Physical exertion",
                        value: $physicalExertion,
                        icon: "figure.walk"
                    )
                    ExertionSlider(
                        title: "Cognitive exertion",
                        value: $cognitiveExertion,
                        icon: "brain.head.profile"
                    )
                    ExertionSlider(
                        title: "Emotional load",
                        value: $emotionalLoad,
                        icon: "heart"
                    )
                }
            }
            .themedFormSection()

            Section {
                DatePicker("Time", selection: $timestamp)
                    .onChange(of: timestamp) { _, _ in
                        userEditedTimestamp = true
                    }

                HStack {
                    Text("Duration (minutes)")
                    Spacer()
                    TextField("Optional", text: $durationMinutes)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .onChange(of: durationMinutes) { _, _ in
                            userEditedDuration = true
                        }
                }
            }
            .themedFormSection()

            Section {
                TextField("Notes (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityHint("Add any additional details about this activity")
            }
            .themedFormSection()

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .themedFormSection()
            }
        }
        .navigationTitle("Log an activity")
        .themedForm()
        .onAppear {
            isNameFieldFocused = true
            Task {
                if calendarAssistant.authorizationStatus == .fullAccess {
                    await calendarAssistant.fetchTodaysEvents()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveActivity()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func parseNaturalLanguage(_ input: String) {
        let parsed = NaturalLanguageParser.parse(input)
        parsedData = parsed

        // Only update fields if the user hasn't manually edited them
        if let parsedTimestamp = parsed.timestamp, !userEditedTimestamp {
            timestamp = parsedTimestamp
        }

        if let parsedDuration = parsed.durationMinutes, !userEditedDuration {
            durationMinutes = "\(parsedDuration)"
        }
    }

    private func populateFromCalendarEvent(_ event: EKEvent) {
        name = event.title ?? ""
        timestamp = event.startDate ?? Date()
        calendarEventID = event.eventIdentifier

        if let startDate = event.startDate, let endDate = event.endDate {
            let duration = Int32(endDate.timeIntervalSince(startDate) / 60)
            durationMinutes = "\(duration)"
        }

        if let notes = event.notes, !notes.isEmpty {
            note = notes
        }
    }

    private func saveActivity() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Activity name is required"
            return
        }

        isSaving = true
        errorMessage = nil

        let activity = ActivityEvent(context: context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = timestamp

        // Use cleaned text if available from natural language parsing, otherwise use raw name
        let activityName: String
        if let parsedText = parsedData?.cleanedText, !parsedText.isEmpty {
            activityName = parsedText
        } else {
            activityName = name.trimmingCharacters(in: .whitespaces)
        }
        activity.name = activityName

        activity.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        activity.physicalExertion = Int16(physicalExertion)
        activity.cognitiveExertion = Int16(cognitiveExertion)
        activity.emotionalLoad = Int16(emotionalLoad)

        if let duration = Int32(durationMinutes) {
            activity.durationMinutes = NSNumber(value: duration)
        }

        activity.calendarEventID = calendarEventID

        do {
            try context.save()
            HapticFeedback.success.trigger()
            dismiss()
        } catch {
            HapticFeedback.error.trigger()
            errorMessage = error.localizedDescription
            context.rollback()
            isSaving = false
        }
    }
}

private struct CalendarEventButton: View {
    let event: EKEvent
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title ?? "Untitled event")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

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
                            Text("\(duration)m")
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
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

private struct ExertionSlider: View {
    let title: String
    @Binding var value: Double
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
            }

            Slider(value: $value, in: 1...5, step: 1) {
                Text(title)
            }
            .accessibilityValue(accessibilityValue)
            .onChange(of: value) { _, _ in
                HapticFeedback.light.trigger()
            }

            HStack {
                Text(descriptor)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(Int(value))/5")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var descriptor: String {
        switch Int(value) {
        case 1: return "Very light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Heavy"
        default: return "Very heavy"
        }
    }

    private var accessibilityValue: String {
        "Level \(Int(value)): \(descriptor)"
    }
}
