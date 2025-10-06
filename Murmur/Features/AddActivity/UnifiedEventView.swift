//
//  UnifiedEventView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 05/10/2025.
//

import CoreData
import EventKit
import Foundation
import SwiftUI

struct UnifiedEventView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var calendarAssistant: CalendarAssistant
    @EnvironmentObject private var healthKit: HealthKitAssistant
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \SymptomType.isStarred, ascending: false),
            NSSortDescriptor(keyPath: \SymptomType.name, ascending: true)
        ],
        animation: .default
    )
    private var allSymptomTypes: FetchedResults<SymptomType>

    // Main input and parsing
    @State private var mainInput: String = ""
    @State private var parsedData: ParsedActivityInput?
    @FocusState private var isInputFocused: Bool
    @State private var hasUserEdited = false
    @State private var suggestedCalendarEvent: EKEvent?
    @State private var isFromCalendarEvent = false

    // Detected/Selected event type
    @State private var eventType: DetectedEventType = .unknown
    @State private var showEventTypePicker = false

    // Progressive disclosure states
    @State private var showExertionCard = false
    @State private var showTimeCard = false
    @State private var showCalendarCard = false
    @State private var showNotesCard = false
    @State private var showSleepQualityCard = false
    @State private var showMealTypeCard = false

    // Activity fields
    @State private var physicalExertion: Int = 3
    @State private var cognitiveExertion: Int = 3
    @State private var emotionalLoad: Int = 3

    // Time fields
    @State private var timestamp = Date()
    @State private var durationMinutes: String = ""
    @State private var selectedTimeChip: TimeChip? = nil

    // Sleep fields - default to yesterday 10pm to today 7am
    @State private var bedTime: Date = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        return calendar.date(bySettingHour: 22, minute: 0, second: 0, of: yesterday)!
    }()
    @State private var wakeTime: Date = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today)!
    }()
    @State private var sleepQuality: Int = 3
    @State private var selectedSleepSymptoms: [SelectedSymptom] = []
    @State private var showingSymptomPicker = false

    // Meal fields
    @State private var mealType: String = "breakfast"

    // Shared fields
    @State private var note: String = ""
    @State private var calendarEventID: String?

    // UI State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showHints = true
    @State private var hasInteracted = false

    // Check if user has seen the hints before
    @AppStorage(UserDefaultsKeys.hasSeenUnifiedEventHints) private var hasSeenHints = false

    // Time chips for quick selection
    enum TimeChip: String, CaseIterable {
        case now = "Just now"
        case thirtyMin = "30 min ago"
        case oneHour = "1 hour ago"
        case twoHours = "2 hours ago"
        case morning = "This morning"
        case yesterday = "Yesterday"

        var date: Date {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .now:
                return now
            case .thirtyMin:
                return now.addingTimeInterval(-30 * 60)
            case .oneHour:
                return now.addingTimeInterval(-60 * 60)
            case .twoHours:
                return now.addingTimeInterval(-2 * 60 * 60)
            case .morning:
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = 8
                components.minute = 0
                return calendar.date(from: components) ?? now
            case .yesterday:
                return calendar.date(byAdding: .day, value: -1, to: now) ?? now
            }
        }
    }

    var smartPlaceholder: String {
        // If we have a suggested calendar event, hint at it
        if let event = suggestedCalendarEvent, !hasUserEdited {
            if isCurrentlyOccurring(event) {
                return "Currently: \(event.title ?? "Event")"
            } else if hasJustEnded(event) {
                return "Just finished: \(event.title ?? "Event")?"
            }
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        switch hour {
        case 5..<9:
            return "How did you sleep?"
        case 11..<14:
            return "What did you have for lunch?"
        case 17..<20:
            return "What's for dinner?"
        case 20..<24:
            return "How was your day?"
        default:
            return "What happened?"
        }
    }

    private func isCurrentlyOccurring(_ event: EKEvent) -> Bool {
        let now = Date()
        guard let startDate = event.startDate, let endDate = event.endDate else { return false }
        return startDate <= now && endDate >= now
    }

    private func hasJustEnded(_ event: EKEvent) -> Bool {
        let now = Date()
        guard let endDate = event.endDate else { return false }
        let thirtyMinutesAgo = now.addingTimeInterval(-30 * 60)
        return endDate >= thirtyMinutesAgo && endDate < now
    }

    private func isAboutToStart(_ event: EKEvent) -> Bool {
        let now = Date()
        guard let startDate = event.startDate else { return false }
        let fifteenMinutesFromNow = now.addingTimeInterval(15 * 60)
        return startDate > now && startDate <= fifteenMinutesFromNow
    }

    private func getMostRelevantCalendarEvent() -> EKEvent? {
        let events = calendarAssistant.recentEvents

        // Priority 1: Currently occurring event
        if let currentEvent = events.first(where: isCurrentlyOccurring) {
            return currentEvent
        }

        // Priority 2: Event that just ended (within 30 minutes)
        let recentlyEnded = events
            .filter(hasJustEnded)
            .sorted { ($0.endDate ?? Date.distantPast) > ($1.endDate ?? Date.distantPast) }

        if let recentEvent = recentlyEnded.first {
            return recentEvent
        }

        // Priority 3: Event about to start (within 15 minutes)
        if let upcomingEvent = events.first(where: isAboutToStart) {
            return upcomingEvent
        }

        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Help hints for first-time users
                if showHints && !hasSeenHints && !hasInteracted {
                    helpHintsSection
                }

                // Main smart input field
                mainInputSection

                // Subtle contextual hints
                if !hasInteracted && mainInput.isEmpty {
                    contextualHintsSection
                }

                // Quick time chips
                if !mainInput.isEmpty {
                    timeChipsSection
                }

                // Calendar suggestions
                if showCalendarCard {
                    calendarSuggestionsCard
                }

                // Progressive disclosure cards based on event type
                if eventType == .activity && showExertionCard {
                    activityExertionCard
                }

                if eventType == .sleep && showSleepQualityCard {
                    sleepCard
                }

                if eventType == .meal && showMealTypeCard {
                    mealCard
                }

                // Time and duration (for activities)
                if showTimeCard {
                    timeDurationCard
                }

                // Notes (always available but collapsed by default)
                if showNotesCard {
                    notesCard
                }

                // Error message
                if let errorMessage {
                    errorCard(message: errorMessage)
                }
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .themedSurface()
        .onAppear {
            Task {
                if calendarAssistant.authorizationStatus == .fullAccess {
                    await calendarAssistant.fetchTodaysEvents()

                    // Auto-suggest the most relevant calendar event
                    if let relevantEvent = getMostRelevantCalendarEvent() {
                        suggestedCalendarEvent = relevantEvent

                        // Auto-fill the input if user hasn't started typing
                        if !hasUserEdited && mainInput.isEmpty {
                            withAnimation(.easeOut(duration: 0.3)) {
                                mainInput = relevantEvent.title ?? ""
                                isFromCalendarEvent = true
                                populateFromCalendarEvent(relevantEvent)
                                // Show a subtle hint that we auto-filled
                                showCalendarCard = false  // Hide the calendar card since we already used it
                            }
                        }
                    }
                }
            }

            // Focus after a slight delay to allow auto-fill animation
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                isInputFocused = true
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
                .disabled(isSaving || mainInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onChange(of: mainInput) { oldValue, newValue in
            // Track interaction
            if !hasInteracted && !newValue.isEmpty {
                withAnimation(.easeOut(duration: 0.3)) {
                    hasInteracted = true
                    if !hasSeenHints {
                        hasSeenHints = true
                    }
                }
            }

            // Track if user has manually edited the text
            if oldValue != newValue && oldValue != "" {
                hasUserEdited = true
                // If user edits, it's no longer purely from calendar
                if hasUserEdited {
                    isFromCalendarEvent = false
                }
            }
            parseInput(newValue, isFromCalendar: isFromCalendarEvent)
        }
        .confirmationDialog("Event type", isPresented: $showEventTypePicker) {
            Button("Activity") {
                eventType = .activity
                withAnimation {
                    showExertionCard = true
                    showTimeCard = true
                    showSleepQualityCard = false
                    showMealTypeCard = false
                }
            }
            Button("Sleep") {
                eventType = .sleep
                withAnimation {
                    showExertionCard = false
                    showTimeCard = false
                    showSleepQualityCard = true
                    showMealTypeCard = false
                }
            }
            Button("Meal") {
                eventType = .meal
                withAnimation {
                    showExertionCard = false
                    showTimeCard = false
                    showSleepQualityCard = false
                    showMealTypeCard = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose the type of event")
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

    // MARK: - View Components

    @ViewBuilder
    private var helpHintsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)

                Text("Quick tip")
                    .font(.caption.weight(.semibold))

                Spacer()

                Button(action: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showHints = false
                        hasSeenHints = true
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Just start typing or tap a calendar event", systemImage: "text.cursor")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("I'll understand things like \"ran 5km\" or \"slept 8 hours\"", systemImage: "wand.and.stars")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("Tap the time chips below for quick time selection", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.yellow.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .transition(.asymmetric(
            insertion: .push(from: .top).combined(with: .opacity),
            removal: .push(from: .top).combined(with: .opacity)
        ))
    }

    @ViewBuilder
    private var contextualHintsSection: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "keyboard")
                    .font(.caption2)
                Text("Type naturally")
                    .font(.caption2)
            }

            Text("•")
                .font(.caption2)

            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text("Tap events")
                    .font(.caption2)
            }

            Text("•")
                .font(.caption2)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("Use time chips")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    @ViewBuilder
    private var mainInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                TextField(smartPlaceholder, text: $mainInput, axis: .vertical)
                    .font(.title3)
                    .focused($isInputFocused)
                    .lineLimit(1)  // Single line only
                    .submitLabel(.done)
                    .onSubmit {
                        // Dismiss keyboard on return/done
                        isInputFocused = false
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.color(for: "surface").opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(palette.accentColor.opacity(0.2), lineWidth: 1)
                    )

                // Calendar indicator when auto-populated
                if suggestedCalendarEvent != nil && !hasUserEdited && !mainInput.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.circle.fill")
                            .font(.system(size: 12))
                        Text("from calendar")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
                    .onTapGesture {
                        withAnimation {
                            // Clear the suggestion
                            mainInput = ""
                            suggestedCalendarEvent = nil
                            hasUserEdited = true
                            isFromCalendarEvent = false
                        }
                    }
                }
            }

            // Event type indicator/picker and controls - always show for manual fallback
            HStack {
                eventTypeChip(eventType)

                Spacer()

                HStack(spacing: 12) {
                    // Calendar suggestions toggle - only show if there are matching events
                    if calendarAssistant.authorizationStatus == .fullAccess {
                        let hasMatchingEvents = !calendarAssistant.recentEvents.filter { event in
                            mainInput.trimmingCharacters(in: .whitespaces).isEmpty ||
                            (event.title?.localizedCaseInsensitiveContains(mainInput) ?? false)
                        }.isEmpty

                        if hasMatchingEvents {
                            Button(action: { withAnimation { showCalendarCard.toggle() } }) {
                                Image(systemName: showCalendarCard ? "calendar" : "calendar.badge.plus")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Notes toggle
                    if !mainInput.isEmpty {
                        Button(action: { withAnimation { showNotesCard.toggle() } }) {
                            Image(systemName: showNotesCard ? "note.text" : "note.text.badge.plus")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func eventTypeChip(_ type: DetectedEventType) -> some View {
        HStack(spacing: 4) {
            Image(systemName: iconForEventType(type))
                .font(.caption)
            Text(labelForEventType(type))
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(0.15))
        )
        .foregroundStyle(Color.accentColor)
        .onTapGesture {
            showEventTypePickerMenu()
        }
    }

    @ViewBuilder
    private var timeChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimeChip.allCases, id: \.self) { chip in
                    timeChipButton(chip)
                }
            }
        }
    }

    @ViewBuilder
    private func timeChipButton(_ chip: TimeChip) -> some View {
        Button(action: {
            selectedTimeChip = chip

            // Update appropriate fields based on event type
            switch eventType {
            case .sleep:
                bedTime = chip.date
            default:
                timestamp = chip.date
            }

            HapticFeedback.selection.trigger()

            // Mark as interacted
            if !hasInteracted {
                withAnimation {
                    hasInteracted = true
                    hasSeenHints = true
                }
            }
        }) {
            Text(chip.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selectedTimeChip == chip ? palette.accentColor : palette.surfaceColor.opacity(0.8))
                )
                .foregroundStyle(selectedTimeChip == chip ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var activityExertionCard: some View {
        DisclosureCard(
            title: "Energy levels",
            icon: "bolt.fill",
            isExpanded: .constant(true)
        ) {
            VStack(spacing: 16) {
                ExertionRingSelector(
                    label: "Physical",
                    value: $physicalExertion,
                    color: .orange
                )
                ExertionRingSelector(
                    label: "Mental",
                    value: $cognitiveExertion,
                    color: .purple
                )
                ExertionRingSelector(
                    label: "Emotional",
                    value: $emotionalLoad,
                    color: .pink
                )
            }
        }
    }

    @ViewBuilder
    private var sleepCard: some View {
        DisclosureCard(
            title: "Sleep details",
            icon: "moon.stars.fill",
            isExpanded: .constant(true)
        ) {
            VStack(spacing: 12) {
                // HealthKit autofill button if available
                if healthKit.latestSleepHours != nil {
                    Button(action: {
                        Task {
                            await loadHealthKitSleepData()
                        }
                    }) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                            Text("Load logged sleep from Health")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.15))
                        )
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }

                DatePicker("Bed time", selection: $bedTime, displayedComponents: [.date, .hourAndMinute])
                DatePicker("Wake time", selection: $wakeTime, displayedComponents: [.date, .hourAndMinute])

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sleep quality")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        HStack(spacing: 4) {
                            Text("Poor")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("Excellent")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    ExertionRingSelector(
                        label: "",  // Empty label since we show it above
                        value: $sleepQuality,
                        color: .indigo,
                        showScale: false  // Don't show the built-in scale
                    )
                }
            }

            // Symptoms
            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    showingSymptomPicker = true
                }) {
                    HStack {
                        Text("Symptoms during sleep")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedSleepSymptoms.isEmpty {
                            Text("None")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(selectedSleepSymptoms.count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                if !selectedSleepSymptoms.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(selectedSleepSymptoms) { selected in
                            HStack {
                                Image(systemName: selected.symptomType.safeIconName)
                                    .foregroundStyle(selected.symptomType.uiColor)
                                Text(selected.symptomType.safeName)
                                    .font(.subheadline)
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
        }
    }

    @ViewBuilder
    private var mealCard: some View {
        DisclosureCard(
            title: "Meal details",
            icon: "fork.knife",
            isExpanded: .constant(true)
        ) {
            Picker("Meal type", selection: $mealType) {
                Text("Breakfast").tag("breakfast")
                Text("Lunch").tag("lunch")
                Text("Dinner").tag("dinner")
                Text("Snack").tag("snack")
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var timeDurationCard: some View {
        DisclosureCard(
            title: "Time & duration",
            icon: "clock.fill",
            isExpanded: .constant(true)
        ) {
            VStack(spacing: 12) {
                DatePicker("Time", selection: $timestamp)

                HStack {
                    Text("Duration")
                    Spacer()
                    TextField("Optional", text: $durationMinutes)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Text("minutes")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var notesCard: some View {
        DisclosureCard(
            title: "Notes",
            icon: "note.text",
            isExpanded: $showNotesCard
        ) {
            TextField("Add any details...", text: $note, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    @ViewBuilder
    private var calendarSuggestionsCard: some View {
        // Filter events based on whether they match the input text
        let filteredEvents = calendarAssistant.recentEvents.filter { event in
            // If no input, show all events
            if mainInput.trimmingCharacters(in: .whitespaces).isEmpty {
                return true
            }
            // Check if event title contains the input text (case insensitive)
            return event.title?.localizedCaseInsensitiveContains(mainInput) ?? false
        }

        if !filteredEvents.isEmpty {
            let sortedEvents = filteredEvents.sorted { event1, event2 in
                // Prioritise by status: happening > just ended > upcoming > other
                let now = Date()

                func priority(_ event: EKEvent) -> Int {
                    guard let startDate = event.startDate, let endDate = event.endDate else { return 0 }

                    if startDate <= now && endDate >= now {
                        return 4  // Currently happening
                    } else if endDate >= now.addingTimeInterval(-30 * 60) && endDate < now {
                        return 3  // Just ended
                    } else if startDate > now && startDate <= now.addingTimeInterval(15 * 60) {
                        return 2  // Upcoming soon
                    }
                    return 1  // Other
                }

                let p1 = priority(event1)
                let p2 = priority(event2)

                if p1 != p2 {
                    return p1 > p2
                }

                // If same priority, sort by time (most recent first)
                return (event1.startDate ?? Date.distantPast) > (event2.startDate ?? Date.distantPast)
            }

            DisclosureCard(
                title: "From your calendar",
                icon: "calendar",
                isExpanded: $showCalendarCard
            ) {
                VStack(spacing: 8) {
                    ForEach(sortedEvents.prefix(5), id: \.eventIdentifier) { event in
                        CalendarEventRow(event: event) {
                            withAnimation {
                                populateFromCalendarEvent(event)
                                hasUserEdited = false  // Allow re-suggestion
                                suggestedCalendarEvent = event
                                isFromCalendarEvent = true
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func errorCard(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.1))
        )
    }

    // MARK: - Helper Functions

    private func parseInput(_ input: String, isFromCalendar: Bool = false) {
        parsedData = NaturalLanguageParser.parse(input, isFromCalendar: isFromCalendar)

        // Update event type
        if parsedData?.detectedType != .unknown {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                eventType = parsedData?.detectedType ?? .unknown
            }
        }

        // Show relevant cards based on detected type
        withAnimation {
            // Check if there are matching calendar events
            let hasMatchingCalendarEvents = !input.isEmpty &&
                calendarAssistant.authorizationStatus == .fullAccess &&
                !calendarAssistant.recentEvents.filter { event in
                    event.title?.localizedCaseInsensitiveContains(input) ?? false
                }.isEmpty

            switch eventType {
            case .activity:
                showExertionCard = true
                showTimeCard = true
                showCalendarCard = hasMatchingCalendarEvents
            case .sleep:
                showSleepQualityCard = true
                showTimeCard = false
                // Auto-load HealthKit sleep data when sleep is detected
                Task {
                    await loadHealthKitSleepData()
                }
            case .meal:
                showMealTypeCard = true
                showTimeCard = true  // Enable time selection for meals
            case .unknown:
                // Smart suggestion based on time
                let hour = Calendar.current.component(.hour, from: Date())
                if hour < 9 || hour > 21 {
                    eventType = .sleep
                    showSleepQualityCard = true
                } else {
                    showCalendarCard = hasMatchingCalendarEvents
                }
            }
        }

        // Apply parsed values
        if let parsed = parsedData {
            if let parsedTimestamp = parsed.timestamp {
                timestamp = parsedTimestamp
            }
            if let parsedDuration = parsed.durationMinutes {
                durationMinutes = "\(parsedDuration)"
            }
            if let parsedPhysical = parsed.physicalExertion {
                physicalExertion = parsedPhysical
            }
            if let parsedCognitive = parsed.cognitiveExertion {
                cognitiveExertion = parsedCognitive
            }
            if let parsedEmotional = parsed.emotionalLoad {
                emotionalLoad = parsedEmotional
            }
            if let parsedBedTime = parsed.bedTime {
                bedTime = parsedBedTime
            }
            if let parsedWakeTime = parsed.wakeTime {
                wakeTime = parsedWakeTime
            }
            if let parsedSleepQuality = parsed.sleepQuality {
                sleepQuality = parsedSleepQuality
            }
            if let parsedMealType = parsed.mealType {
                mealType = parsedMealType
            }
        }
    }

    private func populateFromCalendarEvent(_ event: EKEvent) {
        mainInput = event.title ?? ""
        timestamp = event.startDate ?? Date()
        calendarEventID = event.eventIdentifier
        isFromCalendarEvent = true

        // Mark as interacted
        if !hasInteracted {
            withAnimation {
                hasInteracted = true
                hasSeenHints = true
            }
        }

        if let startDate = event.startDate, let endDate = event.endDate {
            let duration = Int(endDate.timeIntervalSince(startDate) / 60)
            durationMinutes = "\(duration)"
        }

        if let notes = event.notes, !notes.isEmpty {
            note = notes
            showNotesCard = true
        }

        // Parse the input with calendar context
        parseInput(mainInput, isFromCalendar: true)

        withAnimation {
            showCalendarCard = false
        }
    }

    private func showEventTypePickerMenu() {
        showEventTypePicker = true
        HapticFeedback.light.trigger()
    }

    private func iconForEventType(_ type: DetectedEventType) -> String {
        switch type {
        case .activity: return "figure.walk"
        case .sleep: return "moon.stars.fill"
        case .meal: return "fork.knife"
        case .unknown: return "questionmark.circle"
        }
    }

    private func labelForEventType(_ type: DetectedEventType) -> String {
        switch type {
        case .activity: return "Activity"
        case .sleep: return "Sleep"
        case .meal: return "Meal"
        case .unknown: return "Event"
        }
    }

    private func saveEvent() {
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            do {
                switch eventType {
                case .activity:
                    try saveActivity()
                case .sleep:
                    try await saveSleep()
                case .meal:
                    try saveMeal()
                case .unknown:
                    // Default to activity
                    try saveActivity()
                }

                // Ensure all changes are registered
                context.processPendingChanges()

                // Save to persistent store
                if context.hasChanges {
                    try context.save()
                    print("✅ UnifiedEventView: Successfully saved \(eventType) event to persistent store")
                } else {
                    print("⚠️ UnifiedEventView: No changes to save")
                }

                HapticFeedback.success.trigger()
                dismiss()
            } catch {
                print("❌ UnifiedEventView: Failed to save - \(error.localizedDescription)")
                HapticFeedback.error.trigger()
                errorMessage = error.localizedDescription
                context.rollback()
                isSaving = false
            }
        }
    }

    private func saveActivity() throws {
        let activity = ActivityEvent(context: context)
        activity.id = UUID()
        activity.createdAt = Date()
        activity.backdatedAt = timestamp

        let activityName = parsedData?.cleanedText.isEmpty == false
            ? parsedData!.cleanedText
            : mainInput.trimmingCharacters(in: .whitespaces)
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

    private func saveSleep() async throws {
        let sleep = SleepEvent(context: context)
        sleep.id = UUID()
        sleep.createdAt = Date()
        sleep.backdatedAt = bedTime
        sleep.bedTime = bedTime
        sleep.wakeTime = wakeTime
        sleep.quality = Int16(sleepQuality)
        sleep.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note

        // Add HealthKit data if available - await these before saving
        if let hkSleepHours = await healthKit.recentSleepHours() {
            sleep.hkSleepHours = NSNumber(value: hkSleepHours)
        }
        if let hkHRV = await healthKit.recentHRV() {
            sleep.hkHRV = NSNumber(value: hkHRV)
        }
        if let hkRestingHR = await healthKit.recentRestingHR() {
            sleep.hkRestingHR = NSNumber(value: hkRestingHR)
        }

        // Add symptoms
        for selected in selectedSleepSymptoms {
            sleep.addToSymptoms(selected.symptomType)
        }
    }

    private func saveMeal() throws {
        let meal = MealEvent(context: context)
        meal.id = UUID()
        meal.createdAt = Date()
        meal.backdatedAt = timestamp
        meal.mealType = mealType
        meal.mealDescription = mainInput.trimmingCharacters(in: .whitespaces)
        meal.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
    }

    private func loadHealthKitSleepData() async {
        let sleepData = await healthKit.fetchDetailedSleepData()

        // Update UI on main thread
        await MainActor.run {
            if let bedTimeValue = sleepData?.bedTime {
                bedTime = bedTimeValue
            }
            if let wakeTimeValue = sleepData?.wakeTime {
                wakeTime = wakeTimeValue
            }

            // Show a subtle animation to indicate the data was loaded
            withAnimation(.easeInOut(duration: 0.3)) {
                HapticFeedback.success.trigger()
            }
        }
    }
}

// MARK: - Supporting Views

struct DisclosureCard<Content: View>: View {
    let title: String
    let icon: String
    var isExpanded: Binding<Bool>
    @ViewBuilder let content: () -> Content
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    init(title: String, icon: String, isExpanded: Binding<Bool> = .constant(true), @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.isExpanded = isExpanded
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.wrappedValue.toggle()
                    HapticFeedback.light.trigger()
                }
            }

            if isExpanded.wrappedValue {
                content()
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surfaceColor.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.accentColor.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ExertionRingSelector: View {
    let label: String
    @Binding var value: Int
    let color: Color
    var showScale: Bool = true

    private let levels = [1, 2, 3, 4, 5]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !label.isEmpty {
                HStack {
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if showScale {
                        HStack(spacing: 4) {
                            Text("Low")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("High")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                ForEach(levels, id: \.self) { level in
                    RingButton(
                        level: level,
                        isSelected: value == level,
                        color: color
                    ) {
                        value = level
                        HapticFeedback.light.trigger()
                    }
                }
            }
        }
    }

    struct RingButton: View {
        let level: Int
        let isSelected: Bool
        let color: Color
        let action: () -> Void

        var label: String {
            switch level {
            case 1: return "Very low"
            case 2: return "Low"
            case 3: return "Moderate"
            case 4: return "High"
            case 5: return "Very high"
            default: return ""
            }
        }

        var body: some View {
            Button(action: action) {
                ZStack {
                    Circle()
                        .stroke(
                            color.opacity(isSelected ? 1 : 0.3),
                            lineWidth: isSelected ? 4 : 2
                        )

                    if isSelected {
                        Circle()
                            .fill(color.opacity(0.15))
                    }

                    Text("\(level)")
                        .font(.caption.bold())
                        .foregroundStyle(isSelected ? color : .secondary)
                }
                .frame(width: 44, height: 44)
                .scaleEffect(isSelected ? 1.1 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label), level \(level)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

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
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }
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
                    .foregroundStyle(isSelected ? .white : (isDisabled ? palette.accentColor.opacity(0.3) : .primary))
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
                    .fill(isSelected ? symptom.uiColor : palette.surfaceColor)
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
