//
//  AddEventView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CoreData
import EventKit
import Foundation
import SwiftUI

enum EventType: String, CaseIterable {
    case sleep = "Sleep"
    case activity = "Activity"
    case meal = "Meal"
}

struct AddEventView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var calendar: CalendarAssistant
    @EnvironmentObject private var healthKit: HealthKitAssistant

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \SymptomType.isStarred, ascending: false),
            NSSortDescriptor(keyPath: \SymptomType.name, ascending: true)
        ],
        animation: .default
    )
    private var allSymptomTypes: FetchedResults<SymptomType>

    @State private var selectedTab: EventType = .activity

    // Activity fields
    @State private var name: String = ""
    @State private var note: String = ""
    @State private var timestamp = Date()
    @State private var physicalExertion: Double = 3
    @State private var cognitiveExertion: Double = 3
    @State private var emotionalLoad: Double = 3
    @State private var durationMinutes: String = ""
    @State private var selectedCalendarEvent: EKEvent?
    @State private var calendarEventID: String?
    @State private var parsedData: ParsedActivityInput?
    @State private var userEditedTimestamp = false
    @State private var userEditedDuration = false
    @State private var calendarEventsExpanded = true

    // Sleep fields
    @State private var bedTime: Date = {
        let calendar = Calendar.current
        let now = Date()
        // Default to last night at 10pm
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 22
        components.minute = 0
        if let date = calendar.date(from: components), date > now {
            // If 10pm today is in future, use yesterday
            return calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return calendar.date(from: components) ?? now
    }()
    @State private var wakeTime: Date = {
        let calendar = Calendar.current
        let now = Date()
        // Default to this morning at current time or 7am if before that
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        let currentHour = calendar.component(.hour, from: now)
        if currentHour < 7 {
            components.hour = 7
            components.minute = 0
        } else {
            components.hour = currentHour
            components.minute = calendar.component(.minute, from: now)
        }
        return calendar.date(from: components) ?? now
    }()
    @State private var sleepQuality: Double = 3
    @State private var sleepNote: String = ""
    @State private var selectedSleepSymptoms: [SelectedSymptom] = []
    @State private var showingSymptomPicker = false

    // Meal fields
    @State private var mealDescription: String = ""
    @State private var mealType: String = "breakfast"
    @State private var mealTime = Date()
    @State private var mealNote: String = ""

    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isMealDescriptionFocused: Bool

    var sleepDuration: String {
        guard let bed = bedTime as Date?, let wake = wakeTime as Date? else {
            return ""
        }
        let duration = wake.timeIntervalSince(bed)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    var body: some View {
        Form {
            Section {
                EventTypeSelector(selectedTab: $selectedTab)
                    .listRowInsets(EdgeInsets(top: -8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            switch selectedTab {
            case .activity:
                activityFormContent
            case .sleep:
                sleepFormContent
            case .meal:
                mealFormContent
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .themedFormSection()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .themedForm()
        .onAppear {
            if selectedTab == .activity {
                isNameFieldFocused = true
            } else if selectedTab == .meal {
                isMealDescriptionFocused = true
            }
            Task {
                if calendar.authorizationStatus == .fullAccess {
                    await calendar.fetchTodaysEvents()
                }
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .activity {
                isNameFieldFocused = true
            } else if newValue == .meal {
                isMealDescriptionFocused = true
                // Auto-select meal type based on current time
                mealType = getMealTypeFromTime(mealTime)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveEvent()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSaving || !isFormValid)
            }
        }
        .sheet(isPresented: $showingSymptomPicker) {
            NavigationStack {
                AllSymptomsSheet(
                    symptomTypes: Array(allSymptomTypes),
                    selectedSymptoms: $selectedSleepSymptoms,
                    isPresented: $showingSymptomPicker,
                    maxSelection: 5
                )
                .environment(\.managedObjectContext, context)
                .environmentObject(AppearanceManager.shared)
            }
            .themedSurface()
        }
    }

    var isFormValid: Bool {
        switch selectedTab {
        case .activity:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .sleep:
            return true // All sleep fields have defaults
        case .meal:
            return !mealDescription.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Activity Form Content
    @ViewBuilder
    var activityFormContent: some View {
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

            if calendar.authorizationStatus == .notDetermined {
                Button(action: {
                    Task {
                        let granted = await calendar.requestAccess()
                        if granted {
                            await calendar.fetchTodaysEvents()
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
    }

    // MARK: - Sleep Form Content
    @ViewBuilder
    var sleepFormContent: some View {
        Section {
            DatePicker("Bed time", selection: $bedTime, displayedComponents: [.date, .hourAndMinute])

            DatePicker("Wake time", selection: $wakeTime, displayedComponents: [.date, .hourAndMinute])

            HStack {
                Text("Duration")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(sleepDuration)
                    .foregroundStyle(.primary)
            }
        }
        .themedFormSection()

        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "moon.stars")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("Sleep quality")
                        .font(.subheadline)
                }

                Slider(value: $sleepQuality, in: 1...5, step: 1) {
                    Text("Sleep quality")
                }
                .accessibilityValue(sleepQualityAccessibilityValue)
                .onChange(of: sleepQuality) { _, _ in
                    HapticFeedback.light.trigger()
                }

                HStack {
                    Text(sleepQualityDescriptor)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(Int(sleepQuality))/5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .themedFormSection()

        Section {
            Button(action: {
                showingSymptomPicker = true
            }) {
                HStack {
                    Text("Symptoms during sleep")
                    Spacer()
                    if selectedSleepSymptoms.isEmpty {
                        Text("None")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(selectedSleepSymptoms.count)")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if !selectedSleepSymptoms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(selectedSleepSymptoms) { selected in
                        HStack {
                            Image(systemName: selected.symptomType.safeIconName)
                                .foregroundStyle(selected.symptomType.uiColor)
                            Text(selected.symptomType.safeName)
                            Spacer()
                            Button(action: {
                                if let index = selectedSleepSymptoms.firstIndex(where: { $0.id == selected.id }) {
                                    selectedSleepSymptoms.remove(at: index)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .themedFormSection()

        Section {
            TextField("Notes (optional)", text: $sleepNote, axis: .vertical)
                .lineLimit(1...4)
                .accessibilityHint("Add any additional details about your sleep")
        }
        .themedFormSection()
    }

    // MARK: - Meal Form Content
    @ViewBuilder
    var mealFormContent: some View {
        Section {
            TextField("What did you eat?", text: $mealDescription, axis: .vertical)
                .focused($isMealDescriptionFocused)
                .lineLimit(1...3)
                .accessibilityHint("Describe what you ate")

            Picker("Meal type", selection: $mealType) {
                Text("Breakfast").tag("breakfast")
                Text("Lunch").tag("lunch")
                Text("Dinner").tag("dinner")
                Text("Snack").tag("snack")
            }

            DatePicker("Time", selection: $mealTime)
                .onChange(of: mealTime) { _, newValue in
                    // Auto-update meal type when time changes
                    let suggestedType = getMealTypeFromTime(newValue)
                    if mealType != suggestedType {
                        mealType = suggestedType
                    }
                }
        }
        .themedFormSection()

        Section {
            TextField("Notes (optional)", text: $mealNote, axis: .vertical)
                .lineLimit(1...4)
                .accessibilityHint("Add any additional details about this meal")
        }
        .themedFormSection()
    }

    // MARK: - Helper Properties
    var allFilteredEvents: [EKEvent] {
        guard calendar.authorizationStatus == .fullAccess else {
            return []
        }

        let searchText = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if searchText.isEmpty {
            return calendar.recentEvents
        }

        return calendar.recentEvents.filter { event in
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

    var sleepQualityDescriptor: String {
        switch Int(sleepQuality) {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very good"
        default: return "Excellent"
        }
    }

    var sleepQualityAccessibilityValue: String {
        "Level \(Int(sleepQuality)): \(sleepQualityDescriptor)"
    }

    // MARK: - Helper Functions
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

    private func getMealTypeFromTime(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return "breakfast"
        case 11..<16: return "lunch"
        case 16..<22: return "dinner"
        default: return "snack"
        }
    }

    private func saveEvent() {
        errorMessage = nil
        isSaving = true

        do {
            switch selectedTab {
            case .activity:
                try saveActivity()
            case .sleep:
                try saveSleep()
            case .meal:
                try saveMeal()
            }

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

    private func saveActivity() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NSError(domain: "AddEventView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Activity name is required"])
        }

        let activity = ActivityEvent(context: context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = timestamp

        // Use cleaned text if available from natural language parsing, otherwise use raw name
        let activityName = parsedData?.cleanedText.isEmpty == false
            ? parsedData!.cleanedText
            : name.trimmingCharacters(in: .whitespaces)
        activity.name = activityName

        activity.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        activity.physicalExertion = Int16(physicalExertion)
        activity.cognitiveExertion = Int16(cognitiveExertion)
        activity.emotionalLoad = Int16(emotionalLoad)

        if let duration = Int32(durationMinutes) {
            activity.durationMinutes = NSNumber(value: duration)
        }

        activity.calendarEventID = calendarEventID
    }

    private func saveSleep() throws {
        let sleep = SleepEvent(context: context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.backdatedAt = bedTime
        sleep.bedTime = bedTime
        sleep.wakeTime = wakeTime
        sleep.quality = Int16(sleepQuality)
        sleep.note = sleepNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sleepNote

        // Add HealthKit data if available
        Task {
            if let hkSleepHours = await healthKit.recentSleepHours() {
                sleep.hkSleepHours = NSNumber(value: hkSleepHours)
            }
            if let hkHRV = await healthKit.recentHRV() {
                sleep.hkHRV = NSNumber(value: hkHRV)
            }
            if let hkRestingHR = await healthKit.recentRestingHR() {
                sleep.hkRestingHR = NSNumber(value: hkRestingHR)
            }
        }

        // Add symptoms
        for selected in selectedSleepSymptoms {
            sleep.addToSymptoms(selected.symptomType)
        }
    }

    private func saveMeal() throws {
        guard !mealDescription.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NSError(domain: "AddEventView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Meal description is required"])
        }

        let meal = MealEvent(context: context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = mealTime
        meal.mealType = mealType
        meal.mealDescription = mealDescription.trimmingCharacters(in: .whitespaces)
        meal.note = mealNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : mealNote
    }
}

// MARK: - Supporting Views
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

// MARK: - Event Type Selector
private struct EventTypeSelector: View {
    @Binding var selectedTab: EventType
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EventType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = type
                        HapticFeedback.light.trigger()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: type.iconName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(selectedTab == type ? .primary : .secondary)

                        Text(type.rawValue)
                            .font(.caption2.weight(selectedTab == type ? .semibold : .regular))
                            .foregroundStyle(selectedTab == type ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selectedTab == type {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.15))
                                .matchedGeometryEffect(id: "tab", in: animation)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension EventType {
    var iconName: String {
        switch self {
        case .sleep: return "moon.stars.fill"
        case .activity: return "figure.walk"
        case .meal: return "fork.knife"
        }
    }
}

// MARK: - Symptom Picker (shared with AddEntryView)
private struct AllSymptomsSheet: View {
    let symptomTypes: [SymptomType]
    @Binding var selectedSymptoms: [SelectedSymptom]
    @Binding var isPresented: Bool
    let maxSelection: Int

    @State private var searchText: String = ""
    @State private var showCreateSheet = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    private var filteredSymptomTypes: [SymptomType] {
        if searchText.isEmpty {
            return symptomTypes
        } else {
            return symptomTypes.filter { symptom in
                (symptom.name ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var categorisedSymptoms: [(category: String, symptoms: [SymptomType])] {
        let grouped = Dictionary(grouping: filteredSymptomTypes) { symptom in
            symptom.category ?? "User added"
        }

        // Show user added symptoms first, then the rest
        let categoryOrder = ["User added", "Positive wellbeing", "Energy", "Pain", "Cognitive", "Sleep", "Neurological", "Digestive", "Mental health", "Reproductive & hormonal", "Respiratory & cardiovascular", "Other"]

        return categoryOrder.compactMap { category in
            guard let symptoms = grouped[category], !symptoms.isEmpty else { return nil }
            return (category, symptoms.sorted { ($0.name ?? "") < ($1.name ?? "") })
        }
    }

    private func isSelected(_ symptom: SymptomType) -> Bool {
        selectedSymptoms.contains { $0.symptomType.id == symptom.id }
    }

    private func toggleSelection(_ symptom: SymptomType) {
        HapticFeedback.selection.trigger()
        if let index = selectedSymptoms.firstIndex(where: { $0.symptomType.id == symptom.id }) {
            selectedSymptoms.remove(at: index)
        } else if selectedSymptoms.count < maxSelection {
            selectedSymptoms.append(SelectedSymptom(symptomType: symptom))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search symptoms", text: $searchText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .accessibilityLabel("Search symptoms")
                    .accessibilityHint("Type to filter symptoms by name")
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(8)
            .background(palette.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if categorisedSymptoms.isEmpty {
                        VStack(spacing: 16) {
                            Text("No symptoms found matching '\(searchText)'")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)

                            if !searchText.isEmpty {
                                Button(action: {
                                    showCreateSheet = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Create '\(searchText)'")
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                }
                                .accessibilityLabel("Create new symptom named \(searchText)")
                            }
                        }
                        .padding()
                    } else {
                        ForEach(categorisedSymptoms, id: \.category) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.category)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                                    ForEach(group.symptoms) { symptom in
                                        SymptomMultiSelectButton(
                                            symptom: symptom,
                                            isSelected: isSelected(symptom),
                                            isDisabled: !isSelected(symptom) && selectedSymptoms.count >= maxSelection,
                                            action: { toggleSelection(symptom) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("All symptoms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { isPresented = false }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                SymptomTypeFormView(editingType: nil, prefillName: searchText) { newSymptom in
                    // Auto-select the newly created symptom
                    if selectedSymptoms.count < maxSelection {
                        let newSelected = SelectedSymptom(symptomType: newSymptom)
                        selectedSymptoms.append(newSelected)
                        HapticFeedback.success.trigger()
                    }
                    searchText = ""
                }
                .environment(\.managedObjectContext, context)
            }
            .themedSurface()
        }
    }
}

private struct SymptomMultiSelectButton: View {
    let symptom: SymptomType
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: symptom.iconName ?? "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : (isDisabled ? symptom.uiColor.opacity(0.4) : symptom.uiColor))
                        .frame(height: 24)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .background(
                                Circle()
                                    .fill(symptom.uiColor)
                                    .frame(width: 16, height: 16)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
                .frame(maxWidth: .infinity)

                Text(symptom.name ?? "Unnamed")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .white : (isDisabled ? Color(.systemGray) : Color(.label)))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .frame(height: 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? symptom.uiColor : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDisabled ? symptom.uiColor.opacity(0.3) : symptom.uiColor, lineWidth: isSelected ? 3 : 2)
            )
            .shadow(color: isSelected ? symptom.uiColor.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 60, minHeight: 88)
        .disabled(isDisabled)
        .accessibilityLabel(symptom.name ?? "Unnamed")
        .accessibilityHint(isSelected ? "Selected. Double tap to deselect" : "Not selected. Double tap to select")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
