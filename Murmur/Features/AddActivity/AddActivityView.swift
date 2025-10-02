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
    @State private var showingCalendarPicker = false
    @State private var selectedCalendarEvent: EKEvent?
    @State private var calendarEventID: String?

    var body: some View {
        Form {
            Section("What happened") {
                TextField("Activity name", text: $name)
                    .accessibilityHint("Enter the name of the activity or event")

                if calendarAssistant.authorizationStatus == .fullAccess {
                    Button(action: { showingCalendarPicker = true }) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Import from calendar")
                            Spacer()
                            if selectedCalendarEvent != nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .accessibilityHint("Select a calendar event to pre-fill activity details")
                } else if calendarAssistant.authorizationStatus == .notDetermined {
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
                            Text("Connect calendar")
                        }
                    }
                    .accessibilityHint("Requests permission to access your calendar")
                }
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

            Section {
                DatePicker("Time", selection: $timestamp)

                HStack {
                    Text("Duration (minutes)")
                    Spacer()
                    TextField("Optional", text: $durationMinutes)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            Section("Additional details") {
                TextField("Notes (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityHint("Add any additional details about this activity")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Log an activity")
        .onAppear {
            Task {
                if calendarAssistant.authorizationStatus == .fullAccess {
                    await calendarAssistant.fetchTodaysEvents()
                }
            }
        }
        .sheet(isPresented: $showingCalendarPicker) {
            CalendarEventPicker(
                events: calendarAssistant.recentEvents,
                selectedEvent: $selectedCalendarEvent,
                onSelect: { event in
                    populateFromCalendarEvent(event)
                    showingCalendarPicker = false
                }
            )
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
        activity.name = name.trimmingCharacters(in: .whitespaces)
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
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            context.rollback()
            isSaving = false
        }
    }
}

private struct CalendarEventPicker: View {
    let events: [EKEvent]
    @Binding var selectedEvent: EKEvent?
    let onSelect: (EKEvent) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if events.isEmpty {
                    Section {
                        Text("No events found for today")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(events, id: \.eventIdentifier) { event in
                        Button(action: {
                            selectedEvent = event
                            onSelect(event)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title ?? "Untitled event")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                HStack {
                                    if let startDate = event.startDate {
                                        Text(startDate, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let endDate = event.endDate, let startDate = event.startDate {
                                        Text("–")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(endDate, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        let duration = Int(endDate.timeIntervalSince(startDate) / 60)
                                        Text("(\(duration) min)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                if let location = event.location, !location.isEmpty {
                                    Label(location, systemImage: "mappin.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(eventAccessibilityLabel(for: event))
                        .accessibilityHint("Selects this calendar event to pre-fill the activity form")
                    }
                }
            }
            .navigationTitle("Choose event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func eventAccessibilityLabel(for event: EKEvent) -> String {
        var parts: [String] = []
        parts.append(event.title ?? "Untitled event")

        if let startDate = event.startDate {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            parts.append("at \(formatter.string(from: startDate))")

            if let endDate = event.endDate {
                let duration = Int(endDate.timeIntervalSince(startDate) / 60)
                parts.append("for \(duration) minutes")
            }
        }

        if let location = event.location, !location.isEmpty {
            parts.append("Location: \(location)")
        }

        return parts.joined(separator: ", ")
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
