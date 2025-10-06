//
//  ManualCycleSettingsView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI

struct ManualCycleSettingsView: View {
    @EnvironmentObject private var manualCycleTracker: ManualCycleTracker
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var entries: [ManualCycleEntry] = []
    @State private var showingAddEntry = false
    @State private var selectedDate = Date()
    @State private var selectedFlowLevel = "light"
    @State private var showingSetCycleDay = false
    @State private var cycleDayInput = 1
    @State private var errorMessage: String?

    let flowLevels = [
        ("spotting", "Spotting", "drop"),
        ("light", "Light", "drop.fill"),
        ("medium", "Medium", "drop.fill"),
        ("heavy", "Heavy", "drop.fill")
    ]

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        Form {
            Section {
                Text("Track your cycle manually if you don't use the Health app or have irregular cycles you wish to track (e.g., PCOS). This will override Health data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            Section {
                Toggle("Enable manual tracking", isOn: Binding(
                    get: { manualCycleTracker.isEnabled },
                    set: { manualCycleTracker.setEnabled($0) }
                ))
            }
            .listRowBackground(palette.surfaceColor)

            if manualCycleTracker.isEnabled {
                Section {
                    Button(action: { showingSetCycleDay = true }) {
                        HStack {
                            Label("Cycle day", systemImage: "calendar")
                            Spacer()
                            if let cycleDay = manualCycleTracker.latestCycleDay {
                                Text("Day \(cycleDay)")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("–")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)

                    HStack {
                        Label("Today's flow", systemImage: "drop.fill")
                        Spacer()
                        if let flowLevel = manualCycleTracker.latestFlowLevel {
                            Text(flowLevel.capitalized)
                        } else {
                            Text("–")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Current cycle info")
                } footer: {
                    Text("Tap cycle day to set it manually. It will auto-increment each day.")
                }
                .listRowBackground(palette.surfaceColor)

                Section {
                    Button(action: { showingAddEntry = true }) {
                        Label("Log cycle day", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Manage entries")
                }
                .listRowBackground(palette.surfaceColor)

                if !entries.isEmpty {
                    Section {
                        ForEach(entries) { entry in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(entry.date, style: .date)
                                        .font(.body)
                                    Text(entry.flowLevel.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: iconForFlowLevel(entry.flowLevel))
                                    .foregroundStyle(colorForFlowLevel(entry.flowLevel))
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    } header: {
                        Text("Recent entries")
                    }
                    .listRowBackground(palette.surfaceColor)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .listRowBackground(palette.surfaceColor)
            }
        }
        .navigationTitle("Manual cycle tracking")
        .themedScrollBackground()
        .sheet(isPresented: $showingSetCycleDay) {
            NavigationStack {
                Form {
                    Section {
                        Stepper(value: $cycleDayInput, in: 1...99) {
                            HStack {
                                Text("Cycle day")
                                Spacer()
                                Text("\(cycleDayInput)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } footer: {
                        Text("Set what day of your cycle you're on today. This will automatically increment each day.")
                    }
                }
                .themedScrollBackground()
                .navigationTitle("Set cycle day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingSetCycleDay = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Set") {
                            setCycleDay()
                        }
                    }
                }
            }
            .themedSurface()
            .onAppear {
                cycleDayInput = manualCycleTracker.latestCycleDay ?? 1
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            NavigationStack {
                Form {
                    Section {
                        DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    }

                    Section {
                        Picker("Flow level", selection: $selectedFlowLevel) {
                            ForEach(flowLevels, id: \.0) { level in
                                HStack {
                                    Image(systemName: level.2)
                                    Text(level.1)
                                }
                                .tag(level.0)
                            }
                        }
                        .pickerStyle(.inline)
                    } header: {
                        Text("Select flow level")
                    }
                }
                .themedScrollBackground()
                .navigationTitle("Add entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddEntry = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            addEntry()
                        }
                    }
                }
            }
            .themedSurface()
        }
        .onAppear {
            loadEntries()
        }
    }

    private func loadEntries() {
        do {
            entries = try manualCycleTracker.allEntries()
        } catch {
            errorMessage = "Failed to load entries: \(error.localizedDescription)"
        }
    }

    private func addEntry() {
        do {
            try manualCycleTracker.addEntry(date: selectedDate, flowLevel: selectedFlowLevel)
            loadEntries()
            showingAddEntry = false
            errorMessage = nil
        } catch {
            errorMessage = "Failed to add entry: \(error.localizedDescription)"
        }
    }

    private func setCycleDay() {
        manualCycleTracker.setCycleDay(cycleDayInput)
        showingSetCycleDay = false
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            do {
                try manualCycleTracker.removeEntry(date: entry.date)
            } catch {
                errorMessage = "Failed to delete entry: \(error.localizedDescription)"
            }
        }
        loadEntries()
    }

    private func iconForFlowLevel(_ level: String) -> String {
        flowLevels.first(where: { $0.0 == level })?.2 ?? "drop"
    }

    private func colorForFlowLevel(_ level: String) -> Color {
        switch level {
        case "spotting": return .pink
        case "light": return .red.opacity(0.6)
        case "medium": return .red
        case "heavy": return .red.opacity(0.9)
        default: return .gray
        }
    }
}
