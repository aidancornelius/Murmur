// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DayReflectionSection.swift
// Created by Aidan Cornelius-Bell on 04/12/2025.
// Section for viewing and editing daily felt-load reflections.
//
import CoreData
import SwiftUI

/// Section content for daily mental health reflection
/// Includes body-to-mood, mind-to-body, self-care ratings, load adjustment, and notes
struct DayReflectionSection: View {
    let date: Date
    let calculatedLoad: Double?
    var onReflectionChanged: ((DayReflection?) -> Void)?
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appearanceManager: AppearanceManager

    // Local state for editing
    @State private var bodyToMood: Int?
    @State private var mindToBody: Int?
    @State private var selfCareSpace: Int?
    @State private var loadMultiplier: Double?
    @State private var notes: String = ""
    @State private var reflection: DayReflection?
    @State private var saveWorkItem: DispatchWorkItem?

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    private var reflectionTint: Color {
        palette.reflectionColor
    }

    var body: some View {
        VStack(spacing: 20) {
            // The three reflection dimensions
            ReflectionRingSelector(
                label: "Body shaping mood",
                lowLabel: "Not at all",
                highLabel: "Very much",
                value: $bodyToMood,
                tint: reflectionTint
            )
            .onChange(of: bodyToMood) { _, _ in debouncedSave() }

            ReflectionRingSelector(
                label: "Mind showing up in body",
                lowLabel: "Not at all",
                highLabel: "Very much",
                value: $mindToBody,
                tint: reflectionTint
            )
            .onChange(of: mindToBody) { _, _ in debouncedSave() }

            ReflectionRingSelector(
                label: "Space given for self",
                lowLabel: "Little",
                highLabel: "Plenty",
                value: $selfCareSpace,
                tint: reflectionTint
            )
            .onChange(of: selfCareSpace) { _, _ in debouncedSave() }

            // Load adjuster (only if there's a calculated load)
            if let calc = calculatedLoad, calc > 0 {
                Divider()

                FeltLoadAdjuster(
                    calculatedLoad: calc,
                    multiplier: $loadMultiplier,
                    tint: reflectionTint
                )
                .onChange(of: loadMultiplier) { _, _ in debouncedSave() }
            }

            // Notes
            Divider()

            ReflectionNotesField(
                text: $notes,
                tint: reflectionTint,
                onCommit: { save() }
            )
        }
        .onAppear { loadExisting() }
    }

    private func loadExisting() {
        do {
            reflection = try DayReflection.fetch(for: date, in: context)
            guard let r = reflection else { return }

            bodyToMood = r.bodyToMoodValue
            mindToBody = r.mindToBodyValue
            selfCareSpace = r.selfCareSpaceValue
            loadMultiplier = r.loadMultiplierValue
            notes = r.notes ?? ""
        } catch {
            print("Failed to load reflection: \(error)")
        }
    }

    private func debouncedSave() {
        // Cancel any pending save
        saveWorkItem?.cancel()

        // Schedule a new save after a short delay
        let workItem = DispatchWorkItem { [self] in
            save()
        }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func save() {
        do {
            let r = try DayReflection.fetchOrCreate(for: date, in: context)

            r.bodyToMoodValue = bodyToMood
            r.mindToBodyValue = mindToBody
            r.selfCareSpaceValue = selfCareSpace
            r.loadMultiplierValue = loadMultiplier
            r.notes = notes.isEmpty ? nil : notes
            r.updatedAt = DateUtility.now()

            try context.save()
            reflection = r
            onReflectionChanged?(r)
        } catch {
            print("Failed to save reflection: \(error)")
            context.rollback()
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    DayReflectionSection(
                        date: Date(),
                        calculatedLoad: 45
                    )

                    DayReflectionSection(
                        date: Date(),
                        calculatedLoad: nil
                    )
                }
                .padding()
            }
            .environmentObject(AppearanceManager.shared)
        }
    }

    return PreviewWrapper()
}
