// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// SymptomEntryService.swift
// Created by Aidan Cornelius-Bell on 06/10/2025.
// Service for creating and managing symptom entries.
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

        // Determine if this is a backdated entry (more than 1 hour in the past)
        let targetDate = timestamp
        let hourAgo = DateUtility.now().addingTimeInterval(-3600)
        let isBackdated = targetDate < hourAgo

        // Fetch HealthKit data - use historical methods for backdated entries
        let hrv: Double?
        let rhr: Double?
        let sleep: Double?
        let workout: Double?
        let cycleDay: Int?
        let flowLevel: String?

        if isBackdated {
            // Use historical queries for the target date
            hrv = await healthKit.hrvForDate(targetDate)
            try Task.checkCancellation()

            rhr = await healthKit.restingHRForDate(targetDate)
            try Task.checkCancellation()

            sleep = await healthKit.sleepHoursForDate(targetDate)
            try Task.checkCancellation()

            workout = await healthKit.workoutMinutesForDate(targetDate)
            try Task.checkCancellation()

            cycleDay = await healthKit.cycleDayForDate(targetDate)
            try Task.checkCancellation()

            flowLevel = await healthKit.flowLevelForDate(targetDate)
            try Task.checkCancellation()
        } else {
            // Use recent queries for current entries
            hrv = await healthKit.recentHRV()
            try Task.checkCancellation()

            rhr = await healthKit.recentRestingHR()
            try Task.checkCancellation()

            sleep = await healthKit.recentSleepHours()
            try Task.checkCancellation()

            workout = await healthKit.recentWorkoutMinutes()
            try Task.checkCancellation()

            cycleDay = await healthKit.recentCycleDay()
            try Task.checkCancellation()

            flowLevel = await healthKit.recentFlowLevel()
            try Task.checkCancellation()
        }

        // Create entries
        var createdEntries: [SymptomEntry] = []

        for selectedSymptom in selectedSymptoms {
            try Task.checkCancellation()

            let entry = SymptomEntry(context: context)
            entry.id = UUID()
            entry.createdAt = DateUtility.now()
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
