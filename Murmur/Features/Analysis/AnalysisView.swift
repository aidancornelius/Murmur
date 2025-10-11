//
//  AnalysisView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI
import CoreData

struct AnalysisView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var healthKit: HealthKitAssistant
    @State private var selectedTab = AnalysisTab.trends
    @State private var selectedPeriod = 30
    @State private var hasHealthData = false
    @State private var hasActivityData = false

    enum AnalysisTab {
        case trends
        case correlations
        case patterns
        case health
        case calendar
        case history
    }

    private var tabTitle: String {
        switch selectedTab {
        case .trends: return "Trends"
        case .correlations: return "Activities"
        case .patterns: return "Patterns"
        case .health: return "Health"
        case .calendar: return "Calendar"
        case .history: return "History"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if selectedTab != .calendar && selectedTab != .history {
                Picker("Period", selection: $selectedPeriod) {
                    Text("7 days").tag(7)
                        .accessibilityIdentifier(AccessibilityIdentifiers.timePeriod7Days)
                    Text("30 days").tag(30)
                        .accessibilityIdentifier(AccessibilityIdentifiers.timePeriod30Days)
                    Text("90 days").tag(90)
                        .accessibilityIdentifier(AccessibilityIdentifiers.timePeriod90Days)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityIdentifiers.timePeriodPicker)
                .padding(.horizontal)
                .padding(.bottom)
            }

            switch selectedTab {
            case .trends:
                TrendsAnalysisView(days: selectedPeriod)
            case .correlations:
                CorrelationsAnalysisView(days: selectedPeriod)
            case .patterns:
                PatternsAnalysisView(days: selectedPeriod)
            case .health:
                HealthAnalysisView(days: selectedPeriod)
            case .calendar:
                CalendarHeatMapView()
            case .history:
                SymptomHistoryView()
            }
        }
        .navigationTitle("Analysis")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        selectedTab = .trends
                    } label: {
                        Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.analysisTrendsButton)

                    Button {
                        selectedTab = .calendar
                    } label: {
                        Label("Calendar", systemImage: "calendar")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.analysisCalendarButton)

                    Button {
                        selectedTab = .history
                    } label: {
                        Label("History", systemImage: "list.bullet")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.analysisHistoryButton)

                    if hasActivityData {
                        Button {
                            selectedTab = .correlations
                        } label: {
                            Label("Activities", systemImage: "figure.walk")
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.analysisActivitiesButton)
                    }
                    Button {
                        selectedTab = .patterns
                    } label: {
                        Label("Patterns", systemImage: "clock")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.analysisPatternsButton)

                    if hasHealthData {
                        Button {
                            selectedTab = .health
                        } label: {
                            Label("Health", systemImage: "heart")
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.analysisHealthButton)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(tabTitle)
                            .font(.callout)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.analysisViewSelector)
            }
        }
        .task {
            await checkAvailableData()
        }
    }

    private func checkAvailableData() async {
        // Check for HealthKit data availability
        let healthAvailable = healthKit.isHealthDataAvailable
        let hasHealthData = await hasAnyHealthKitData()
        let hasHealth = healthAvailable && hasHealthData
        self.hasHealthData = hasHealth

        // Check for activity data
        let hasActivities = await hasAnyActivityData()
        hasActivityData = hasActivities

        // If current tab is now hidden, switch to trends
        if selectedTab == .health && !hasHealthData {
            selectedTab = .trends
        } else if selectedTab == .correlations && !hasActivityData {
            selectedTab = .trends
        }
    }

    private func hasAnyHealthKitData() async -> Bool {
        await context.perform {
            let request = SymptomEntry.fetchRequest()
            request.predicate = NSPredicate(
                format: "hkHRV != nil OR hkRestingHR != nil OR hkSleepHours != nil"
            )
            request.fetchLimit = 1
            return (try? context.fetch(request).first) != nil
        }
    }

    private func hasAnyActivityData() async -> Bool {
        await context.perform {
            let request = ActivityEvent.fetchRequest()
            request.fetchLimit = 1
            return (try? context.fetch(request).first) != nil
        }
    }
}

// MARK: - Trends analysis

private struct TrendsAnalysisView: View {
    let days: Int
    @State private var trends: [SymptomTrend] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if trends.isEmpty {
                emptyState(message: "No symptom data available for this period")
            } else {
                List {
                    Section {
                        Text("Shows how your symptoms may have changed over time")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(trends) { trend in
                        TrendRow(trend: trend)
                    }
                }
                .listStyle(.insetGrouped)
                .themedScrollBackground()
            }
        }
        .task(id: days) {
            await loadTrends()
        }
    }

    private func loadTrends() async {
        isLoading = true
        let bgContext = CoreDataStack.shared.newBackgroundContext()
        let trends = await bgContext.perform {
            AnalysisEngine.analyseSymptomTrends(in: bgContext, days: days)
        }
        self.trends = trends
        isLoading = false
    }

    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Start logging symptoms to see trends")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TrendRow: View {
    let trend: SymptomTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: trend.symptomTypeColor))
                    .frame(width: 12, height: 12)
                Text(trend.symptomTypeName)
                    .font(.headline)
                Spacer()
                trendIndicator
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Occurrences")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(trend.occurrences)")
                        .font(.title3.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(trend.isPositive ? "Average level" : "Average severity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", trend.rawAverageSeverity))
                        .font(.title3.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trend")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(trend.periodComparison)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(trendColor)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var trendIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: trendIcon)
            Text(trendText)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(trendColor)
    }

    private var trendIcon: String {
        switch trend.trend {
        case .increasing: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .decreasing: return "arrow.down.right"
        }
    }

    private var trendText: String {
        switch trend.trend {
        case .increasing: return "Improving"
        case .stable: return "Stable"
        case .decreasing: return "Worsening"
        }
    }

    private var trendColor: Color {
        switch trend.trend {
        case .increasing: return .green  // Improving is good
        case .stable: return .orange
        case .decreasing: return .red     // Worsening is bad
        }
    }
}

// MARK: - Correlations analysis

private struct CorrelationsAnalysisView: View {
    let days: Int
    @State private var correlations: [ActivityCorrelation] = []
    @State private var isLoading = true
    @State private var hasAnyActivities = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if !hasAnyActivities {
                emptyState(
                    icon: "calendar.badge.clock",
                    message: "No activities logged yet",
                    detail: "Start logging activities to see how they correlate with your symptoms"
                )
            } else if correlations.isEmpty {
                emptyState(
                    icon: "link.circle",
                    message: "Not enough data to identify activity correlations",
                    detail: "Keep logging activities and symptoms to discover patterns"
                )
            } else {
                List {
                    Section {
                        Text("Shows which activities may be associated with changes in your symptoms (24-hour window)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(correlations) { correlation in
                        CorrelationRow(correlation: correlation)
                    }
                }
                .listStyle(.insetGrouped)
                .themedScrollBackground()
            }
        }
        .task(id: days) {
            await loadCorrelations()
        }
    }

    private func loadCorrelations() async {
        isLoading = true

        let bgContext = CoreDataStack.shared.newBackgroundContext()

        // Check if we have any activities at all
        let hasActivities = await bgContext.perform {
            let request = ActivityEvent.fetchRequest()
            request.fetchLimit = 1
            return (try? bgContext.fetch(request).first) != nil
        }
        hasAnyActivities = hasActivities

        let correlations = await bgContext.perform {
            AnalysisEngine.analyseActivityCorrelations(in: bgContext, days: days)
        }
        self.correlations = correlations
        isLoading = false
    }

    private func emptyState(icon: String, message: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CorrelationRow: View {
    let correlation: ActivityCorrelation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.purple)
                Text(correlation.activityName)
                    .font(.headline)
                Spacer()
                correlationBadge
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Circle()
                    .fill(Color(hex: correlation.symptomTypeColor))
                    .frame(width: 10, height: 10)
                Text(correlation.symptomTypeName)
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("After activity:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f %@ (%d times)",
                        correlation.averageSeverityAfterActivity,
                        correlation.isPositive ? "level" : "severity",
                        correlation.occurrencesWithSymptom))
                        .font(.caption.weight(.medium))
                }

                HStack {
                    Text("Without activity:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f %@ (%d times)",
                        correlation.averageSeverityWithoutActivity,
                        correlation.isPositive ? "level" : "severity",
                        correlation.occurrencesWithoutSymptom))
                        .font(.caption.weight(.medium))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var correlationBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: correlationIcon)
            Text(correlationText)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(correlationColor, in: Capsule())
    }

    private var correlationIcon: String {
        switch correlation.correlationType {
        case .positive: return "exclamationmark.triangle.fill"
        case .negative: return "checkmark.circle.fill"
        case .neutral: return "minus.circle.fill"
        }
    }

    private var correlationText: String {
        switch correlation.correlationType {
        case .positive: return "May worsen"
        case .negative: return "May help"
        case .neutral: return "Neutral"
        }
    }

    private var correlationColor: Color {
        switch correlation.correlationType {
        case .positive: return .red
        case .negative: return .green
        case .neutral: return .gray
        }
    }
}

// MARK: - Time patterns analysis

private struct PatternsAnalysisView: View {
    let days: Int
    @State private var patterns: [TimePattern] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if patterns.isEmpty {
                emptyState(message: "Not enough data yet to identify time patterns, keep adding entries")
            } else {
                List {
                    Section {
                        Text("Shows when your symptoms are more likely to occur based on trends")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(patterns) { pattern in
                        PatternRow(pattern: pattern)
                    }
                }
                .listStyle(.insetGrouped)
                .themedScrollBackground()
            }
        }
        .task(id: days) {
            await loadPatterns()
        }
    }

    private func loadPatterns() async {
        isLoading = true
        let bgContext = CoreDataStack.shared.newBackgroundContext()
        let patterns = await bgContext.perform {
            AnalysisEngine.analyseTimePatterns(in: bgContext, days: days)
        }
        self.patterns = patterns
        isLoading = false
    }

    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Log more symptoms to discover when they typically occur")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PatternRow: View {
    let pattern: TimePattern

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: pattern.symptomTypeColor))
                    .frame(width: 12, height: 12)
                Text(pattern.symptomTypeName)
                    .font(.headline)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Peak time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatHour(pattern.peakHour))
                        .font(.subheadline.weight(.semibold))
                }

                if let peakDay = pattern.peakDayOfWeek {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Peak day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatDayOfWeek(peakDay))
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }

            // Hour distribution chart
            HourDistributionChart(occurrencesByHour: pattern.occurrencesByHour)
        }
        .padding(.vertical, 4)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        if let date = calendar.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }

    private func formatDayOfWeek(_ day: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        // Weekday 1 is Sunday
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = day
        if let date = calendar.date(from: components) {
            return formatter.string(from: date)
        }
        return "Day \(day)"
    }
}

private struct HourDistributionChart: View {
    let occurrencesByHour: [Int: Int]

    var body: some View {
        let maxCount = occurrencesByHour.values.max() ?? 1

        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<24, id: \.self) { hour in
                let count = occurrencesByHour[hour] ?? 0
                let height = CGFloat(count) / CGFloat(maxCount) * 40

                RoundedRectangle(cornerRadius: 2)
                    .fill(count > 0 ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
                    .frame(height: max(height, 2))
            }
        }
        .frame(height: 50)
    }
}

// MARK: - Health metrics analysis

private struct HealthAnalysisView: View {
    @EnvironmentObject private var healthKit: HealthKitAssistant
    let days: Int
    @State private var correlations: [PhysiologicalCorrelation] = []
    @State private var isLoading = true
    @State private var hasAnyHealthData = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if !healthKit.isHealthDataAvailable {
                emptyState(
                    icon: "heart.text.square",
                    message: "HealthKit not available",
                    detail: "HealthKit is not available on this device"
                )
            } else if !hasAnyHealthData {
                emptyState(
                    icon: "heart.text.square",
                    message: "No health data synced yet",
                    detail: "Enable HealthKit integration in settings to see how health metrics relate to symptoms"
                )
            } else if correlations.isEmpty {
                emptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    message: "Not enough data to identify correlations",
                    detail: "Keep logging symptoms to discover patterns with your health metrics"
                )
            } else {
                List {
                    Section {
                        Text("Shows how health metrics may relate to symptom severity")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(correlations) { correlation in
                        HealthCorrelationRow(correlation: correlation)
                    }
                }
                .listStyle(.insetGrouped)
                .themedScrollBackground()
            }
        }
        .task(id: days) {
            await loadCorrelations()
        }
    }

    private func loadCorrelations() async {
        isLoading = true

        let bgContext = CoreDataStack.shared.newBackgroundContext()

        // Check if we have any health data at all
        let hasHealthData = await bgContext.perform {
            let request = SymptomEntry.fetchRequest()
            request.predicate = NSPredicate(
                format: "hkHRV != nil OR hkRestingHR != nil OR hkSleepHours != nil"
            )
            request.fetchLimit = 1
            return (try? bgContext.fetch(request).first) != nil
        }
        hasAnyHealthData = hasHealthData

        let correlations = await bgContext.perform {
            AnalysisEngine.analysePhysiologicalCorrelations(in: bgContext, days: days)
        }
        self.correlations = correlations
        isLoading = false
    }

    private func emptyState(icon: String, message: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HealthCorrelationRow: View {
    let correlation: PhysiologicalCorrelation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: correlation.symptomTypeColor))
                    .frame(width: 12, height: 12)
                Text(correlation.symptomTypeName)
                    .font(.headline)
            }

            HStack {
                Image(systemName: metricIcon)
                    .foregroundStyle(.blue)
                Text(correlation.metricName)
                    .font(.subheadline)
            }

            if let high = correlation.averageWithHighSymptoms,
               let low = correlation.averageWithLowSymptoms {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(correlation.isPositive ? "High level days:" : "High symptom days:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatMetricValue(high, metric: correlation.metricName))
                            .font(.caption.weight(.medium))
                    }

                    HStack {
                        Text(correlation.isPositive ? "Low level days:" : "Low symptom days:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatMetricValue(low, metric: correlation.metricName))
                            .font(.caption.weight(.medium))
                    }
                }

                HStack {
                    Text(interpretationText)
                        .font(.caption)
                        .foregroundStyle(interpretationColor)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var metricIcon: String {
        switch correlation.metricName {
        case "HRV": return "waveform.path.ecg"
        case "Resting heart rate": return "heart.fill"
        case "Sleep hours": return "bed.double.fill"
        default: return "chart.line.uptrend.xyaxis"
        }
    }

    private func formatMetricValue(_ value: Double, metric: String) -> String {
        switch metric {
        case "Sleep hours":
            return String(format: "%.1f hours", value)
        case "HRV":
            return String(format: "%.0f ms", value)
        case "Resting heart rate":
            return String(format: "%.0f bpm", value)
        default:
            return String(format: "%.1f", value)
        }
    }

    private var interpretationText: String {
        guard let high = correlation.averageWithHighSymptoms,
              let low = correlation.averageWithLowSymptoms else {
            return ""
        }

        let diff = abs(high - low)
        let diffPercent = (diff / max(high, low)) * 100

        if correlation.correlationStrength > 0.3 {
            return String(format: "Higher %@ linked to worsening (%.0f%% difference)", correlation.metricName.lowercased(), diffPercent)
        } else if correlation.correlationStrength < -0.3 {
            return String(format: "Lower %@ linked to worsening (%.0f%% difference)", correlation.metricName.lowercased(), diffPercent)
        } else {
            return "Moderate correlation"
        }
    }

    private var interpretationColor: Color {
        if abs(correlation.correlationStrength) > 0.5 {
            return .red
        } else if abs(correlation.correlationStrength) > 0.3 {
            return .orange
        } else {
            return .secondary
        }
    }
}
