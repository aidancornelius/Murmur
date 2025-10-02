import AppIntents
import CoreData
import Foundation

// MARK: - Get Symptoms by Severity

@available(iOS 16.0, *)
struct GetSymptomsBySeverityIntent: AppIntent {
    static var title: LocalizedStringResource = "Get symptoms by severity"
    static var description = IntentDescription("Get symptom entries filtered by severity level")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Minimum severity", description: "Filter entries with this severity or higher (1-5)", default: 3)
    var minSeverity: Int

    @Parameter(title: "Days to look back", description: "How many days of history to check", default: 7)
    var daysBack: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[SymptomEntryEntity]> {
        let context = CoreDataStack.shared.context

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()

        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "severity >= %d AND backdatedAt >= %@",
            max(1, min(5, minSeverity)),
            startDate as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false)]

        guard let entries = try? context.fetch(fetchRequest) else {
            return .result(value: [])
        }

        let entities = entries.map { SymptomEntryEntity(from: $0) }
        return .result(value: entities)
    }
}

// MARK: - Get Activities by Type

@available(iOS 16.0, *)
struct GetRecentActivitiesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get recent activities"
    static var description = IntentDescription("Get recent activity events")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Number of activities", description: "How many recent activities to fetch", default: 5)
    var count: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ActivityEventEntity]> {
        let context = CoreDataStack.shared.context

        let fetchRequest: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ActivityEvent.backdatedAt, ascending: false)]
        fetchRequest.fetchLimit = max(1, min(20, count))

        guard let activities = try? context.fetch(fetchRequest) else {
            return .result(value: [])
        }

        let entities = activities.map { ActivityEventEntity(from: $0) }
        return .result(value: entities)
    }
}

// MARK: - Get Symptoms for Date Range

@available(iOS 16.0, *)
struct GetSymptomsInRangeIntent: AppIntent {
    static var title: LocalizedStringResource = "Get symptoms in date range"
    static var description = IntentDescription("Get symptom entries within a specific date range")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Start date", description: "Beginning of date range")
    var startDate: Date

    @Parameter(title: "End date", description: "End of date range")
    var endDate: Date

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[SymptomEntryEntity]> {
        let context = CoreDataStack.shared.context

        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "backdatedAt >= %@ AND backdatedAt <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false)]

        guard let entries = try? context.fetch(fetchRequest) else {
            return .result(value: [])
        }

        let entities = entries.map { SymptomEntryEntity(from: $0) }
        return .result(value: entities)
    }
}

// MARK: - Get Symptom Types

@available(iOS 16.0, *)
struct GetSymptomTypesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get symptom types"
    static var description = IntentDescription("Get all available symptom types")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Starred only", description: "Only return starred/favourite symptoms", default: false)
    var starredOnly: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[SymptomTypeEntity]> {
        let context = CoreDataStack.shared.context

        let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()

        if starredOnly {
            fetchRequest.predicate = NSPredicate(format: "isStarred == YES")
        }

        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SymptomType.isStarred, ascending: false),
            NSSortDescriptor(keyPath: \SymptomType.name, ascending: true)
        ]

        guard let types = try? context.fetch(fetchRequest) else {
            return .result(value: [])
        }

        let entities = types.map { SymptomTypeEntity(from: $0) }
        return .result(value: entities)
    }
}

// MARK: - Get Daily Summary

@available(iOS 16.0, *)
struct GetDailySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get daily summary"
    static var description = IntentDescription("Get a summary of symptoms and activities for a specific day")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Date", description: "The date to get summary for", default: Date())
    var date: Date

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = CoreDataStack.shared.context
        let calendar = Calendar.current

        // Get start and end of day
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        // Fetch symptoms
        let symptomFetch: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        symptomFetch.predicate = NSPredicate(
            format: "backdatedAt >= %@ AND backdatedAt < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        symptomFetch.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: true)]

        // Fetch activities
        let activityFetch: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
        activityFetch.predicate = NSPredicate(
            format: "backdatedAt >= %@ AND backdatedAt < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        activityFetch.sortDescriptors = [NSSortDescriptor(keyPath: \ActivityEvent.backdatedAt, ascending: true)]

        let symptoms = (try? context.fetch(symptomFetch)) ?? []
        let activities = (try? context.fetch(activityFetch)) ?? []

        // Build summary
        var summary = ""

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        summary += "Summary for \(dateFormatter.string(from: date))\n\n"

        if symptoms.isEmpty && activities.isEmpty {
            summary += "No entries for this day."
        } else {
            if !symptoms.isEmpty {
                summary += "Symptoms (\(symptoms.count)):\n"
                for symptom in symptoms {
                    let name = symptom.symptomType?.name ?? "Unknown"
                    let severity = SeverityScale.descriptor(for: Int(symptom.severity))
                    summary += "• \(name): \(severity)\n"
                }
                summary += "\n"
            }

            if !activities.isEmpty {
                summary += "Activities (\(activities.count)):\n"
                for activity in activities {
                    let name = activity.name ?? "Unknown"
                    summary += "• \(name)\n"
                }
            }
        }

        return .result(dialog: summary.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

// MARK: - Count Symptoms

@available(iOS 16.0, *)
struct CountSymptomsIntent: AppIntent {
    static var title: LocalizedStringResource = "Count symptoms"
    static var description = IntentDescription("Count how many symptom entries you've logged")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Days to count", description: "How many days back to count (0 for all time)", default: 7)
    var daysBack: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Int> {
        let context = CoreDataStack.shared.context

        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()

        if daysBack > 0 {
            let calendar = Calendar.current
            let startDate = calendar.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
            fetchRequest.predicate = NSPredicate(format: "backdatedAt >= %@", startDate as NSDate)
        }

        let count = (try? context.count(for: fetchRequest)) ?? 0

        let timeframe = daysBack > 0 ? "in the last \(daysBack) days" : "of all time"
        let message = "You've logged \(count) symptom \(count == 1 ? "entry" : "entries") \(timeframe)."

        return .result(value: count, dialog: message)
    }
}
