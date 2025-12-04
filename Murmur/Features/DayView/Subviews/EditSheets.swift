// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// EditSheets.swift
// Created by Aidan Cornelius-Bell on 04/12/2025.
// Sheet views for editing timeline items.
//
import SwiftUI

// MARK: - Edit Entry Sheet

struct EditEntrySheet: View {
    @ObservedObject var entry: SymptomEntry
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var severity: Double
    @State private var note: String

    init(entry: SymptomEntry, onSave: @escaping () -> Void) {
        self.entry = entry
        self.onSave = onSave
        _severity = State(initialValue: Double(entry.severity))
        _note = State(initialValue: entry.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(entry.symptomType?.name ?? "Symptom")
                            .font(.headline)
                        Spacer()
                        SeverityBadge(value: severity, precision: .integer, isPositive: entry.symptomType?.isPositive ?? false)
                    }
                }

                Section("Severity") {
                    Slider(value: $severity, in: 1...5, step: 1)
                    Text(SeverityScale.descriptor(for: Int(severity), isPositive: entry.symptomType?.isPositive ?? false))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Note") {
                    TextField("Add a note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        entry.severity = Int16(severity)
                        entry.note = note.isEmpty ? nil : note
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Edit Activity Sheet

struct EditActivitySheet: View {
    @ObservedObject var activity: ActivityEvent
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var physicalExertion: Double
    @State private var cognitiveExertion: Double
    @State private var emotionalLoad: Double
    @State private var note: String

    init(activity: ActivityEvent, onSave: @escaping () -> Void) {
        self.activity = activity
        self.onSave = onSave
        _name = State(initialValue: activity.name ?? "")
        _physicalExertion = State(initialValue: Double(activity.physicalExertion))
        _cognitiveExertion = State(initialValue: Double(activity.cognitiveExertion))
        _emotionalLoad = State(initialValue: Double(activity.emotionalLoad))
        _note = State(initialValue: activity.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Name", text: $name)
                }

                Section("Exertion levels") {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "figure.walk")
                            Text("Physical: \(Int(physicalExertion))")
                        }
                        Slider(value: $physicalExertion, in: 1...5, step: 1)
                    }
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                            Text("Cognitive: \(Int(cognitiveExertion))")
                        }
                        Slider(value: $cognitiveExertion, in: 1...5, step: 1)
                    }
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "heart")
                            Text("Emotional: \(Int(emotionalLoad))")
                        }
                        Slider(value: $emotionalLoad, in: 1...5, step: 1)
                    }
                }

                Section("Note") {
                    TextField("Add a note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        activity.name = name.isEmpty ? nil : name
                        activity.physicalExertion = Int16(physicalExertion)
                        activity.cognitiveExertion = Int16(cognitiveExertion)
                        activity.emotionalLoad = Int16(emotionalLoad)
                        activity.note = note.isEmpty ? nil : note
                        onSave()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Edit Sleep Sheet

struct EditSleepSheet: View {
    @ObservedObject var sleep: SleepEvent
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var quality: Double
    @State private var note: String

    init(sleep: SleepEvent, onSave: @escaping () -> Void) {
        self.sleep = sleep
        self.onSave = onSave
        _quality = State(initialValue: Double(sleep.quality))
        _note = State(initialValue: sleep.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quality") {
                    HStack {
                        ForEach(1...5, id: \.self) { level in
                            Image(systemName: level <= Int(quality) ? "moon.fill" : "moon")
                                .foregroundStyle(level <= Int(quality) ? .indigo : .secondary)
                                .onTapGesture {
                                    quality = Double(level)
                                }
                        }
                    }
                    .font(.title2)
                }

                Section("Note") {
                    TextField("Add a note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        sleep.quality = Int16(quality)
                        sleep.note = note.isEmpty ? nil : note
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Edit Meal Sheet

struct EditMealSheet: View {
    @ObservedObject var meal: MealEvent
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var mealType: String
    @State private var mealDescription: String
    @State private var note: String

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

    init(meal: MealEvent, onSave: @escaping () -> Void) {
        self.meal = meal
        self.onSave = onSave
        _mealType = State(initialValue: meal.mealType ?? "snack")
        _mealDescription = State(initialValue: meal.mealDescription ?? "")
        _note = State(initialValue: meal.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal type") {
                    Picker("Type", selection: $mealType) {
                        ForEach(mealTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Description") {
                    TextField("What did you eat?", text: $mealDescription, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Note") {
                    TextField("Add a note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        meal.mealType = mealType
                        meal.mealDescription = mealDescription.isEmpty ? nil : mealDescription
                        meal.note = note.isEmpty ? nil : note
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
