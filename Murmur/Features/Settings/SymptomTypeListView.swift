// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// SymptomTypeListView.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// List view displaying user-defined symptom types.
//
import SwiftUI
import CoreData

struct SymptomTypeListView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme
    @FetchRequest(
        entity: SymptomType.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \SymptomType.isDefault, ascending: true),
            NSSortDescriptor(keyPath: \SymptomType.name, ascending: true)
        ]
    ) private var types: FetchedResults<SymptomType>

    @State private var editingType: SymptomType?
    @State private var presentingForm = false
    @State private var symptomToDelete: SymptomType?
    @State private var showDeleteConfirmation = false
    @State private var deleteEntryCount = 0

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        List {
            Section {
                Text("Track the symptoms that matter to you. Your custom symptoms help you notice patterns and understand what affects your wellbeing. Add one with the button above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(palette.backgroundColor)
            }

            ForEach(types) { type in
                NavigationLink(value: type.objectID) {
                    HStack {
                        Circle()
                            .fill(type.uiColor)
                            .frame(width: 18, height: 18)
                        Text(type.name ?? "Unnamed")
                        Spacer()
                        if type.isDefault {
                            Text("Default")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: type.iconName ?? "circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("\(type.name ?? "Unnamed")\(type.isDefault ? ", default symptom" : "")")
                .accessibilityHint("Double tap to edit this symptom")
                .deleteDisabled(type.isDefault)
                .listRowBackground(palette.surfaceColor)
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Tracked symptoms")
        .navigationBarTitleDisplayMode(.large)
        .themedScrollBackground()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingType = nil
                    presentingForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add symptom")
                .accessibilityHint("Creates a new custom symptom to track")
            }
        }
        .sheet(isPresented: $presentingForm) {
            NavigationStack {
                SymptomTypeFormView(editingType: editingType)
                    .environment(\.managedObjectContext, context)
            }
            .themedSurface()
        }
        .navigationDestination(for: NSManagedObjectID.self) { objectID in
            if let type = try? context.existingObject(with: objectID) as? SymptomType {
                SymptomTypeFormView(editingType: type)
                    .environment(\.managedObjectContext, context)
            }
        }
        .alert("Delete symptom?", isPresented: $showDeleteConfirmation, presenting: symptomToDelete) { symptom in
            Button("Cancel", role: .cancel) {
                symptomToDelete = nil
            }
            Button("Delete", role: .destructive) {
                performDelete(symptom)
            }
        } message: { symptom in
            if deleteEntryCount > 0 {
                Text("This will delete '\(symptom.name ?? "Unnamed")' and \(deleteEntryCount) timeline \(deleteEntryCount == 1 ? "entry" : "entries") using it.")
            } else {
                Text("This will delete '\(symptom.name ?? "Unnamed")'.")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        guard let offset = offsets.first else { return }
        let symptom = types[offset]

        // Don't allow deleting default symptoms
        guard !symptom.isDefault else { return }

        // Count entries using this symptom
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "symptomType == %@", symptom)
        deleteEntryCount = (try? context.count(for: fetchRequest)) ?? 0

        // Show confirmation
        symptomToDelete = symptom
        showDeleteConfirmation = true
    }

    private func performDelete(_ symptom: SymptomType) {
        // Delete all entries using this symptom
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "symptomType == %@", symptom)

        if let entries = try? context.fetch(fetchRequest) {
            entries.forEach(context.delete)
        }

        // Delete the symptom itself
        context.delete(symptom)

        if (try? context.save()) != nil {
            HapticFeedback.success.trigger()
        }

        symptomToDelete = nil
    }
}
