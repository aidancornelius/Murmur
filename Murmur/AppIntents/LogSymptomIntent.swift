//
//  LogSymptomIntent.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import AppIntents
import CoreData
import Foundation

@available(iOS 16.0, *)
struct LogSymptomIntent: AppIntent {
    static var title: LocalizedStringResource = "Log symptom"
    static var description = IntentDescription("Quickly log a symptom")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Symptom name", description: "The name of the symptom to log")
    var symptomName: String?

    @Parameter(title: "Severity", description: "How severe is it (1-5)?", default: 3)
    var severity: Int

    @Parameter(title: "Notes", description: "Any additional notes")
    var notes: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$symptomName) with severity \(\.$severity)") {
            \.$notes
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = CoreDataStack.shared.context

        // Fetch available symptom types
        let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomType.name, ascending: true)]

        guard let symptomTypes = try? context.fetch(fetchRequest), !symptomTypes.isEmpty else {
            return .result(dialog: "You need to add some symptoms in the app first.")
        }

        // Find matching symptom type
        let selectedType: SymptomType
        if let symptomName = symptomName?.lowercased() {
            // Try to find a matching symptom
            if let match = symptomTypes.first(where: { $0.name?.lowercased() == symptomName }) {
                selectedType = match
            } else if let fuzzyMatch = symptomTypes.first(where: { $0.name?.lowercased().contains(symptomName) ?? false }) {
                selectedType = fuzzyMatch
            } else {
                // Use first starred or just first
                selectedType = symptomTypes.first(where: { $0.isStarred }) ?? symptomTypes[0]
            }
        } else {
            // Use first starred or just first
            selectedType = symptomTypes.first(where: { $0.isStarred }) ?? symptomTypes[0]
        }

        // Clamp severity to valid range
        let validSeverity = max(1, min(5, severity))

        // Create entry
        let entry = SymptomEntry(context: context)
        entry.id = UUID()
        entry.createdAt = Date()
        entry.backdatedAt = Date()
        entry.severity = Int16(validSeverity)
        entry.note = notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? notes : nil
        entry.symptomType = selectedType

        // Save
        do {
            try context.save()
            let severityText = SeverityScale.descriptor(for: validSeverity).lowercased()
            return .result(dialog: "Logged \(selectedType.name ?? "symptom") with \(severityText) severity.")
        } catch {
            return .result(dialog: "Failed to save entry: \(error.localizedDescription)")
        }
    }
}

@available(iOS 16.0, *)
struct MurmurAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        // Primary actions
        AppShortcut(
            intent: OpenAddEntryIntent(),
            phrases: [
                "How am I feeling in \(.applicationName)",
                "Log how I'm feeling in \(.applicationName)",
                "Open \(.applicationName) symptom log"
            ],
            shortTitle: "How are you feeling?",
            systemImageName: "heart.text.square"
        )
        AppShortcut(
            intent: OpenAddActivityIntent(),
            phrases: [
                "Log activity in \(.applicationName)",
                "Record activity in \(.applicationName)",
                "Add activity to \(.applicationName)"
            ],
            shortTitle: "Log an activity",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: LogSymptomIntent(),
            phrases: [
                "Log symptom in \(.applicationName)",
                "Record symptom in \(.applicationName)",
                "Quick log in \(.applicationName)"
            ],
            shortTitle: "Quick log symptom",
            systemImageName: "bolt.heart"
        )

        // Data query actions
        AppShortcut(
            intent: GetRecentEntriesIntent(),
            phrases: [
                "Get my recent symptoms from \(.applicationName)",
                "Show my \(.applicationName) entries",
                "What are my recent \(.applicationName) logs"
            ],
            shortTitle: "Get recent entries",
            systemImageName: "list.bullet.clipboard"
        )
        AppShortcut(
            intent: GetSymptomsBySeverityIntent(),
            phrases: [
                "Get severe symptoms from \(.applicationName)",
                "Show high severity entries in \(.applicationName)"
            ],
            shortTitle: "Get symptoms by severity",
            systemImageName: "exclamationmark.triangle"
        )
        AppShortcut(
            intent: GetDailySummaryIntent(),
            phrases: [
                "Get my \(.applicationName) summary",
                "Show my day in \(.applicationName)",
                "What's my \(.applicationName) summary"
            ],
            shortTitle: "Get daily summary",
            systemImageName: "calendar.day.timeline.left"
        )
        AppShortcut(
            intent: CountSymptomsIntent(),
            phrases: [
                "How many symptoms in \(.applicationName)",
                "Count my \(.applicationName) entries"
            ],
            shortTitle: "Count symptoms",
            systemImageName: "number"
        )
    }
}
