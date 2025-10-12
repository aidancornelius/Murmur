//
//  SymptomHistoryView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import SwiftUI
import CoreData

struct SymptomHistoryView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var symptomCounts: [SymptomCount] = []
    @State private var selectedSymptom: SymptomCount?
    @State private var isLoading = true
    @State private var loadingMore = false
    @State private var detailEntries: [SymptomEntry] = []
    @State private var hasMoreEntries = true
    @State private var currentPage = 0
    private let pageSize = 20

    struct SymptomCount: Identifiable {
        var id: UUID { symptomType.safeId }
        let symptomType: SymptomType
        let count: Int
        let lastOccurrence: Date?
        let averageSeverity: Double  // Normalised (higher = worse)
        let rawAverageSeverity: Double  // Raw average for display (1-5 scale)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if symptomCounts.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        Text("All symptoms you've tracked, sorted by frequency")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(symptomCounts) { symptomCount in
                        SymptomCountRow(
                            symptomCount: symptomCount,
                            isSelected: selectedSymptom?.id == symptomCount.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedSymptom?.id == symptomCount.id {
                                        selectedSymptom = nil
                                        detailEntries = []
                                        currentPage = 0
                                        hasMoreEntries = true
                                    } else {
                                        selectedSymptom = symptomCount
                                        loadInitialEntries(for: symptomCount.symptomType)
                                    }
                                }
                            }
                        )

                        // Show details right after the selected symptom row
                        if selectedSymptom?.id == symptomCount.id {
                            if detailEntries.isEmpty && !loadingMore {
                                // Show loading state when first fetching
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .listRowBackground(Color.clear)
                            } else {
                                ForEach(detailEntries) { entry in
                                    SymptomOccurrenceRow(entry: entry)
                                        .listRowBackground(Color.gray.opacity(0.05))
                                }

                                if hasMoreEntries {
                                    HStack {
                                        Spacer()
                                        if loadingMore {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Button("Load more") {
                                                loadMoreEntries(for: symptomCount.symptomType)
                                            }
                                            .font(.footnote)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .listRowBackground(Color.clear)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .themedScrollBackground()
            }
        }
        .task {
            await loadSymptomCounts()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No symptoms tracked yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start logging symptoms to see your history")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func loadSymptomCounts() async {
        isLoading = true

        let ctx = context
        let counts: [SymptomCount] = await ctx.perform {
            let request = SymptomType.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \SymptomType.name, ascending: true)]

            guard let symptomTypes = try? ctx.fetch(request) else { return [] }

            return symptomTypes.compactMap { symptomType -> SymptomCount? in
                guard let entries = symptomType.entries as? Set<SymptomEntry>, !entries.isEmpty else { return nil }

                let sortedEntries = entries.sorted { entry1, entry2 in
                    let date1 = entry1.backdatedAt ?? entry1.createdAt ?? Date()
                    let date2 = entry2.backdatedAt ?? entry2.createdAt ?? Date()
                    return date1 > date2
                }

                // Calculate raw average (for display)
                let rawTotalSeverity = entries.reduce(0.0) { total, entry in
                    return total + Double(entry.severity)
                }
                let rawAverageSeverity = rawTotalSeverity / Double(entries.count)

                // Calculate normalized average (for sorting/calculations)
                let totalSeverity = entries.reduce(0.0) { total, entry in
                    return total + entry.normalisedSeverity
                }
                let averageSeverity = totalSeverity / Double(entries.count)

                return SymptomCount(
                    symptomType: symptomType,
                    count: entries.count,
                    lastOccurrence: sortedEntries.first?.backdatedAt ?? sortedEntries.first?.createdAt,
                    averageSeverity: averageSeverity,
                    rawAverageSeverity: rawAverageSeverity
                )
            }
            .sorted { $0.count > $1.count }
        }

        symptomCounts = counts
        isLoading = false
    }

    private func loadInitialEntries(for symptomType: SymptomType) {
        currentPage = 0
        hasMoreEntries = true
        detailEntries = []
        loadingMore = true  // Set loading state immediately
        loadMoreEntries(for: symptomType)
    }

    private func loadMoreEntries(for symptomType: SymptomType) {
        loadingMore = true
        let symptomTypeID = symptomType.objectID
        let ctx = context
        let page = currentPage
        let size = pageSize

        Task { @MainActor in
            let newEntries: [SymptomEntry] = await ctx.perform {
                guard let symptomType = try? ctx.existingObject(with: symptomTypeID) as? SymptomType else {
                    return []
                }
                let request = SymptomEntry.fetchRequest()
                request.predicate = NSPredicate(format: "symptomType == %@", symptomType)
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \SymptomEntry.backdatedAt, ascending: false),
                    NSSortDescriptor(keyPath: \SymptomEntry.createdAt, ascending: false)
                ]
                request.fetchLimit = size
                request.fetchOffset = page * size

                return (try? ctx.fetch(request)) ?? []
            }

            await MainActor.run {
                detailEntries.append(contentsOf: newEntries)
                hasMoreEntries = newEntries.count == pageSize
                currentPage += 1
                loadingMore = false
            }
        }
    }
}

private struct SymptomCountRow: View {
    let symptomCount: SymptomHistoryView.SymptomCount
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color(hex: symptomCount.symptomType.safeColor))
                        .frame(width: 12, height: 12)
                    Text(symptomCount.symptomType.safeName)
                        .font(.headline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(symptomCount.count)")
                            .font(.title3.bold())
                        Text(symptomCount.count == 1 ? "time" : "times")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avg \(symptomCount.symptomType.isPositive ? "level" : "severity")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f", symptomCount.rawAverageSeverity))
                            .font(.subheadline.weight(.medium))
                    }

                    if let lastOccurrence = symptomCount.lastOccurrence {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Last occurrence")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(relativeTime(from: lastOccurrence))
                                .font(.caption.weight(.medium))
                        }
                    }
                }

                if isSelected {
                    HStack {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Tap again to hide details")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct SymptomOccurrenceRow: View {
    let entry: SymptomEntry
    @State private var selectedDay: SelectedDay?

    private struct SelectedDay: Identifiable {
        let id = UUID()
        let date: Date
    }

    var body: some View {
        Button {
            selectedDay = SelectedDay(date: entry.backdatedAt ?? entry.createdAt ?? Date())
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateLabel)
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 8) {
                        Text(timeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(severityLabel): \(entry.severity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(item: $selectedDay) { selectedDay in
            NavigationView {
                DayDetailView(date: selectedDay.date)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var dateLabel: String {
        let date = entry.backdatedAt ?? entry.createdAt ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private var timeLabel: String {
        let date = entry.backdatedAt ?? entry.createdAt ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var severityLabel: String {
        entry.symptomType?.isPositive == true ? "Level" : "Severity"
    }
}