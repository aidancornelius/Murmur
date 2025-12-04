// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// SymptomTypeFormView.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Form view for creating and editing symptom types.
//
import SwiftUI
import CoreData

struct SymptomTypeFormView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let editingType: SymptomType?
    let onSave: ((SymptomType) -> Void)?

    @State private var name: String = ""
    @State private var colorHex: String = "#6FA8DC"
    @State private var iconName: String = "heart.fill"
    @State private var category: String = ""
    @State private var isStarred: Bool = false
    @State private var starOrder: Int = 0
    @State private var errorMessage: String?

    private let colorPalette = ["#6FA8DC", "#76C7C0", "#FFD966", "#F4B183", "#C27BA0", "#E06666", "#F5A3A3", "#8DC6D2", "#FFB570", "#B07BB4", "#A678B0"]
    private let iconOptions = ["heart.fill", "bolt.horizontal.circle", "dumbbell", "figure.stand", "brain", "heart.circle", "moon.zzz", "waveform.path.ecg", "bandage", "heart.text.square", "fork.knife", "lungs.fill", "sparkles"]

    private let categoryOptions = ["", "Positive wellbeing"]

    init(editingType: SymptomType?, prefillName: String = "", onSave: ((SymptomType) -> Void)? = nil) {
        self.editingType = editingType
        self.onSave = onSave
        _name = State(initialValue: editingType?.name ?? prefillName)
        _colorHex = State(initialValue: editingType?.color ?? "#6FA8DC")
        _iconName = State(initialValue: editingType?.iconName ?? "heart.fill")
        _category = State(initialValue: editingType?.category ?? "")
        _isStarred = State(initialValue: editingType?.isStarred ?? false)
        _starOrder = State(initialValue: Int(editingType?.starOrder ?? 0))
    }

    var body: some View {
        Form {
            Section {
                TextField("Symptom name", text: $name)
                    .disabled(editingType?.isDefault == true)
            }

            Section("Color") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(colorPalette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if hex == colorHex {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture {
                                    HapticFeedback.selection.trigger()
                                    colorHex = hex
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 12) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Image(systemName: icon)
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(icon == iconName ? Color.accentColor : .gray.opacity(0.2)))
                            .onTapGesture {
                                HapticFeedback.selection.trigger()
                                iconName = icon
                            }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("Type", selection: $category) {
                    Text("Negative symptom").tag("")
                    Text("Positive wellbeing").tag("Positive wellbeing")
                }
                .pickerStyle(.segmented)
                .onChange(of: category) { _, _ in
                    HapticFeedback.selection.trigger()
                }
                .disabled(editingType?.isDefault == true)
            } footer: {
                if editingType?.isDefault == true {
                    Text("Default symptoms cannot have their type changed.")
                        .font(.caption)
                } else {
                    Text(category == "Positive wellbeing"
                        ? "Positive symptoms track good days (higher ratings = better). Great for noting energy, joy, or mental clarity."
                        : "Standard symptoms track challenges (higher ratings = worse). Use these for pain, fatigue, or other difficulties.")
                        .font(.caption)
                }
            }

            Section {
                Toggle("Show first when logging", isOn: $isStarred)
                    .onChange(of: isStarred) { _, _ in
                        HapticFeedback.selection.trigger()
                    }
                if isStarred {
                    Stepper("Priority: \(starOrder)", value: $starOrder, in: 0...100)
                        .font(.callout)
                }
            } footer: {
                Text("Your starred symptoms appear first when logging (we recommend 5 or fewer).")
                    .font(.caption)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(editingType == nil ? "Add a symptom" : "Update symptom")
        .themedScrollBackground()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please give this symptom a name."
            return
        }

        let target: SymptomType
        if let editingType {
            target = editingType
        } else {
            target = SymptomType(context: context)
            target.id = UUID()
            target.isDefault = false
        }

        // Only allow changing name and category for non-default symptoms
        if !target.isDefault {
            target.name = trimmed
            target.category = category.isEmpty ? nil : category
        }

        // Always allow changing color, icon, starred status
        target.color = colorHex
        target.iconName = iconName
        target.isStarred = isStarred
        target.starOrder = Int16(starOrder)

        do {
            if context.hasChanges {
                try context.save()
                HapticFeedback.success.trigger()
                onSave?(target)
            }
            dismiss()
        } catch let error as NSError {
            HapticFeedback.error.trigger()
            if error.code == NSManagedObjectConstraintMergeError {
                errorMessage = "A symptom with this name already exists. Please choose a different name."
            } else {
                errorMessage = error.localizedDescription
            }
            context.rollback()
        }
    }
}
