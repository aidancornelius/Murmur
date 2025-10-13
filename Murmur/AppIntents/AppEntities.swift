//
//  AppEntities.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import AppIntents
import CoreData
import Foundation

// MARK: - Symptom Entry Entity

@available(iOS 16.0, *)
struct SymptomEntryEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Symptom Entry"
    static let defaultQuery = SymptomEntryQuery()

    var id: UUID
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(symptomName)",
            subtitle: "\(severityDescription) - \(dateDescription)",
            image: .init(systemName: "heart.text.square")
        )
    }

    var symptomName: String
    var severity: Int
    var severityDescription: String
    var date: Date
    var dateDescription: String
    var note: String?

    init(from entry: SymptomEntry) {
        self.id = entry.id ?? UUID()
        self.symptomName = entry.symptomType?.name ?? "Unknown"
        self.severity = Int(entry.severity)
        self.severityDescription = SeverityScale.descriptor(for: Int(entry.severity))
        self.date = entry.backdatedAt ?? entry.createdAt ?? DateUtility.now()

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        self.dateDescription = formatter.localizedString(for: date, relativeTo: DateUtility.now())
        self.note = entry.note
    }
}

@available(iOS 16.0, *)
struct SymptomEntryQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [SymptomEntryEntity] {
        let context = await MainActor.run { CoreDataStack.shared.context }

        guard let entries = try? await context.perform({
            let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id IN %@", identifiers)
            return try context.fetch(fetchRequest)
        }) else {
            return []
        }

        return entries.map { SymptomEntryEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [SymptomEntryEntity] {
        let context = await MainActor.run { CoreDataStack.shared.context }

        guard let entries = try? await context.perform({
            let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false)]
            fetchRequest.fetchLimit = 5
            return try context.fetch(fetchRequest)
        }) else {
            return []
        }

        return entries.map { SymptomEntryEntity(from: $0) }
    }
}

// MARK: - Activity Event Entity

@available(iOS 16.0, *)
struct ActivityEventEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Activity Event"
    static let defaultQuery = ActivityEventQuery()

    var id: UUID
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: dateDescription),
            image: .init(systemName: "calendar.badge.clock")
        )
    }

    var name: String
    var date: Date
    var dateDescription: String
    var physicalExertion: Int
    var cognitiveExertion: Int
    var emotionalLoad: Int
    var durationMinutes: Int?
    var note: String?

    init(from activity: ActivityEvent) {
        self.id = activity.id ?? UUID()
        self.name = activity.name ?? "Unknown"
        self.date = activity.backdatedAt ?? activity.createdAt ?? DateUtility.now()

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        self.dateDescription = formatter.localizedString(for: date, relativeTo: DateUtility.now())

        self.physicalExertion = Int(activity.physicalExertion)
        self.cognitiveExertion = Int(activity.cognitiveExertion)
        self.emotionalLoad = Int(activity.emotionalLoad)
        self.durationMinutes = activity.durationMinutes?.intValue
        self.note = activity.note
    }
}

@available(iOS 16.0, *)
struct ActivityEventQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ActivityEventEntity] {
        let context = await MainActor.run { CoreDataStack.shared.context }

        guard let activities = try? await context.perform({
            let fetchRequest: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id IN %@", identifiers)
            return try context.fetch(fetchRequest)
        }) else {
            return []
        }

        return activities.map { ActivityEventEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [ActivityEventEntity] {
        let context = await MainActor.run { CoreDataStack.shared.context }

        guard let activities = try? await context.perform({
            let fetchRequest: NSFetchRequest<ActivityEvent> = ActivityEvent.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ActivityEvent.backdatedAt, ascending: false)]
            fetchRequest.fetchLimit = 5
            return try context.fetch(fetchRequest)
        }) else {
            return []
        }

        return activities.map { ActivityEventEntity(from: $0) }
    }
}

// MARK: - Symptom Type Entity

@available(iOS 16.0, *)
struct SymptomTypeEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Symptom Type"
    static let defaultQuery = SymptomTypeQuery()

    var id: UUID
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: category),
            image: .init(systemName: iconName)
        )
    }

    var name: String
    var category: String
    var iconName: String
    var isStarred: Bool

    init(from symptomType: SymptomType) {
        self.id = symptomType.id ?? UUID()
        self.name = symptomType.name ?? "Unknown"
        self.category = symptomType.category ?? "Other"
        self.iconName = symptomType.iconName ?? "circle"
        self.isStarred = symptomType.isStarred
    }
}

@available(iOS 16.0, *)
struct SymptomTypeQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [SymptomTypeEntity] {
        let context = await MainActor.run { CoreDataStack.shared.context }

        guard let types = try? await context.perform({
            let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id IN %@", identifiers)
            return try context.fetch(fetchRequest)
        }) else {
            return []
        }

        return types.map { SymptomTypeEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [SymptomTypeEntity] {
        let context = await MainActor.run { CoreDataStack.shared.context }

        guard let types = try? await context.perform({
            let fetchRequest: NSFetchRequest<SymptomType> = SymptomType.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \SymptomType.isStarred, ascending: false),
                NSSortDescriptor(keyPath: \SymptomType.name, ascending: true)
            ]
            fetchRequest.fetchLimit = 10
            return try context.fetch(fetchRequest)
        }) else {
            return []
        }

        return types.map { SymptomTypeEntity(from: $0) }
    }
}
