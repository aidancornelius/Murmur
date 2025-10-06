//
//  AccessibilityIdentifiers.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import Foundation

/// Centralised accessibility identifiers for UI testing
enum AccessibilityIdentifiers {
    // MARK: - Timeline
    static let logSymptomButton = "log-symptom-button"
    static let logEventButton = "log-event-button"
    static let timelineScrollView = "timeline-scroll-view"
    static let timelineList = "timeline-list"

    // MARK: - Navigation
    static let settingsButton = "settings-button"
    static let analysisButton = "analysis-button"
    static let backButton = "back-button"

    // MARK: - Add Entry
    static let searchAllSymptomsButton = "search-all-symptoms-button"
    static let symptomSearchField = "symptom-search-field"
    static let severitySlider = "severity-slider"
    static let severityLabel = "severity-label"
    static let saveButton = "save-button"
    static let cancelButton = "cancel-button"
    static let noteTextField = "note-text-field"
    static let locationToggle = "location-toggle"
    static let timestampPicker = "timestamp-picker"
    static let sameSeverityToggle = "same-severity-toggle"

    // MARK: - Settings
    static let trackedSymptomsButton = "tracked-symptoms-button"
    static let remindersButton = "reminders-button"
    static let loadCapacityButton = "load-capacity-button"
    static let notificationsButton = "notifications-button"
    static let appearanceButton = "appearance-button"
    static let privacyButton = "privacy-button"
    static let dataManagementButton = "data-management-button"
    static let aboutButton = "about-button"
    static let healthKitToggle = "healthkit-toggle"
    static let locationSettingsToggle = "location-settings-toggle"
    static let exportDataButton = "export-data-button"
    static let darkModeToggle = "dark-mode-toggle"

    // MARK: - Tracked Symptoms
    static let addSymptomButton = "add-symptom-button"
    static let symptomNameField = "symptom-name-field"

    // MARK: - Analysis
    static let trendsTab = "trends-tab"
    static let correlationsTab = "correlations-tab"
    static let patternsTab = "patterns-tab"
    static let analysisViewSelector = "analysis-view-selector"
    static let analysisTrendsButton = "analysis-trends-button"
    static let analysisCalendarButton = "analysis-calendar-button"
    static let analysisHistoryButton = "analysis-history-button"
    static let analysisActivitiesButton = "analysis-activities-button"
    static let analysisPatternsButton = "analysis-patterns-button"
    static let analysisHealthButton = "analysis-health-button"
    static let timePeriodPicker = "time-period-picker"
    static let timePeriod7Days = "time-period-7"
    static let timePeriod30Days = "time-period-30"
    static let timePeriod90Days = "time-period-90"
    static let chartView = "chart-view"
    static let calendarGrid = "calendar-grid"

    // MARK: - Day Detail
    static let dayDetailScrollView = "day-detail-scroll-view"
    static let dayDetailList = "day-detail-list"
    static let addEntryForDayButton = "add-entry-day-button"

    // MARK: - Dynamic Identifiers

    /// Generate identifier for a timeline entry cell
    /// - Parameter id: The unique identifier or name of the entry
    static func entryCell(_ id: String) -> String {
        "entry-cell-\(id)"
    }

    /// Generate identifier for a quick symptom selection button
    /// - Parameter symptomName: The name of the symptom
    static func quickSymptomButton(_ symptomName: String) -> String {
        "quick-symptom-button-\(symptomName)"
    }

    /// Generate identifier for a symptom cell
    /// - Parameter name: The name of the symptom
    static func symptomCell(_ name: String) -> String {
        "symptom-cell-\(name)"
    }

    /// Generate identifier for an individual severity slider
    /// - Parameter symptomName: The name of the symptom
    static func individualSeveritySlider(_ symptomName: String) -> String {
        "severity-slider-\(symptomName)"
    }
}
