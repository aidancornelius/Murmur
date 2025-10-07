//
//  SymptomEntryService.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import CoreData
import CoreLocation
import Foundation

/// Service for creating and saving symptom entries with HealthKit and location enrichment
@MainActor
struct SymptomEntryService {

    // MARK: - Errors

    enum ServiceError: LocalizedError {
        case noSymptomsSelected
        case saveTaskCancelled
        case contextSaveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noSymptomsSelected:
                return "Select at least one symptom."
            case .saveTaskCancelled:
                return "Save was cancelled."
            case .contextSaveFailed(let error):
                return "Failed to save: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Entry Creation

    /// Create and save symptom entries with HealthKit and location enrichment
    ///
    /// - Parameters:
    ///   - selectedSymptoms: Array of selected symptoms with severity
    ///   - note: Optional note text
    ///   - timestamp: Backdated timestamp for the entries
    ///   - includeLocation: Whether to include location data
    ///   - healthKit: HealthKit assistant for fetching metrics
    ///   - location: Location assistant for fetching placemark
    ///   - context: Core Data managed object context
    /// - Returns: Array of created symptom entries
    /// - Throws: ServiceError if validation fails or save fails
    static func createEntries(
        selectedSymptoms: [SelectedSymptom],
        note: String,
        timestamp: Date,
        includeLocation: Bool,
        healthKit: HealthKitAssistantProtocol,
        location: LocationAssistantProtocol,
        context: NSManagedObjectContext
    ) async throws -> [SymptomEntry] {
        // Validate input
        guard !selectedSymptoms.isEmpty else {
            throw ServiceError.noSymptomsSelected
        }

        // Check for cancellation before starting
        try Task.checkCancellation()

        // Fetch location data first if requested
        let placemark = includeLocation ? await location.currentPlacemark() : nil
        try Task.checkCancellation()

        // Fetch all HealthKit data in parallel
        let hrv = await healthKit.recentHRV()
        try Task.checkCancellation()

        let rhr = await healthKit.recentRestingHR()
        try Task.checkCancellation()

        let sleep = await healthKit.recentSleepHours()
        try Task.checkCancellation()

        let workout = await healthKit.recentWorkoutMinutes()
        try Task.checkCancellation()

        let cycleDay = await healthKit.recentCycleDay()
        try Task.checkCancellation()

        let flowLevel = await healthKit.recentFlowLevel()
        try Task.checkCancellation()

        // Create entries
        var createdEntries: [SymptomEntry] = []

        for selectedSymptom in selectedSymptoms {
            try Task.checkCancellation()

            let entry = SymptomEntry(context: context)
            entry.id = UUID()
            entry.createdAt = Date()
            entry.backdatedAt = timestamp
            entry.severity = Int16(selectedSymptom.severity)

            // Trim and set note (nil if empty)
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.note = trimmedNote.isEmpty ? nil : trimmedNote

            // Set symptom type relationship
            entry.symptomType = selectedSymptom.symptomType

            // Apply shared HealthKit data
            if let placemark {
                entry.locationPlacemark = placemark
            }
            if let hrv {
                entry.hkHRV = NSNumber(value: hrv)
            }
            if let rhr {
                entry.hkRestingHR = NSNumber(value: rhr)
            }
            if let sleep {
                entry.hkSleepHours = NSNumber(value: sleep)
            }
            if let workout {
                entry.hkWorkoutMinutes = NSNumber(value: workout)
            }
            if let cycleDay {
                entry.hkCycleDay = NSNumber(value: cycleDay)
            }
            if let flowLevel {
                entry.hkFlowLevel = flowLevel
            }

            createdEntries.append(entry)
        }

        // Check cancellation before saving
        try Task.checkCancellation()

        // Ensure all changes are registered
        context.processPendingChanges()

        // Save to persistent store
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            // Rollback on error
            context.rollback()
            throw ServiceError.contextSaveFailed(error)
        }

        return createdEntries
    }
}
