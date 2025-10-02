import AppIntents
import CoreData
import Foundation
import SwiftUI

@available(iOS 16.0, *)
struct GetRecentEntriesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get recent entries"
    static var description = IntentDescription("Get a summary of your recent symptom entries")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Number of entries", description: "How many recent entries to fetch", default: 5)
    var count: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let context = CoreDataStack.shared.context

        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
            NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
        ]
        fetchRequest.fetchLimit = max(1, min(10, count))

        guard let entries = try? context.fetch(fetchRequest), !entries.isEmpty else {
            return .result(dialog: "You haven't logged any symptoms yet.") {
                RecentEntriesView(entries: [])
            }
        }

        // Create summary text
        var summary = "Your \(entries.count) most recent "
        summary += entries.count == 1 ? "entry:\n" : "entries:\n"

        for entry in entries {
            let symptomName = entry.symptomType?.name ?? "Unknown"
            let severityText = SeverityScale.descriptor(for: Int(entry.severity))
            let date = entry.backdatedAt ?? entry.createdAt ?? Date()
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let timeText = formatter.localizedString(for: date, relativeTo: Date())

            summary += "\(symptomName): \(severityText) (\(timeText))"
            if let note = entry.note {
                summary += " - \(note)"
            }
            summary += "\n"
        }

        return .result(dialog: IntentDialog(stringLiteral: summary.trimmingCharacters(in: .whitespacesAndNewlines))) {
            RecentEntriesView(entries: entries.map { EntrySnippet(from: $0) })
        }
    }
}

@available(iOS 16.0, *)
struct EntrySnippet: Identifiable {
    let id: UUID
    let symptomName: String
    let severity: String
    let date: String
    let note: String?

    init(from entry: SymptomEntry) {
        self.id = entry.id ?? UUID()
        self.symptomName = entry.symptomType?.name ?? "Unknown"
        self.severity = SeverityScale.descriptor(for: Int(entry.severity))

        let date = entry.backdatedAt ?? entry.createdAt ?? Date()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        self.date = formatter.localizedString(for: date, relativeTo: Date())
        self.note = entry.note
    }
}

@available(iOS 16.0, *)
struct RecentEntriesView: View {
    let entries: [EntrySnippet]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entries.isEmpty {
                Text("No entries yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.symptomName)
                                .font(.headline)
                            Spacer()
                            Text(entry.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.severity)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let note = entry.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
    }
}
