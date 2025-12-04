//
//  DataBackupService.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import CoreData
import CryptoKit
import Foundation

/// Service for backing up and restoring all app data with encryption
@MainActor
final class DataBackupService {
    private let stack: CoreDataStack

    enum BackupError: LocalizedError {
        case exportFailed(String)
        case importFailed(String)
        case encryptionFailed
        case decryptionFailed
        case invalidData
        case invalidPassword

        var errorDescription: String? {
            switch self {
            case .exportFailed(let reason):
                return "Backup failed: \(reason)"
            case .importFailed(let reason):
                return "Restore failed: \(reason)"
            case .encryptionFailed:
                return "Failed to encrypt backup"
            case .decryptionFailed:
                return "Failed to decrypt backup"
            case .invalidData:
                return "Backup file is corrupted or invalid"
            case .invalidPassword:
                return "Incorrect password"
            }
        }
    }

    /// Current backup format version. Increment when adding new fields or entities.
    nonisolated static let currentBackupVersion = 2

    struct BackupData: Codable {
        let version: Int
        let createdAt: Date
        let entries: [EntryBackup]
        let symptomTypes: [SymptomTypeBackup]
        let activities: [ActivityBackup]
        let manualCycleEntries: [ManualCycleEntryBackup]
        let reminders: [ReminderBackup]
        let manualCyclePreferences: ManualCyclePreferences
        // Added in version 2
        let sleepEvents: [SleepEventBackup]?
        let mealEvents: [MealEventBackup]?
        let dayReflections: [DayReflectionBackup]?

        init(
            version: Int = DataBackupService.currentBackupVersion,
            createdAt: Date,
            entries: [EntryBackup],
            symptomTypes: [SymptomTypeBackup],
            activities: [ActivityBackup],
            manualCycleEntries: [ManualCycleEntryBackup],
            reminders: [ReminderBackup],
            manualCyclePreferences: ManualCyclePreferences,
            sleepEvents: [SleepEventBackup]? = nil,
            mealEvents: [MealEventBackup]? = nil,
            dayReflections: [DayReflectionBackup]? = nil
        ) {
            self.version = version
            self.createdAt = createdAt
            self.entries = entries
            self.symptomTypes = symptomTypes
            self.activities = activities
            self.manualCycleEntries = manualCycleEntries
            self.reminders = reminders
            self.manualCyclePreferences = manualCyclePreferences
            self.sleepEvents = sleepEvents
            self.mealEvents = mealEvents
            self.dayReflections = dayReflections
        }

        struct EntryBackup: Codable {
            let id: UUID
            let createdAt: Date
            let backdatedAt: Date?
            let severity: Int16
            let note: String?
            let symptomTypeID: UUID
            // Health data
            let hkHRV: Double?
            let hkRestingHR: Double?
            let hkSleepHours: Double?
            let hkWorkoutMinutes: Double?
            let hkCycleDay: Int?
            let hkFlowLevel: String?
            // Location data (simplified)
            let locationLocality: String?
            let locationArea: String?
        }

        struct SymptomTypeBackup: Codable {
            let id: UUID
            let name: String
            let color: String
            let iconName: String
            let category: String?
            let isDefault: Bool
            let isStarred: Bool
            let starOrder: Int16
        }

        struct ActivityBackup: Codable {
            let id: UUID
            let createdAt: Date
            let backdatedAt: Date?
            let name: String
            let note: String?
            let physicalExertion: Int16
            let cognitiveExertion: Int16
            let emotionalLoad: Int16
            let durationMinutes: Int?
            let calendarEventID: String?
        }

        struct ManualCycleEntryBackup: Codable {
            let id: UUID
            let date: Date
            let flowLevel: String
        }

        struct ReminderBackup: Codable {
            let id: UUID
            let hour: Int16
            let minute: Int16
            let repeatsOn: [String]
            let isEnabled: Bool
        }

        struct SleepEventBackup: Codable {
            let id: UUID
            let createdAt: Date
            let backdatedAt: Date?
            let bedTime: Date
            let wakeTime: Date
            let quality: Int16
            let note: String?
            let hkSleepHours: Double?
            let hkHRV: Double?
            let hkRestingHR: Double?
            let source: String?
            let healthKitUUID: String?
            let symptomTypeIDs: [UUID]
        }

        struct MealEventBackup: Codable {
            let id: UUID
            let createdAt: Date
            let backdatedAt: Date?
            let mealType: String
            let mealDescription: String
            let note: String?
            let physicalExertion: Int16?
            let cognitiveExertion: Int16?
            let emotionalLoad: Int16?
        }

        struct DayReflectionBackup: Codable {
            let id: UUID
            let date: Date
            let bodyToMood: Int16?
            let mindToBody: Int16?
            let selfCareSpace: Int16?
            let loadMultiplier: Double?
            let notes: String?
            let createdAt: Date
            let updatedAt: Date
        }

        struct ManualCyclePreferences: Codable {
            let isEnabled: Bool
            let cycleDay: Int?
            let cycleDaySetDate: Date?
        }
    }

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: - Backup

    func createBackup(password: String) async throws -> URL {
        let backupData = try await fetchBackupData()
        let jsonData = try JSONEncoder().encode(backupData)

        // Encrypt the data
        let encryptedData = try encrypt(data: jsonData, password: password)

        // Save to file
        let timestamp = DateUtility.backupTimestamp(for: DateUtility.now())
        let filename = "Murmur_Backup_\(timestamp).murmurbackup"

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
        try encryptedData.write(to: tempURL)

        return tempURL
    }

    private func fetchBackupData() async throws -> BackupData {
        let context = stack.container.viewContext

        // Fetch all entries
        let entryRequest = SymptomEntry.fetchRequest()
        entryRequest.relationshipKeyPathsForPrefetching = ["symptomType"]
        entryRequest.fetchBatchSize = 100
        let entries = try context.fetch(entryRequest)

        // Fetch all symptom types
        let typeRequest = SymptomType.fetchRequest()
        let types = try context.fetch(typeRequest)

        let entryBackups = entries.compactMap { entry -> BackupData.EntryBackup? in
            // Use safe accessors
            guard let symptomTypeID = entry.symptomType?.safeId else {
                return nil
            }

            return BackupData.EntryBackup(
                id: entry.safeId,
                createdAt: entry.safeCreatedAt,
                backdatedAt: entry.backdatedAt,
                severity: entry.severity,
                note: entry.note,
                symptomTypeID: symptomTypeID,
                hkHRV: entry.hkHRV?.doubleValue,
                hkRestingHR: entry.hkRestingHR?.doubleValue,
                hkSleepHours: entry.hkSleepHours?.doubleValue,
                hkWorkoutMinutes: entry.hkWorkoutMinutes?.doubleValue,
                hkCycleDay: entry.hkCycleDay?.intValue,
                hkFlowLevel: entry.hkFlowLevel,
                locationLocality: entry.locationPlacemark?.locality,
                locationArea: entry.locationPlacemark?.administrativeArea
            )
        }

        let typeBackups = types.map { type -> BackupData.SymptomTypeBackup in
            // Use safe accessors
            return BackupData.SymptomTypeBackup(
                id: type.safeId,
                name: type.safeName,
                color: type.safeColor,
                iconName: type.safeIconName,
                category: type.category,
                isDefault: type.isDefault,
                isStarred: type.isStarred,
                starOrder: type.starOrder
            )
        }

        let activityRequest = ActivityEvent.fetchRequest()
        activityRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \ActivityEvent.createdAt, ascending: false)
        ]
        activityRequest.fetchBatchSize = 100
        let activities = try context.fetch(activityRequest)

        let activityBackups = activities.compactMap { activity -> BackupData.ActivityBackup? in
            guard let id = activity.id, let createdAt = activity.createdAt, let name = activity.name else {
                return nil
            }
            return BackupData.ActivityBackup(
                id: id,
                createdAt: createdAt,
                backdatedAt: activity.backdatedAt,
                name: name,
                note: activity.note,
                physicalExertion: activity.physicalExertion,
                cognitiveExertion: activity.cognitiveExertion,
                emotionalLoad: activity.emotionalLoad,
                durationMinutes: activity.durationMinutes?.intValue,
                calendarEventID: activity.calendarEventID
            )
        }

        let manualCycleEntries = try ManualCycleEntry.fetchAll(in: context)
        let manualCycleBackups = manualCycleEntries.map { entry in
            BackupData.ManualCycleEntryBackup(
                id: entry.id,
                date: entry.date,
                flowLevel: entry.flowLevel
            )
        }

        let reminderRequest = Reminder.fetchRequest()
        reminderRequest.sortDescriptors = [
            NSSortDescriptor(key: "hour", ascending: true),
            NSSortDescriptor(key: "minute", ascending: true)
        ]
        let reminders = try context.fetch(reminderRequest)
        let reminderBackups = reminders.compactMap { reminder -> BackupData.ReminderBackup? in
            guard let id = reminder.id else { return nil }
            let repeats = (reminder.repeatsOn as? [String]) ?? []
            return BackupData.ReminderBackup(
                id: id,
                hour: reminder.hour,
                minute: reminder.minute,
                repeatsOn: repeats,
                isEnabled: reminder.isEnabled
            )
        }

        let manualCyclePreferences = BackupData.ManualCyclePreferences(
            isEnabled: UserDefaults.standard.bool(forKey: UserDefaultsKeys.manualCycleTrackingEnabled),
            cycleDay: UserDefaults.standard.object(forKey: UserDefaultsKeys.currentCycleDay) as? Int,
            cycleDaySetDate: UserDefaults.standard.object(forKey: UserDefaultsKeys.cycleDaySetDate) as? Date
        )

        // Fetch sleep events (added in v2)
        let sleepRequest = SleepEvent.fetchRequest()
        sleepRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SleepEvent.createdAt, ascending: false)
        ]
        sleepRequest.fetchBatchSize = 100
        let sleepEvents = try context.fetch(sleepRequest)

        let sleepBackups = sleepEvents.compactMap { sleep -> BackupData.SleepEventBackup? in
            guard let id = sleep.id, let createdAt = sleep.createdAt,
                  let bedTime = sleep.bedTime, let wakeTime = sleep.wakeTime else {
                return nil
            }
            let symptomIDs = (sleep.symptoms as? Set<SymptomType>)?.compactMap { $0.id } ?? []
            return BackupData.SleepEventBackup(
                id: id,
                createdAt: createdAt,
                backdatedAt: sleep.backdatedAt,
                bedTime: bedTime,
                wakeTime: wakeTime,
                quality: sleep.quality,
                note: sleep.note,
                hkSleepHours: sleep.hkSleepHours?.doubleValue,
                hkHRV: sleep.hkHRV?.doubleValue,
                hkRestingHR: sleep.hkRestingHR?.doubleValue,
                source: sleep.source,
                healthKitUUID: sleep.healthKitUUID,
                symptomTypeIDs: symptomIDs
            )
        }

        // Fetch meal events (added in v2)
        let mealRequest = MealEvent.fetchRequest()
        mealRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \MealEvent.createdAt, ascending: false)
        ]
        mealRequest.fetchBatchSize = 100
        let mealEvents = try context.fetch(mealRequest)

        let mealBackups = mealEvents.compactMap { meal -> BackupData.MealEventBackup? in
            guard let id = meal.id, let createdAt = meal.createdAt,
                  let mealType = meal.mealType, let mealDescription = meal.mealDescription else {
                return nil
            }
            return BackupData.MealEventBackup(
                id: id,
                createdAt: createdAt,
                backdatedAt: meal.backdatedAt,
                mealType: mealType,
                mealDescription: mealDescription,
                note: meal.note,
                physicalExertion: meal.physicalExertion?.int16Value,
                cognitiveExertion: meal.cognitiveExertion?.int16Value,
                emotionalLoad: meal.emotionalLoad?.int16Value
            )
        }

        // Fetch day reflections (added in v2)
        let reflectionRequest = DayReflection.fetchRequest()
        reflectionRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \DayReflection.date, ascending: false)
        ]
        reflectionRequest.fetchBatchSize = 100
        let dayReflections = try context.fetch(reflectionRequest)

        let reflectionBackups = dayReflections.compactMap { reflection -> BackupData.DayReflectionBackup? in
            guard let id = reflection.id, let date = reflection.date,
                  let createdAt = reflection.createdAt, let updatedAt = reflection.updatedAt else {
                return nil
            }
            return BackupData.DayReflectionBackup(
                id: id,
                date: date,
                bodyToMood: reflection.bodyToMood?.int16Value,
                mindToBody: reflection.mindToBody?.int16Value,
                selfCareSpace: reflection.selfCareSpace?.int16Value,
                loadMultiplier: reflection.loadMultiplier?.doubleValue,
                notes: reflection.notes,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }

        return BackupData(
            createdAt: DateUtility.now(),
            entries: entryBackups,
            symptomTypes: typeBackups,
            activities: activityBackups,
            manualCycleEntries: manualCycleBackups,
            reminders: reminderBackups,
            manualCyclePreferences: manualCyclePreferences,
            sleepEvents: sleepBackups,
            mealEvents: mealBackups,
            dayReflections: reflectionBackups
        )
    }

    // MARK: - Backup Metadata

    struct BackupMetadata {
        let createdAt: Date
        let version: Int
        let entryCount: Int
        let symptomTypeCount: Int
        let activityCount: Int
        let manualCycleEntryCount: Int
        let reminderCount: Int
        // Added in v2
        let sleepEventCount: Int
        let mealEventCount: Int
        let dayReflectionCount: Int

        var formattedCreatedAt: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: createdAt)
        }

        /// Indicates if this backup was made with an older format that may be missing data
        var isLegacyBackup: Bool {
            version < DataBackupService.currentBackupVersion
        }

        var summary: String {
            var parts: [String] = []
            if entryCount > 0 {
                parts.append("\(entryCount) symptom \(entryCount == 1 ? "entry" : "entries")")
            }
            if symptomTypeCount > 0 {
                parts.append("\(symptomTypeCount) symptom \(symptomTypeCount == 1 ? "type" : "types")")
            }
            if activityCount > 0 {
                parts.append("\(activityCount) \(activityCount == 1 ? "activity" : "activities")")
            }
            if manualCycleEntryCount > 0 {
                parts.append("\(manualCycleEntryCount) cycle \(manualCycleEntryCount == 1 ? "entry" : "entries")")
            }
            if reminderCount > 0 {
                parts.append("\(reminderCount) \(reminderCount == 1 ? "reminder" : "reminders")")
            }
            if sleepEventCount > 0 {
                parts.append("\(sleepEventCount) sleep \(sleepEventCount == 1 ? "event" : "events")")
            }
            if mealEventCount > 0 {
                parts.append("\(mealEventCount) \(mealEventCount == 1 ? "meal" : "meals")")
            }
            if dayReflectionCount > 0 {
                parts.append("\(dayReflectionCount) \(dayReflectionCount == 1 ? "reflection" : "reflections")")
            }
            return parts.isEmpty ? "No data" : parts.joined(separator: ", ")
        }
    }

    func readBackupMetadata(from url: URL, password: String) async throws -> BackupMetadata {
        let encryptedData = try Data(contentsOf: url)

        // Decrypt the data
        let jsonData = try decrypt(data: encryptedData, password: password)

        // Decode backup
        let backupData = try JSONDecoder().decode(BackupData.self, from: jsonData)

        return BackupMetadata(
            createdAt: backupData.createdAt,
            version: backupData.version,
            entryCount: backupData.entries.count,
            symptomTypeCount: backupData.symptomTypes.count,
            activityCount: backupData.activities.count,
            manualCycleEntryCount: backupData.manualCycleEntries.count,
            reminderCount: backupData.reminders.count,
            sleepEventCount: backupData.sleepEvents?.count ?? 0,
            mealEventCount: backupData.mealEvents?.count ?? 0,
            dayReflectionCount: backupData.dayReflections?.count ?? 0
        )
    }

    // MARK: - Restore

    func restoreBackup(from url: URL, password: String) async throws {
        let encryptedData = try Data(contentsOf: url)

        // Decrypt the data
        let jsonData = try decrypt(data: encryptedData, password: password)

        // Decode backup
        let backupData = try JSONDecoder().decode(BackupData.self, from: jsonData)

        // Restore to Core Data
        try await restoreToDatabase(backupData: backupData)
    }

    private func restoreToDatabase(backupData: BackupData) async throws {
        let context = stack.newBackgroundContext()
        let viewContext = stack.container.viewContext

        let enabledReminderIDs = try await context.perform {
            // Delete all existing data with proper merge to view context
            func deleteAll(entityName: String) throws -> [NSManagedObjectID] {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let delete = NSBatchDeleteRequest(fetchRequest: request)
                delete.resultType = .resultTypeObjectIDs
                let result = try context.execute(delete) as? NSBatchDeleteResult
                return (result?.result as? [NSManagedObjectID]) ?? []
            }

            let deletedObjectIDs: [NSManagedObjectID] = try [
                deleteAll(entityName: "SymptomEntry"),
                deleteAll(entityName: "SymptomType"),
                deleteAll(entityName: "ActivityEvent"),
                deleteAll(entityName: "ManualCycleEntry"),
                deleteAll(entityName: "Reminder"),
                deleteAll(entityName: "SleepEvent"),
                deleteAll(entityName: "MealEvent"),
                deleteAll(entityName: "DayReflection")
            ].flatMap { $0 }

            // Merge the deletions into the view context
            let changes = [NSDeletedObjectsKey: deletedObjectIDs]
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: changes,
                into: [viewContext]
            )

            // Create symptom types
            var typeMap: [UUID: SymptomType] = [:]
            for typeBackup in backupData.symptomTypes {
                let type = SymptomType(context: context)
                type.id = typeBackup.id
                type.name = typeBackup.name
                type.color = typeBackup.color
                type.iconName = typeBackup.iconName
                type.category = typeBackup.category
                type.isDefault = typeBackup.isDefault
                type.isStarred = typeBackup.isStarred
                type.starOrder = typeBackup.starOrder
                typeMap[typeBackup.id] = type
            }

            // Create entries
            for entryBackup in backupData.entries {
                guard let symptomType = typeMap[entryBackup.symptomTypeID] else {
                    continue
                }

                let entry = SymptomEntry(context: context)
                entry.id = entryBackup.id
                entry.createdAt = entryBackup.createdAt
                entry.backdatedAt = entryBackup.backdatedAt
                entry.severity = entryBackup.severity
                entry.note = entryBackup.note
                entry.symptomType = symptomType
                entry.hkHRV = entryBackup.hkHRV.map { NSNumber(value: $0) }
                entry.hkRestingHR = entryBackup.hkRestingHR.map { NSNumber(value: $0) }
                entry.hkSleepHours = entryBackup.hkSleepHours.map { NSNumber(value: $0) }
                entry.hkWorkoutMinutes = entryBackup.hkWorkoutMinutes.map { NSNumber(value: $0) }
                entry.hkCycleDay = entryBackup.hkCycleDay.map { NSNumber(value: $0) }
                entry.hkFlowLevel = entryBackup.hkFlowLevel
                // Note: Location placemark restoration would need CLPlacemark reconstruction
            }

            for activityBackup in backupData.activities {
                let activity = ActivityEvent(context: context)
                activity.id = activityBackup.id
                activity.createdAt = activityBackup.createdAt
                activity.backdatedAt = activityBackup.backdatedAt
                activity.name = activityBackup.name
                activity.note = activityBackup.note
                activity.physicalExertion = activityBackup.physicalExertion
                activity.cognitiveExertion = activityBackup.cognitiveExertion
                activity.emotionalLoad = activityBackup.emotionalLoad
                if let duration = activityBackup.durationMinutes {
                    activity.durationMinutes = NSNumber(value: duration)
                } else {
                    activity.durationMinutes = nil
                }
                activity.calendarEventID = activityBackup.calendarEventID
            }

            for cycleBackup in backupData.manualCycleEntries {
                let cycleEntry = ManualCycleEntry(context: context)
                cycleEntry.id = cycleBackup.id
                cycleEntry.date = cycleBackup.date
                cycleEntry.flowLevel = cycleBackup.flowLevel
            }

            var ids: [UUID] = []
            for reminderBackup in backupData.reminders {
                let reminder = Reminder(context: context)
                reminder.id = reminderBackup.id
                reminder.hour = reminderBackup.hour
                reminder.minute = reminderBackup.minute
                reminder.repeatsOn = reminderBackup.repeatsOn as NSArray
                reminder.isEnabled = reminderBackup.isEnabled
                if reminderBackup.isEnabled {
                    ids.append(reminderBackup.id)
                }
            }

            // Restore sleep events (v2+)
            if let sleepBackups = backupData.sleepEvents {
                for sleepBackup in sleepBackups {
                    let sleep = SleepEvent(context: context)
                    sleep.id = sleepBackup.id
                    sleep.createdAt = sleepBackup.createdAt
                    sleep.backdatedAt = sleepBackup.backdatedAt
                    sleep.bedTime = sleepBackup.bedTime
                    sleep.wakeTime = sleepBackup.wakeTime
                    sleep.quality = sleepBackup.quality
                    sleep.note = sleepBackup.note
                    sleep.hkSleepHours = sleepBackup.hkSleepHours.map { NSNumber(value: $0) }
                    sleep.hkHRV = sleepBackup.hkHRV.map { NSNumber(value: $0) }
                    sleep.hkRestingHR = sleepBackup.hkRestingHR.map { NSNumber(value: $0) }
                    sleep.source = sleepBackup.source
                    sleep.healthKitUUID = sleepBackup.healthKitUUID
                    // Restore symptom type relationships
                    let symptoms = sleepBackup.symptomTypeIDs.compactMap { typeMap[$0] }
                    sleep.symptoms = NSSet(array: symptoms)
                }
            }

            // Restore meal events (v2+)
            if let mealBackups = backupData.mealEvents {
                for mealBackup in mealBackups {
                    let meal = MealEvent(context: context)
                    meal.id = mealBackup.id
                    meal.createdAt = mealBackup.createdAt
                    meal.backdatedAt = mealBackup.backdatedAt
                    meal.mealType = mealBackup.mealType
                    meal.mealDescription = mealBackup.mealDescription
                    meal.note = mealBackup.note
                    meal.physicalExertion = mealBackup.physicalExertion.map { NSNumber(value: $0) }
                    meal.cognitiveExertion = mealBackup.cognitiveExertion.map { NSNumber(value: $0) }
                    meal.emotionalLoad = mealBackup.emotionalLoad.map { NSNumber(value: $0) }
                }
            }

            // Restore day reflections (v2+)
            if let reflectionBackups = backupData.dayReflections {
                for reflectionBackup in reflectionBackups {
                    let reflection = DayReflection(context: context)
                    reflection.id = reflectionBackup.id
                    reflection.date = reflectionBackup.date
                    reflection.bodyToMood = reflectionBackup.bodyToMood.map { NSNumber(value: $0) }
                    reflection.mindToBody = reflectionBackup.mindToBody.map { NSNumber(value: $0) }
                    reflection.selfCareSpace = reflectionBackup.selfCareSpace.map { NSNumber(value: $0) }
                    reflection.loadMultiplier = reflectionBackup.loadMultiplier.map { NSNumber(value: $0) }
                    reflection.notes = reflectionBackup.notes
                    reflection.createdAt = reflectionBackup.createdAt
                    reflection.updatedAt = reflectionBackup.updatedAt
                }
            }

            try context.save()

            // Restore manual cycle preferences
            UserDefaults.standard.set(backupData.manualCyclePreferences.isEnabled, forKey: UserDefaultsKeys.manualCycleTrackingEnabled)
            if let cycleDay = backupData.manualCyclePreferences.cycleDay {
                UserDefaults.standard.set(cycleDay, forKey: UserDefaultsKeys.currentCycleDay)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.currentCycleDay)
            }
            if let setDate = backupData.manualCyclePreferences.cycleDaySetDate {
                UserDefaults.standard.set(setDate, forKey: UserDefaultsKeys.cycleDaySetDate)
            } else {
                UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.cycleDaySetDate)
            }

            return ids
        }

        // Refresh view context to trigger UI updates
        await MainActor.run {
            viewContext.refreshAllObjects()
        }

        if !enabledReminderIDs.isEmpty {
            let viewContext = stack.container.viewContext
            Task { @MainActor in
                do {
                    try await NotificationScheduler.requestAuthorization()
                } catch {
                    // Ignore authorization failures during restore; user can re-enable manually later
                }

                for id in enabledReminderIDs {
                    let request: NSFetchRequest<Reminder> = Reminder.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    request.fetchLimit = 1
                    if let reminder = try? viewContext.fetch(request).first {
                        try? await NotificationScheduler.schedule(reminder: reminder)
                    }
                }
            }
        }
    }

    // MARK: - Encryption

    private func encrypt(data: Data, password: String) throws -> Data {
        // Derive key from password using PBKDF2
        guard let passwordData = password.data(using: .utf8) else {
            throw BackupError.encryptionFailed
        }

        let salt = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let key = try deriveKey(from: passwordData, salt: salt)

        // Encrypt using AES-GCM
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)

        guard let combined = sealedBox.combined else {
            throw BackupError.encryptionFailed
        }

        // Combine salt + encrypted data
        var result = Data()
        result.append(salt)
        result.append(combined)

        return result
    }

    private func decrypt(data: Data, password: String) throws -> Data {
        guard data.count > 32 else {
            throw BackupError.invalidData
        }

        // Extract salt and encrypted data
        let salt = data.prefix(32)
        let encryptedData = data.suffix(from: 32)

        // Derive key
        guard let passwordData = password.data(using: .utf8) else {
            throw BackupError.decryptionFailed
        }

        let key = try deriveKey(from: passwordData, salt: salt)

        // Decrypt
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            throw BackupError.invalidPassword
        }
    }

    private func deriveKey(from password: Data, salt: Data) throws -> SymmetricKey {
        let iterations = 100_000
        let keyLength = 32

        var derivedKeyData = Data(count: keyLength)
        let result = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw BackupError.encryptionFailed
        }

        return SymmetricKey(data: derivedKeyData)
    }
}

// Required for PBKDF2
import CommonCrypto
