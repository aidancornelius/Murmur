//
//  AddEntryView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CoreData
import CoreLocation
import Foundation
import SwiftUI

// Model to track selected symptoms and their individual severities
struct SelectedSymptom: Identifiable, Equatable {
    let id: UUID
    let symptomType: SymptomType
    var severity: Double

    init(symptomType: SymptomType, severity: Double = 3) {
        self.id = symptomType.id ?? UUID()
        self.symptomType = symptomType
        self.severity = severity
    }

    static func == (lhs: SelectedSymptom, rhs: SelectedSymptom) -> Bool {
        lhs.id == rhs.id && lhs.severity == rhs.severity
    }
}

struct AddEntryView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthKit: HealthKitAssistant

    @FetchRequest(
        entity: SymptomType.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \SymptomType.isStarred, ascending: false),
            NSSortDescriptor(keyPath: \SymptomType.starOrder, ascending: true),
            NSSortDescriptor(keyPath: \SymptomType.name, ascending: true)
        ]
    ) private var symptomTypes: FetchedResults<SymptomType>

    @State private var selectedSymptoms: [SelectedSymptom] = []
    @State private var useSameSeverity: Bool = true
    @State private var sharedSeverity: Double = 3
    @State private var note: String = ""
    @State private var timestamp = Date()
    @State private var includeLocation = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var saveTask: Task<Void, Never>?

    @StateObject private var locationAssistant = LocationAssistant()

    private var starredSymptoms: [SymptomType] {
        symptomTypes.filter { $0.isStarred }
    }

    private var unstarredSymptoms: [SymptomType] {
        symptomTypes.filter { !$0.isStarred }
    }

    var body: some View {
        Form {
            if symptomTypes.isEmpty {
                Section("What happened") {
                    Text("Add some symptoms in Settings to get started.")
                        .foregroundStyle(.secondary)
                }
                .themedFormSection()
            } else {
                Section {
                    SymptomMultiPicker(
                        symptomTypes: Array(symptomTypes),
                        selectedSymptoms: $selectedSymptoms,
                        useSameSeverity: $useSameSeverity,
                        sharedSeverity: $sharedSeverity
                    )
                } header: {
                    Text("Symptoms")
                } footer: {
                    if selectedSymptoms.isEmpty {
                        Text("Select up to 5 symptoms")
                    } else {
                        Text("\(selectedSymptoms.count)/5 selected")
                    }
                }
                .themedFormSection()
            }

            if !selectedSymptoms.isEmpty {
                Section("How intense") {
                    Toggle("Same severity for all", isOn: $useSameSeverity)
                        .accessibilityLabel("Same severity for all symptoms")
                        .accessibilityHint("When enabled, all selected symptoms will use the same severity rating. When disabled, you can rate each symptom individually.")
                        .accessibilityValue(useSameSeverity ? "On, using shared severity" : "Off, individual severity ratings")
                        .accessibilityIdentifier(AccessibilityIdentifiers.sameSeverityToggle)
                        .onChange(of: useSameSeverity) { _, _ in
                            HapticFeedback.selection.trigger()
                        }

                    if useSameSeverity {
                        VStack(alignment: .leading, spacing: 8) {
                            Slider(value: $sharedSeverity, in: 1...5, step: 1,
                                   onEditingChanged: { editing in
                                       if !editing {
                                           // Only trigger haptic when user finishes adjusting
                                           HapticFeedback.light.trigger()
                                       }
                                   }) {
                                Text("Severity")
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.severitySlider)
                            .accessibilityLabel("Severity for all symptoms")
                            .accessibilityValue(sharedSeverityAccessibilityValue)
                            .accessibilityHint("Adjust to change severity for all \(selectedSymptoms.count) selected symptoms")
                            .onChange(of: sharedSeverity) { _, newValue in
                                // Update all selected symptoms to use the shared severity
                                for i in selectedSymptoms.indices {
                                    selectedSymptoms[i].severity = newValue
                                }
                            }
                            HStack {
                                Text(sharedSeverityDescriptor)
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                    .accessibilityIdentifier(AccessibilityIdentifiers.severityLabel)
                                Spacer()
                                Text("\(Int(sharedSeverity))/5")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Severity level: \(sharedSeverityDescriptor), \(Int(sharedSeverity)) out of 5")
                        }
                    } else {
                        ForEach($selectedSymptoms) { $symptom in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(symptom.symptomType.name ?? "Unnamed")
                                    .font(.subheadline.bold())
                                    .accessibilityAddTraits(.isHeader)
                                Slider(value: $symptom.severity, in: 1...5, step: 1,
                                       onEditingChanged: { editing in
                                           if !editing {
                                               // Only trigger haptic when user finishes adjusting
                                               HapticFeedback.light.trigger()
                                           }
                                       }) {
                                    Text("Severity for \(symptom.symptomType.name ?? "symptom")")
                                }
                                .accessibilityLabel("Severity for \(symptom.symptomType.name ?? "symptom")")
                                .accessibilityValue(SeverityScale.accessibilityValue(for: symptom.severity, isPositive: symptom.symptomType.isPositive))
                                .accessibilityIdentifier(AccessibilityIdentifiers.individualSeveritySlider(symptom.symptomType.name ?? "symptom"))
                                HStack {
                                    Text(SeverityScale.descriptor(for: Int(symptom.severity), isPositive: symptom.symptomType.isPositive))
                                        .font(.caption.bold())
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(Int(symptom.severity))/5")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Severity level: \(SeverityScale.descriptor(for: Int(symptom.severity), isPositive: symptom.symptomType.isPositive)), \(Int(symptom.severity)) out of 5")
                            }
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .contain)
                        }
                    }
                }
                .themedFormSection()

                Section {
                    DatePicker("Time", selection: $timestamp)
                        .accessibilityIdentifier(AccessibilityIdentifiers.timestampPicker)
                }
                .themedFormSection()
            }

            Section("Additional details") {
                TextField("Notes (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityHint("Add any additional details about this symptom")
                    .accessibilityIdentifier(AccessibilityIdentifiers.noteTextField)

                Toggle("Save location", isOn: $includeLocation)
                    .accessibilityIdentifier(AccessibilityIdentifiers.locationToggle)
                    .onChange(of: includeLocation) { _, enabled in
                        HapticFeedback.selection.trigger()
                        if enabled { locationAssistant.requestLocation() }
                    }
                if includeLocation {
                    LocationStatusView(state: locationAssistant.state)
                }
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
        .themedForm()
        .navigationTitle("How are you feeling?")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
                    .accessibilityIdentifier(AccessibilityIdentifiers.cancelButton)
                    .accessibilityInputLabels(["Cancel", "Dismiss", "Close", "Go back"])
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveEntries(addAnother: false)
                }
                .disabled(isSaving || selectedSymptoms.isEmpty)
                .accessibilityIdentifier(AccessibilityIdentifiers.saveButton)
                .accessibilityInputLabels(["Save", "Submit", "Log entry", "Record", "Save entry"])
            }
        }
        .onDisappear {
            saveTask?.cancel()
        }
    }

    // When using shared severity, determine the descriptor based on all selected symptoms
    // If all are positive or all are negative, use that; otherwise use a neutral descriptor
    private var sharedSeverityDescriptor: String {
        guard !selectedSymptoms.isEmpty else {
            return SeverityScale.descriptor(for: Int(sharedSeverity))
        }

        let hasPositive = selectedSymptoms.contains { $0.symptomType.isPositive }
        let hasNegative = selectedSymptoms.contains { !$0.symptomType.isPositive }

        if hasPositive && !hasNegative {
            // All positive
            return SeverityScale.descriptor(for: Int(sharedSeverity), isPositive: true)
        } else if hasNegative && !hasPositive {
            // All negative
            return SeverityScale.descriptor(for: Int(sharedSeverity), isPositive: false)
        } else {
            // Mixed - use level number
            return "Level \(Int(sharedSeverity))"
        }
    }

    // Accessibility value for shared severity slider - adapts based on selected symptom types
    private var sharedSeverityAccessibilityValue: String {
        guard !selectedSymptoms.isEmpty else {
            return SeverityScale.accessibilityValue(for: sharedSeverity)
        }

        let hasPositive = selectedSymptoms.contains { $0.symptomType.isPositive }
        let hasNegative = selectedSymptoms.contains { !$0.symptomType.isPositive }

        if hasPositive && !hasNegative {
            // All positive
            return SeverityScale.accessibilityValue(for: sharedSeverity, isPositive: true)
        } else if hasNegative && !hasPositive {
            // All negative
            return SeverityScale.accessibilityValue(for: sharedSeverity, isPositive: false)
        } else {
            // Mixed - use neutral language
            return "Level \(Int(sharedSeverity)) out of 5"
        }
    }

    private func saveEntries(addAnother: Bool) {
        isSaving = true
        errorMessage = nil

        // Cancel any existing save task
        saveTask?.cancel()

        saveTask = Task { @MainActor in
            do {
                // Use the service to create and save entries
                _ = try await SymptomEntryService.createEntries(
                    selectedSymptoms: selectedSymptoms,
                    note: note,
                    timestamp: timestamp,
                    includeLocation: includeLocation,
                    healthKit: healthKit,
                    location: locationAssistant,
                    context: context
                )

                HapticFeedback.success.trigger()
                dismiss()
            } catch is CancellationError {
                // Task was cancelled - service already rolled back changes
                isSaving = false
            } catch {
                HapticFeedback.error.trigger()
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

private struct LocationStatusView: View {
    let state: LocationAssistant.State

    var body: some View {
        switch state {
        case .idle:
            Text("We'll save your location when you submit.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .requesting:
            HStack {
                ProgressView()
                Text("Finding your location...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .denied:
            Text("Location is turned off. Enable it in Settings.")
                .font(.caption)
                .foregroundStyle(.red)
        case .resolved(let placemark):
            Text(LocationAssistant.formatted(placemark: placemark))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SymptomMultiPicker: View {
    let symptomTypes: [SymptomType]
    @Binding var selectedSymptoms: [SelectedSymptom]
    @Binding var useSameSeverity: Bool
    @Binding var sharedSeverity: Double

    @State private var showAllSymptoms = false
    @State private var recentSymptoms: [SymptomType] = []
    @Environment(\.managedObjectContext) private var context

    private let maxSelection = AppConstants.UI.maxSymptomSelection

    private var starredSymptoms: [SymptomType] {
        symptomTypes.filter { $0.isStarred }.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private func loadRecentSymptoms() {
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)]
        fetchRequest.fetchLimit = 20

        guard let entries = try? context.fetch(fetchRequest) else { return }

        var seen = Set<UUID>()
        var recent: [SymptomType] = []

        for entry in entries {
            if let type = entry.symptomType, let id = type.id, !seen.contains(id) {
                seen.insert(id)
                recent.append(type)
                if recent.count >= 6 { break }
            }
        }

        recentSymptoms = recent
    }

    private func isSelected(_ symptom: SymptomType) -> Bool {
        selectedSymptoms.contains { $0.symptomType.id == symptom.id }
    }

    private func toggleSelection(_ symptom: SymptomType) {
        HapticFeedback.selection.trigger()
        if let index = selectedSymptoms.firstIndex(where: { $0.symptomType.id == symptom.id }) {
            selectedSymptoms.remove(at: index)
        } else if selectedSymptoms.count < maxSelection {
            let newSymptom = SelectedSymptom(symptomType: symptom, severity: useSameSeverity ? sharedSeverity : 3)
            selectedSymptoms.append(newSymptom)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Selected symptoms display
            if !selectedSymptoms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedSymptoms) { selected in
                                HStack(spacing: 6) {
                                    Image(systemName: selected.symptomType.iconName ?? "circle")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                    Text(selected.symptomType.name ?? "Unnamed")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                    Button(action: { toggleSelection(selected.symptomType) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                    .accessibilityLabel("Remove \(selected.symptomType.name ?? "symptom")")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selected.symptomType.uiColor)
                                .clipShape(Capsule())
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(selected.symptomType.name ?? "Unnamed") selected")
                                .accessibilityHint("Double tap to remove")
                            }
                        }
                    }
                    .accessibilityLabel("Selected symptoms")
                    .accessibilityHint("\(selectedSymptoms.count) of \(maxSelection) symptoms selected")
                }
            }

            // Starred symptoms
            if !starredSymptoms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Favourites")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        ForEach(starredSymptoms) { symptom in
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

            // Recent symptoms
            if !recentSymptoms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        ForEach(recentSymptoms) { symptom in
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

            // Browse all button
            Button(action: { showAllSymptoms = true }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Search all symptoms")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Search all symptoms")
            .accessibilityIdentifier(AccessibilityIdentifiers.searchAllSymptomsButton)
            .accessibilityHint("Opens a searchable list of all available symptoms")
            .accessibilityInputLabels(["Search all symptoms", "Browse symptoms", "Find symptom", "Search symptoms", "All symptoms"])
        }
        .padding(.vertical, 8)
        .onAppear {
            if recentSymptoms.isEmpty {
                loadRecentSymptoms()
            }
        }
        .sheet(isPresented: $showAllSymptoms) {
            NavigationStack {
                AllSymptomsSheet(
                    symptomTypes: symptomTypes,
                    selectedSymptoms: $selectedSymptoms,
                    isPresented: $showAllSymptoms,
                    maxSelection: maxSelection,
                    onSymptomCreated: loadRecentSymptoms
                )
            }
            .themedSurface()
        }
    }
}

// MARK: - Supporting Views
// Note: AllSymptomsSheet and SymptomMultiSelectButton have been extracted to:
// Murmur/Features/AddActivity/Subviews/AllSymptomsSheet.swift
