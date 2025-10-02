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
        lhs.id == rhs.id
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
    @State private var showAddAnother = false

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
            }

            if !selectedSymptoms.isEmpty {
                Section("How intense") {
                    Toggle("Same severity for all", isOn: $useSameSeverity)
                        .accessibilityLabel("Same severity for all symptoms")
                        .accessibilityHint("When enabled, all selected symptoms will use the same severity rating. When disabled, you can rate each symptom individually.")
                        .accessibilityValue(useSameSeverity ? "On, using shared severity" : "Off, individual severity ratings")

                    if useSameSeverity {
                        VStack(alignment: .leading, spacing: 8) {
                            Slider(value: $sharedSeverity, in: 1...5, step: 1) {
                                Text("Severity")
                            }
                            .accessibilityLabel("Severity for all symptoms")
                            .accessibilityValue(severityAccessibilityValue(for: sharedSeverity))
                            .accessibilityHint("Adjust to change severity for all \(selectedSymptoms.count) selected symptoms")
                            .onChange(of: sharedSeverity) { _, newValue in
                                HapticFeedback.light.trigger()
                                // Update all selected symptoms to use the shared severity
                                for i in selectedSymptoms.indices {
                                    selectedSymptoms[i].severity = newValue
                                }
                            }
                            HStack {
                                Text(SeverityScale.descriptor(for: Int(sharedSeverity)))
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(Int(sharedSeverity))/5")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Severity level: \(SeverityScale.descriptor(for: Int(sharedSeverity))), \(Int(sharedSeverity)) out of 5")
                        }
                    } else {
                        ForEach($selectedSymptoms) { $symptom in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(symptom.symptomType.name ?? "Unnamed")
                                    .font(.subheadline.bold())
                                    .accessibilityAddTraits(.isHeader)
                                Slider(value: $symptom.severity, in: 1...5, step: 1) {
                                    Text("Severity for \(symptom.symptomType.name ?? "symptom")")
                                }
                                .accessibilityLabel("Severity for \(symptom.symptomType.name ?? "symptom")")
                                .accessibilityValue(severityAccessibilityValue(for: symptom.severity))
                                .onChange(of: symptom.severity) { _, _ in
                                    HapticFeedback.light.trigger()
                                }
                                HStack {
                                    Text(SeverityScale.descriptor(for: Int(symptom.severity)))
                                        .font(.caption.bold())
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(Int(symptom.severity))/5")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Severity level: \(SeverityScale.descriptor(for: Int(symptom.severity))), \(Int(symptom.severity)) out of 5")
                            }
                            .padding(.vertical, 4)
                            .accessibilityElement(children: .contain)
                        }
                    }
                }

                Section {
                    DatePicker("Time", selection: $timestamp)
                }
            }

            Section("Additional details") {
                TextField("Notes (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityHint("Add any additional details about this symptom")

                Toggle("Save location", isOn: $includeLocation)
                    .onChange(of: includeLocation) { _, enabled in
                        HapticFeedback.selection.trigger()
                        if enabled { locationAssistant.requestLocation() }
                    }
                if includeLocation {
                    LocationStatusView(state: locationAssistant.state)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("How are you feeling?")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Menu {
                    Button(action: { saveEntries(addAnother: false) }) {
                        Label("Save", systemImage: "checkmark")
                    }
                    Button(action: { saveEntries(addAnother: true) }) {
                        Label("Save & log another", systemImage: "plus.circle")
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSaving || selectedSymptoms.isEmpty)
            }
        }
    }

    private func severityAccessibilityValue(for severity: Double) -> String {
        let level = Int(severity)
        switch level {
        case 1: return "Level 1: Stable, minimal impact"
        case 2: return "Level 2: Manageable, mild discomfort"
        case 3: return "Level 3: Challenging, moderate impact"
        case 4: return "Level 4: Severe, significant difficulty"
        default: return "Level 5: Crisis, immediate attention needed"
        }
    }

    private func saveEntries(addAnother: Bool) {
        guard !selectedSymptoms.isEmpty else {
            errorMessage = "Select at least one symptom."
            return
        }
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            // Fetch HealthKit data once for all entries
            let placemark = includeLocation ? await locationAssistant.currentPlacemark() : nil
            let hrv = await healthKit.recentHRV()
            let rhr = await healthKit.recentRestingHR()
            let sleep = await healthKit.recentSleepHours()
            let workout = await healthKit.recentWorkoutMinutes()
            let cycleDay = await healthKit.recentCycleDay()
            let flowLevel = await healthKit.recentFlowLevel()

            // Create an entry for each selected symptom
            for selectedSymptom in selectedSymptoms {
                let entry = SymptomEntry(context: context)
                entry.id = UUID()
                entry.createdAt = Date()
                entry.backdatedAt = timestamp
                entry.severity = Int16(selectedSymptom.severity)
                entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
                entry.symptomType = selectedSymptom.symptomType

                // Apply shared HealthKit data
                if let placemark { entry.locationPlacemark = placemark }
                if let hrv { entry.hkHRV = NSNumber(value: hrv) }
                if let rhr { entry.hkRestingHR = NSNumber(value: rhr) }
                if let sleep { entry.hkSleepHours = NSNumber(value: sleep) }
                if let workout { entry.hkWorkoutMinutes = NSNumber(value: workout) }
                if let cycleDay { entry.hkCycleDay = NSNumber(value: cycleDay) }
                if let flowLevel { entry.hkFlowLevel = flowLevel }
            }

            do {
                try context.save()
                HapticFeedback.success.trigger()
                if addAnother {
                    // Reset selections but keep timestamp and location
                    self.selectedSymptoms = []
                    self.sharedSeverity = 3
                    self.useSameSeverity = true
                    self.note = ""
                    self.isSaving = false
                } else {
                    dismiss()
                }
            } catch {
                HapticFeedback.error.trigger()
                errorMessage = error.localizedDescription
                context.rollback()
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
    @Environment(\.managedObjectContext) private var context

    private let maxSelection = 5

    private var starredSymptoms: [SymptomType] {
        symptomTypes.filter { $0.isStarred }.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private var recentSymptoms: [SymptomType] {
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)]
        fetchRequest.fetchLimit = 20

        guard let entries = try? context.fetch(fetchRequest) else { return [] }

        var seen = Set<UUID>()
        var recent: [SymptomType] = []

        for entry in entries {
            if let type = entry.symptomType, let id = type.id, !seen.contains(id) {
                seen.insert(id)
                recent.append(type)
                if recent.count >= 5 { break }
            }
        }

        return recent
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
            .foregroundStyle(.blue)
            .accessibilityLabel("Search all symptoms")
            .accessibilityHint("Opens a searchable list of all available symptoms")
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showAllSymptoms) {
            NavigationStack {
                AllSymptomsSheet(
                    symptomTypes: symptomTypes,
                    selectedSymptoms: $selectedSymptoms,
                    isPresented: $showAllSymptoms,
                    maxSelection: maxSelection
                )
            }
        }
    }
}

private struct AllSymptomsSheet: View {
    let symptomTypes: [SymptomType]
    @Binding var selectedSymptoms: [SelectedSymptom]
    @Binding var isPresented: Bool
    let maxSelection: Int

    @State private var searchText: String = ""

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
        let categoryOrder = ["User added", "Energy", "Pain", "Cognitive", "Sleep", "Neurological", "Digestive", "Mental health", "Respiratory & cardiovascular", "Other"]

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
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if categorisedSymptoms.isEmpty {
                        Text("No symptoms found matching '\(searchText)'")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
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
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { isPresented = false }
            }
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
        .accessibilityLabel("\(symptom.name ?? "Unnamed")")
        .accessibilityHint(isSelected ? "Tap to deselect" : (isDisabled ? "Maximum symptoms selected" : "Tap to select"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
