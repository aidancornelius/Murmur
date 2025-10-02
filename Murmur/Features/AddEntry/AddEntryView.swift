import CoreData
import CoreLocation
import Foundation
import SwiftUI

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

    @State private var selectedType: SymptomType?
    @State private var severity: Double = 3
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
                Section("Which symptom") {
                    SymptomCategoryPicker(symptomTypes: Array(symptomTypes), selectedType: $selectedType)
                }

            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: $severity, in: 1...5, step: 1) {
                        Text("How intense")
                    }
                    .accessibilityValue(severityAccessibilityValue)
                    HStack {
                        Text(SeverityScale.descriptor(for: Int(severity)))
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(Int(severity))/5")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                DatePicker("Time", selection: $timestamp)
            }

            Section("Additional details") {
                TextField("Notes (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityHint("Add any additional details about this symptom")

                Toggle("Save location", isOn: $includeLocation)
                    .onChange(of: includeLocation) { _, enabled in
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
        .onAppear {
            if selectedType == nil {
                selectedType = symptomTypes.first
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Menu {
                    Button(action: { saveEntry(addAnother: false) }) {
                        Label("Save", systemImage: "checkmark")
                    }
                    Button(action: { saveEntry(addAnother: true) }) {
                        Label("Save & log another", systemImage: "plus.circle")
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSaving || selectedType == nil)
            }
        }
    }

    private var severityAccessibilityValue: String {
        let level = Int(severity)
        switch level {
        case 1: return "Level 1: Stable, minimal impact"
        case 2: return "Level 2: Manageable, mild discomfort"
        case 3: return "Level 3: Challenging, moderate impact"
        case 4: return "Level 4: Severe, significant difficulty"
        default: return "Level 5: Crisis, immediate attention needed"
        }
    }

    private func saveEntry(addAnother: Bool) {
        guard let currentType = selectedType else {
            errorMessage = "Add at least one symptom in Settings first."
            return
        }
        isSaving = true
        errorMessage = nil

        let entry = SymptomEntry(context: context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.backdatedAt = timestamp
        entry.severity = Int16(severity)
        entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        entry.symptomType = currentType

        Task { @MainActor in
            if includeLocation {
                entry.locationPlacemark = await locationAssistant.currentPlacemark()
            }
            if let hrv = await healthKit.recentHRV() {
                entry.hkHRV = NSNumber(value: hrv)
            }
            if let rhr = await healthKit.recentRestingHR() {
                entry.hkRestingHR = NSNumber(value: rhr)
            }
            if let sleep = await healthKit.recentSleepHours() {
                entry.hkSleepHours = NSNumber(value: sleep)
            }
            if let workout = await healthKit.recentWorkoutMinutes() {
                entry.hkWorkoutMinutes = NSNumber(value: workout)
            }
            if let cycleDay = await healthKit.recentCycleDay() {
                entry.hkCycleDay = NSNumber(value: cycleDay)
            }
            if let flowLevel = await healthKit.recentFlowLevel() {
                entry.hkFlowLevel = flowLevel
            }
            do {
                try context.save()
                if addAnother {
                    // Reset only symptom type, severity, and note - keep timestamp and location
                    self.selectedType = starredSymptoms.first ?? unstarredSymptoms.first
                    self.severity = 3
                    self.note = ""
                    self.isSaving = false
                } else {
                    dismiss()
                }
            } catch {
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

private struct SymptomCategoryPicker: View {
    let symptomTypes: [SymptomType]
    @Binding var selectedType: SymptomType?

    @State private var showAllSymptoms = false
    @Environment(\.managedObjectContext) private var context

    private var starredSymptoms: [SymptomType] {
        symptomTypes.filter { $0.isStarred }.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private var recentSymptoms: [SymptomType] {
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)]
        fetchRequest.fetchLimit = 20

        guard let entries = try? context.fetch(fetchRequest) else { return [] }

        // Get unique symptom types from recent entries, max 5
        var seen = Set<UUID>()
        var recent: [SymptomType] = []

        for entry in entries {
            if let type = entry.symptomType, let id = type.id, !seen.contains(id) {
                seen.insert(id)
                recent.append(type)
                if recent.count >= 5 { break }
            }
        }

        // If there's a selected type that's not already in the list, add it at the front
        if let selected = selectedType,
           let selectedId = selected.id,
           !seen.contains(selectedId) {
            recent.insert(selected, at: 0)
            // Keep only 5 items
            if recent.count > 5 {
                recent.removeLast()
            }
        }

        return recent
    }

    private var categorisedSymptoms: [(category: String, symptoms: [SymptomType])] {
        let grouped = Dictionary(grouping: symptomTypes) { symptom in
            symptom.category ?? "User added"
        }

        let categoryOrder = ["Energy", "Pain", "Cognitive", "Sleep", "Neurological", "Digestive", "Mental health", "Respiratory & cardiovascular", "Other", "User added"]

        return categoryOrder.compactMap { category in
            guard let symptoms = grouped[category], !symptoms.isEmpty else { return nil }
            return (category, symptoms.sorted { ($0.name ?? "") < ($1.name ?? "") })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Starred symptoms
            if !starredSymptoms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Favourites")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        ForEach(starredSymptoms) { symptom in
                            SymptomButton(
                                symptom: symptom,
                                isSelected: selectedType?.id == symptom.id,
                                action: { selectedType = symptom }
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
                            SymptomButton(
                                symptom: symptom,
                                isSelected: selectedType?.id == symptom.id,
                                action: { selectedType = symptom }
                            )
                        }
                    }
                }
            }

            // Browse all button
            Button(action: { showAllSymptoms = true }) {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("Browse all symptoms")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showAllSymptoms) {
            NavigationStack {
                AllSymptomsSheet(symptomTypes: symptomTypes, selectedType: $selectedType, isPresented: $showAllSymptoms)
            }
        }
    }
}

private struct AllSymptomsSheet: View {
    let symptomTypes: [SymptomType]
    @Binding var selectedType: SymptomType?
    @Binding var isPresented: Bool

    private var categorisedSymptoms: [(category: String, symptoms: [SymptomType])] {
        let grouped = Dictionary(grouping: symptomTypes) { symptom in
            symptom.category ?? "User added"
        }

        let categoryOrder = ["Energy", "Pain", "Cognitive", "Sleep", "Neurological", "Digestive", "Mental health", "Respiratory & cardiovascular", "Other", "User added"]

        return categoryOrder.compactMap { category in
            guard let symptoms = grouped[category], !symptoms.isEmpty else { return nil }
            return (category, symptoms.sorted { ($0.name ?? "") < ($1.name ?? "") })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(categorisedSymptoms, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.category)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                            ForEach(group.symptoms) { symptom in
                                SymptomButton(
                                    symptom: symptom,
                                    isSelected: selectedType?.id == symptom.id,
                                    action: {
                                        selectedType = symptom
                                        isPresented = false
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("All symptoms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { isPresented = false }
            }
        }
    }
}

private struct SymptomButton: View {
    let symptom: SymptomType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symptom.iconName ?? "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : symptom.uiColor)
                    .frame(height: 24)

                Text(symptom.name ?? "Unnamed")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : .primary)
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
                    .fill(isSelected ? symptom.uiColor : symptom.uiColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(symptom.uiColor, lineWidth: isSelected ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
        .frame(minWidth: 60, minHeight: 88)
        .accessibilityLabel("\(symptom.name ?? "Unnamed")\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
