//
//  AllSymptomsSheet.swift
//  Murmur
//
//  Extracted from UnifiedEventView.swift on 10/10/2025.
//

import CoreData
import SwiftUI

/// A sheet for selecting multiple symptoms with search and categorisation
struct AllSymptomsSheet: View {
    let symptomTypes: [SymptomType]
    @Binding var selectedSymptoms: [SelectedSymptom]
    @Binding var isPresented: Bool
    let maxSelection: Int
    var onSymptomCreated: (() -> Void)? = nil

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
                    // Notify caller that a new symptom was created
                    onSymptomCreated?()
                }
                .environment(\.managedObjectContext, context)
            }
            .themedSurface()
        }
    }
}

/// A button for multi-selecting symptoms in the AllSymptomsSheet
struct SymptomMultiSelectButton: View {
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
