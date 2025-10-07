//
//  CalendarHeatMapView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import SwiftUI
import CoreData

struct CalendarHeatMapView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentMonth = Date()
    @State private var dayData: [Date: DayIntensity] = [:]
    @State private var selectedDate: SelectedDay?
    @State private var isLoading = true

    private struct SelectedDay: Identifiable {
        let id = UUID()
        let date: Date
    }

    struct DayIntensity {
        let date: Date
        let averageSeverity: Double  // Normalised for calculations (higher = worse)
        let rawAverageSeverity: Double  // Raw average for display (1-5 scale)
        let entryCount: Int
        let hasData: Bool
    }

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            // Month navigation
            monthNavigationHeader
                .padding(.horizontal)
                .padding(.vertical, 12)

            // Weekday headers
            weekdayHeaders
                .padding(.horizontal)
                .padding(.bottom, 8)

            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else {
                    // Calendar grid
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(Array(calendarDays.enumerated()), id: \.offset) { index, date in
                            if let date = date {
                                DayCell(
                                    date: date,
                                    intensity: dayData[calendar.startOfDay(for: date)],
                                    isToday: calendar.isDateInToday(date),
                                    onTap: {
                                        selectedDate = SelectedDay(date: date)
                                    }
                                )
                            } else {
                                Color.clear
                                    .frame(height: 44)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Legend
                    legend
                        .padding(.top, 20)
                        .padding(.horizontal)

                    // Summary stats
                    if !dayData.isEmpty {
                        summaryStats
                            .padding(.top, 20)
                            .padding(.horizontal)
                    }
                }
            }
            .themedScrollBackground()
        }
        .sheet(item: $selectedDate) { selectedDay in
            NavigationView {
                DayDetailView(date: selectedDay.date)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task(id: currentMonth) {
            await loadMonthData()
        }
    }

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                withAnimation {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            Text(monthYearString)
                .font(.headline)

            Spacer()

            Button {
                withAnimation {
                    let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    // Allow navigation if next month is not in the future
                    if nextMonth <= Date() {
                        currentMonth = nextMonth
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .disabled(isNextMonthInFuture)
        }
    }

    private var weekdayHeaders: some View {
        HStack(spacing: 2) {
            ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intensity legend")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(0..<6) { level in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorForLevel(Double(level)))
                            .frame(width: 30, height: 30)
                        Text(level == 0 ? "None" : "\(level)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var summaryStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Month summary")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Days tracked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(daysWithData)")
                        .font(.title3.bold())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Average intensity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", monthAverageIntensity))
                        .font(.title3.bold())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(totalEntries)")
                        .font(.title3.bold())
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    private var isNextMonthInFuture: Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else {
            return true
        }
        return nextMonth > Date()
    }

    private var calendarDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var days: [Date?] = []
        var date = firstWeek.start

        // Add empty cells for days before month starts
        while date < monthInterval.start {
            days.append(nil)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        // Add all days of the month
        while date < monthInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        // Fill remaining cells to complete the grid
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private var daysWithData: Int {
        dayData.filter { $0.value.hasData }.count
    }

    private var monthAverageIntensity: Double {
        let dataWithEntries = dayData.values.filter { $0.hasData }
        guard !dataWithEntries.isEmpty else { return 0 }
        let total = dataWithEntries.reduce(0) { $0 + $1.averageSeverity }
        return total / Double(dataWithEntries.count)
    }

    private var totalEntries: Int {
        dayData.values.reduce(0) { $0 + $1.entryCount }
    }

    private func loadMonthData() async {
        isLoading = true

        let data: [Date: DayIntensity] = await context.perform {
            guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return [:] }

            let request = SymptomEntry.fetchRequest()
            request.predicate = NSPredicate(
                format: "((backdatedAt >= %@ AND backdatedAt < %@) OR (backdatedAt == nil AND createdAt >= %@ AND createdAt < %@))",
                monthInterval.start as NSDate, monthInterval.end as NSDate,
                monthInterval.start as NSDate, monthInterval.end as NSDate
            )

            guard let entries = try? context.fetch(request) else { return [:] }

            // Group entries by day
            let groupedEntries = Dictionary(grouping: entries) { entry in
                calendar.startOfDay(for: entry.backdatedAt ?? entry.createdAt ?? Date())
            }

            // Calculate intensity for each day
            var dayIntensities: [Date: DayIntensity] = [:]
            for (date, dayEntries) in groupedEntries {
                // Calculate raw average (for display)
                let totalRawSeverity = dayEntries.reduce(0.0) { total, entry in
                    return total + Double(entry.severity)
                }
                let rawAverageSeverity = totalRawSeverity / Double(dayEntries.count)

                // Calculate normalized average (for color intensity)
                let totalSeverity = dayEntries.reduce(0.0) { total, entry in
                    return total + entry.normalisedSeverity
                }
                let averageSeverity = totalSeverity / Double(dayEntries.count)

                dayIntensities[date] = DayIntensity(
                    date: date,
                    averageSeverity: averageSeverity,
                    rawAverageSeverity: rawAverageSeverity,
                    entryCount: dayEntries.count,
                    hasData: true
                )
            }

            return dayIntensities
        }

        dayData = data
        isLoading = false
    }

    private func colorForLevel(_ level: Double) -> Color {
        switch level {
        case 0:
            return colorScheme == .dark ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1)
        case 0..<1:
            return Color.green.opacity(0.3)
        case 1..<2:
            return Color.yellow.opacity(0.4)
        case 2..<3:
            return Color.orange.opacity(0.5)
        case 3..<4:
            return Color.orange.opacity(0.7)
        case 4...5:
            return Color.red.opacity(0.8)
        default:
            return Color.gray.opacity(0.1)
        }
    }
}

private struct DayCell: View {
    let date: Date
    let intensity: CalendarHeatMapView.DayIntensity?
    let isToday: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(borderColor, lineWidth: isToday ? 2 : 0)
                    )

                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption.weight(isToday ? .bold : .regular))
                        .foregroundStyle(textColor)

                    if let intensity = intensity, intensity.entryCount > 0 {
                        Text("\(intensity.entryCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Tap to view details for this day")
    }

    private var backgroundColor: Color {
        guard let intensity = intensity else {
            return Color.gray.opacity(0.1)
        }
        return colorForIntensity(intensity.averageSeverity)
    }

    private var borderColor: Color {
        isToday ? Color.blue : Color.clear
    }

    private var textColor: Color {
        if let intensity = intensity, intensity.averageSeverity > 3 {
            return .white
        }
        return .primary
    }

    private func colorForIntensity(_ severity: Double) -> Color {
        switch severity {
        case 0..<1:
            return Color.green.opacity(0.3)
        case 1..<2:
            return Color.yellow.opacity(0.4)
        case 2..<3:
            return Color.orange.opacity(0.5)
        case 3..<4:
            return Color.orange.opacity(0.7)
        case 4...5:
            return Color.red.opacity(0.8)
        default:
            return Color.gray.opacity(0.1)
        }
    }

    private var accessibilityDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: date)

        if let intensity = intensity, intensity.hasData {
            let intensityLevel = Int(round(intensity.rawAverageSeverity))
            let descriptor = SeverityScale.descriptor(for: intensityLevel)
            return "\(dateString). \(intensity.entryCount) \(intensity.entryCount == 1 ? "entry" : "entries"). Average intensity: \(descriptor)"
        } else {
            return "\(dateString). No entries"
        }
    }
}