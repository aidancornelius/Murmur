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
    @FocusState private var isNotesFocused: Bool
    @State private var hasUserEdited = false
    @State private var suggestedCalendarEvent: EKEvent?
    @State private var isFromCalendarEvent = false

    // Detected/Selected event type
    @State private var eventType: DetectedEventType = .activity
    @State private var hasManuallySelectedEventType = false

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
    @State private var timestamp = DateUtility.now()
    @State private var durationMinutes: String = ""
    @State private var selectedTimeChip: TimeChip? = nil
    @State private var selectedDurationChip: DurationChip? = nil

    // Sleep fields - default to yesterday 10pm to today 7am
    @State private var bedTime: Date = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: DateUtility.now())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        return calendar.date(bySettingHour: 22, minute: 0, second: 0, of: yesterday)!
    }()
    @State private var wakeTime: Date = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: DateUtility.now())
        return calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today)!
    }()
    @State private var sleepQuality: Int = 3
    @State private var selectedSleepSymptoms: [SelectedSymptom] = []
    @State private var showingSymptomPicker = false

    // Meal fields
    @State private var mealType: String = "breakfast"
    @State private var showMealExertion: Bool = false
    @State private var mealPhysicalExertion: Int = 3
    @State private var mealCognitiveExertion: Int = 3
    @State private var mealEmotionalLoad: Int = 3

    // Shared fields
    @State private var note: String = ""
    @State private var calendarEventID: String?

    // UI State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var errorMessages: [String] = []
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
            let now = DateUtility.now()

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

    enum DurationChip: String, CaseIterable {
        case fifteen = "15 min"
        case thirty = "30 min"
        case fortyfive = "45 min"
        case sixty = "1 hour"
        case ninety = "1.5 hours"
        case twoHours = "2 hours"

        var minutes: Int {
            switch self {
            case .fifteen: return 15
            case .thirty: return 30
            case .fortyfive: return 45
            case .sixty: return 60
            case .ninety: return 90
            case .twoHours: return 120
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

        // Placeholder based on selected event type
        switch eventType {
        case .activity:
            return "What did you do?"
        case .sleep:
            return "How did you sleep?"
        case .meal:
            return "What did you eat?"
        case .unknown:
            return "What happened?"
        }
    }

    private func isCurrentlyOccurring(_ event: EKEvent) -> Bool {
        let now = DateUtility.now()
        guard let startDate = event.startDate, let endDate = event.endDate else { return false }
        return startDate <= now && endDate >= now
    }

    private func hasJustEnded(_ event: EKEvent) -> Bool {
        let now = DateUtility.now()
        guard let endDate = event.endDate else { return false }
        let thirtyMinutesAgo = now.addingTimeInterval(-30 * 60)
        return endDate >= thirtyMinutesAgo && endDate < now
    }

    private func isAboutToStart(_ event: EKEvent) -> Bool {
        let now = DateUtility.now()
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
        ScrollViewReader { proxy in
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

                    // Notes (always available at the bottom)
                    notesCard

                    // Error message
                    if let errorMessage {
                        errorCard(message: errorMessage)
                            .id("errorCard")
                    }
                }
                .padding()
            }
            .onChange(of: errorMessage) { _, newValue in
                // Auto-scroll to error when it appears
                if newValue != nil {
                    withAnimation {
                        proxy.scrollTo("errorCard", anchor: .center)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .themedSurface()
        .onAppear {
            Task {
                if calendarAssistant.authorizationStatus == .fullAccess {
                    await calendarAssistant.fetchTodaysEvents()

                    // Suggest the most relevant calendar event
                    if let relevantEvent = getMostRelevantCalendarEvent() {
                        suggestedCalendarEvent = relevantEvent
                        // Show the calendar card so user can tap to fill
                        showCalendarCard = true
                    }
                }
            }

            // Focus the input field
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                isInputFocused = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier(AccessibilityIdentifiers.cancelButton)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveEvent()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSaving || mainInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .foregroundStyle(isSaving || mainInput.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : palette.accentColor)
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

            // Clear error when user makes changes
            if errorMessage != nil {
                errorMessage = nil
            }
        }
        .onChange(of: physicalExertion) { _, _ in errorMessage = nil }
        .onChange(of: cognitiveExertion) { _, _ in errorMessage = nil }
        .onChange(of: emotionalLoad) { _, _ in errorMessage = nil }
        .onChange(of: sleepQuality) { _, _ in errorMessage = nil }
        .onChange(of: bedTime) { _, _ in errorMessage = nil }
        .onChange(of: wakeTime) { _, _ in errorMessage = nil }
        .onChange(of: mealType) { _, _ in errorMessage = nil }
        .onChange(of: mealPhysicalExertion) { _, _ in errorMessage = nil }
        .onChange(of: mealCognitiveExertion) { _, _ in errorMessage = nil }
        .onChange(of: mealEmotionalLoad) { _, _ in errorMessage = nil }
        .onChange(of: durationMinutes) { _, _ in errorMessage = nil }
        .onChange(of: timestamp) { _, _ in errorMessage = nil }
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
                // Main input row with event type selector inside
                HStack(spacing: 8) {
                    // Event type selector - always visible on the left
                    eventTypeDropdown

                    // Text input field
                    TextField(smartPlaceholder, text: $mainInput, axis: .vertical)
                        .font(.title3)
                        .focused($isInputFocused)
                        .lineLimit(1)  // Single line only
                        .submitLabel(.done)
                        .onSubmit {
                            // Dismiss keyboard on return/done
                            isInputFocused = false
                        }
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

            // Additional controls
            HStack(spacing: 8) {
                // Calendar suggestions toggle - only show if there are matching events
                if calendarAssistant.authorizationStatus == .fullAccess {
                    let hasMatchingEvents = !calendarAssistant.recentEvents.filter { event in
                        mainInput.trimmingCharacters(in: .whitespaces).isEmpty ||
                        (event.title?.localizedCaseInsensitiveContains(mainInput) ?? false)
                    }.isEmpty

                    if hasMatchingEvents {
                        Button(action: { withAnimation { showCalendarCard.toggle() } }) {
                            HStack(spacing: 4) {
                                Image(systemName: showCalendarCard ? "calendar" : "calendar.badge.plus")
                                    .font(.subheadline)
                                Text(showCalendarCard ? "Hide calendar" : "From calendar")
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(palette.surfaceColor.opacity(0.8))
                            )
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var eventTypeDropdown: some View {
        Menu {
            Button(action: {
                withAnimation {
                    eventType = .activity
                    hasManuallySelectedEventType = true
                    showExertionCard = true
                    showTimeCard = true
                    showSleepQualityCard = false
                    showMealTypeCard = false
                }
                HapticFeedback.selection.trigger()
            }) {
                Label("Activity", systemImage: "figure.walk")
            }

            Button(action: {
                withAnimation {
                    eventType = .sleep
                    hasManuallySelectedEventType = true
                    showExertionCard = false
                    showTimeCard = false
                    showSleepQualityCard = true
                    showMealTypeCard = false
                    // Prepopulate with "Sleep" if the field is empty
                    if mainInput.trimmingCharacters(in: .whitespaces).isEmpty {
                        mainInput = "Sleep"
                    }
                }
                HapticFeedback.selection.trigger()
            }) {
                Label("Sleep", systemImage: "moon.stars.fill")
            }

            Button(action: {
                withAnimation {
                    eventType = .meal
                    hasManuallySelectedEventType = true
                    showExertionCard = false
                    showTimeCard = false
                    showSleepQualityCard = false
                    showMealTypeCard = true
                }
                HapticFeedback.selection.trigger()
            }) {
                Label("Meal", systemImage: "fork.knife")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: iconForEventType(eventType))
                    .font(.body)
                    .foregroundStyle(palette.accentColor)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
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
    private func durationChipButton(_ chip: DurationChip) -> some View {
        Button(action: {
            selectedDurationChip = chip
            durationMinutes = "\(chip.minutes)"
            HapticFeedback.selection.trigger()
        }) {
            Text(chip.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selectedDurationChip == chip ? palette.accentColor : palette.surfaceColor.opacity(0.8))
                )
                .foregroundStyle(selectedDurationChip == chip ? .white : .primary)
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
            VStack(spacing: 16) {
                Picker("Meal type", selection: $mealType) {
                    Text("Breakfast").tag("breakfast")
                    Text("Lunch").tag("lunch")
                    Text("Dinner").tag("dinner")
                    Text("Snack").tag("snack")
                }
                .pickerStyle(.segmented)

                // Optional exertion toggle
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showMealExertion.toggle()
                        HapticFeedback.selection.trigger()
                    }
                }) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(showMealExertion ? "Energy impact" : "Add energy impact")
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(showMealExertion ? 0 : -90))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)

                // Exertion controls (shown when toggled)
                if showMealExertion {
                    VStack(spacing: 16) {
                        ExertionRingSelector(
                            label: "Physical",
                            value: $mealPhysicalExertion,
                            color: .orange
                        )
                        ExertionRingSelector(
                            label: "Mental",
                            value: $mealCognitiveExertion,
                            color: .purple
                        )
                        ExertionRingSelector(
                            label: "Emotional",
                            value: $mealEmotionalLoad,
                            color: .pink
                        )
                    }
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                }
            }
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
                // Quick time chips
                VStack(alignment: .leading, spacing: 6) {
                    Text("When")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TimeChip.allCases, id: \.self) { chip in
                                timeChipButton(chip)
                            }
                        }
                    }
                }

                DatePicker("Time", selection: $timestamp)

                // Duration chips
                VStack(alignment: .leading, spacing: 6) {
                    Text("How long")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DurationChip.allCases, id: \.self) { chip in
                                durationChipButton(chip)
                            }
                        }
                    }
                }

                HStack {
                    Text("Duration")
                    Spacer()
                    TextField("Optional", text: $durationMinutes)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .onChange(of: durationMinutes) { oldValue, newValue in
                            // Only clear selected chip if the value doesn't match any chip
                            // (meaning user manually typed something different)
                            if let selected = selectedDurationChip {
                                if newValue != "\(selected.minutes)" {
                                    selectedDurationChip = nil
                                }
                            }
                        }
                    Text("minutes")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showNotesCard.toggle()
                    HapticFeedback.light.trigger()

                    // Auto-focus the notes field when expanding
                    if showNotesCard {
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            await MainActor.run {
                                isNotesFocused = true
                            }
                        }
                    }
                }
            }) {
                HStack {
                    Image(systemName: "note.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(showNotesCard ? "Notes" : "Add notes")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showNotesCard ? 0 : -90))
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
            .buttonStyle(.plain)

            if showNotesCard {
                TextField("Add any details...", text: $note, axis: .vertical)
                    .focused($isNotesFocused)
                    .lineLimit(3...6)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.surfaceColor.opacity(0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(palette.accentColor.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
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
                let now = DateUtility.now()

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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.body)

                VStack(alignment: .leading, spacing: 4) {
                    // Split message by newlines to support multiple errors
                    let messages = message.components(separatedBy: "\n").filter { !$0.isEmpty }

                    if messages.count == 1 {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    } else {
                        Text("Please fix the following issues:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)

                        ForEach(messages, id: \.self) { msg in
                            HStack(alignment: .top, spacing: 4) {
                                Text("•")
                                    .foregroundStyle(.red)
                                Text(msg)
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helper Functions

    private func parseInput(_ input: String, isFromCalendar: Bool = false) {
        parsedData = NaturalLanguageParser.parse(input, isFromCalendar: isFromCalendar)

        // Only update event type if user hasn't manually selected one
        if !hasManuallySelectedEventType && parsedData?.detectedType != .unknown {
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
                // Smart suggestion based on time - prioritise sleep between 5-8am
                let hour = Calendar.current.component(.hour, from: DateUtility.now())
                let shouldSuggestSleep = (hour >= 5 && hour < 8) || hour > 21

                if shouldSuggestSleep && !hasSleepInLast12Hours() {
                    eventType = .sleep
                    showSleepQualityCard = true
                    // Auto-title as "Sleep" when suggesting sleep mode
                    if mainInput.trimmingCharacters(in: .whitespaces).isEmpty {
                        mainInput = "Sleep"
                    }
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
        timestamp = event.startDate ?? DateUtility.now()
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
                }

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

    private func saveActivity() throws {
        let activity = ActivityEvent(context: context)
        activity.id = UUID()
        activity.createdAt = DateUtility.now()
        activity.backdatedAt = timestamp

        // Ensure we have a non-empty name
        let trimmedInput = mainInput.trimmingCharacters(in: .whitespaces)
        let activityName: String
        if let parsedText = parsedData?.cleanedText, !parsedText.isEmpty {
            activityName = parsedText
        } else if !trimmedInput.isEmpty {
            activityName = trimmedInput
        } else {
            activityName = "Activity"  // Fallback - should never happen due to save button being disabled
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
    }

    private func saveSleep() async throws {
        let sleep = SleepEvent(context: context)
        sleep.id = UUID()
        sleep.createdAt = DateUtility.now()
        sleep.backdatedAt = bedTime
        sleep.bedTime = bedTime
        sleep.wakeTime = wakeTime
        sleep.quality = Int16(sleepQuality)

        // Combine mainInput and note field
        let trimmedInput = mainInput.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedInput.isEmpty && !trimmedNote.isEmpty {
            sleep.note = "\(trimmedInput)\n\n\(trimmedNote)"
        } else if !trimmedInput.isEmpty {
            sleep.note = trimmedInput
        } else if !trimmedNote.isEmpty {
            sleep.note = trimmedNote
        } else {
            sleep.note = nil
        }

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
        meal.createdAt = DateUtility.now()
        meal.backdatedAt = timestamp
        meal.mealType = mealType

        // Ensure we have a non-empty description
        let trimmedInput = mainInput.trimmingCharacters(in: .whitespaces)
        if !trimmedInput.isEmpty {
            meal.mealDescription = trimmedInput
        } else {
            meal.mealDescription = mealType.capitalized  // Fallback to meal type name
        }

        meal.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note

        // Save exertion values if user has opted in
        if showMealExertion {
            meal.physicalExertion = NSNumber(value: mealPhysicalExertion)
            meal.cognitiveExertion = NSNumber(value: mealCognitiveExertion)
            meal.emotionalLoad = NSNumber(value: mealEmotionalLoad)
        }
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

    private func hasSleepInLast12Hours() -> Bool {
        let request = SleepEvent.fetchRequest()
        let twelveHoursAgo = DateUtility.now().addingTimeInterval(-12 * 3600)
        request.predicate = NSPredicate(
            format: "createdAt >= %@",
            twelveHoursAgo as NSDate
        )
        request.fetchLimit = 1

        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }
}

// MARK: - Supporting Views
// Note: Supporting views have been extracted to separate files in the Subviews folder:
// - DisclosureCard.swift
// - ExertionRingSelector.swift
// - CalendarEventRow.swift
// - AllSymptomsSheet.swift
