//
//  AccessibilityIdentifiers.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import Foundation

/// Centralised accessibility identifiers for UI testing
public enum AccessibilityIdentifiers {
    // MARK: - Timeline
    public static let logSymptomButton = "log-symptom-button"
    public static let logEventButton = "log-event-button"
    public static let timelineScrollView = "timeline-scroll-view"
    public static let timelineList = "timeline-list"

    // MARK: - Navigation
    public static let settingsButton = "settings-button"
    public static let analysisButton = "analysis-button"
    public static let backButton = "back-button"

    // MARK: - Add Entry
    public static let searchAllSymptomsButton = "search-all-symptoms-button"
    public static let symptomSearchField = "symptom-search-field"
    public static let severitySlider = "severity-slider"
    public static let severityLabel = "severity-label"
    public static let saveButton = "save-button"
    public static let cancelButton = "cancel-button"
    public static let noteTextField = "note-text-field"
    public static let locationToggle = "location-toggle"
    public static let timestampPicker = "timestamp-picker"
    public static let sameSeverityToggle = "same-severity-toggle"

    // MARK: - Settings
    public static let trackedSymptomsButton = "tracked-symptoms-button"
    public static let remindersButton = "reminders-button"
    public static let loadCapacityButton = "load-capacity-button"
    public static let notificationsButton = "notifications-button"
    public static let appearanceButton = "appearance-button"
    public static let privacyButton = "privacy-button"
    public static let dataManagementButton = "data-management-button"
    public static let aboutButton = "about-button"
    public static let healthKitToggle = "healthkit-toggle"
    public static let locationSettingsToggle = "location-settings-toggle"
    public static let exportDataButton = "export-data-button"
    public static let darkModeToggle = "dark-mode-toggle"

    // MARK: - Tracked Symptoms
    public static let addSymptomButton = "add-symptom-button"
    public static let symptomNameField = "symptom-name-field"

    // MARK: - Analysis
    public static let trendsTab = "trends-tab"
    public static let correlationsTab = "correlations-tab"
    public static let patternsTab = "patterns-tab"
    public static let analysisViewSelector = "analysis-view-selector"
    public static let analysisTrendsButton = "analysis-trends-button"
    public static let analysisCalendarButton = "analysis-calendar-button"
    public static let analysisHistoryButton = "analysis-history-button"
    public static let analysisActivitiesButton = "analysis-activities-button"
    public static let analysisPatternsButton = "analysis-patterns-button"
    public static let analysisHealthButton = "analysis-health-button"
    public static let timePeriodPicker = "time-period-picker"
    public static let timePeriod7Days = "time-period-7"
    public static let timePeriod30Days = "time-period-30"
    public static let timePeriod90Days = "time-period-90"
    public static let chartView = "chart-view"
    public static let calendarGrid = "calendar-grid"

    // MARK: - Day Detail
    public static let dayDetailScrollView = "day-detail-scroll-view"
    public static let dayDetailList = "day-detail-list"
    public static let addEntryForDayButton = "add-entry-day-button"

    // MARK: - Dynamic Identifiers

    /// Generate identifier for a timeline entry cell
    /// - Parameter id: The unique identifier or name of the entry
    public static func entryCell(_ id: String) -> String {
        "entry-cell-\(id)"
    }

    /// Generate identifier for a quick symptom selection button
    /// - Parameter symptomName: The name of the symptom
    public static func quickSymptomButton(_ symptomName: String) -> String {
        "quick-symptom-button-\(symptomName)"
    }

    /// Generate identifier for a symptom cell
    /// - Parameter name: The name of the symptom
    public static func symptomCell(_ name: String) -> String {
        "symptom-cell-\(name)"
    }

    /// Generate identifier for an individual severity slider
    /// - Parameter symptomName: The name of the symptom
    public static func individualSeveritySlider(_ symptomName: String) -> String {
        "severity-slider-\(symptomName)"
    }
}
