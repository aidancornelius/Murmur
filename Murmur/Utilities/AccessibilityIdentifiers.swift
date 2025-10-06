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

    // MARK: - Navigation
    static let settingsButton = "settings-button"
    static let analysisButton = "analysis-button"
    static let backButton = "back-button"

    // MARK: - Add Entry
    static let symptomSearchField = "symptom-search-field"
    static let severitySlider = "severity-slider"
    static let severityLabel = "severity-label"
    static let saveButton = "save-button"
    static let cancelButton = "cancel-button"

    // MARK: - Settings
    static let trackedSymptomsButton = "tracked-symptoms-button"
    static let notificationsButton = "notifications-button"
    static let appearanceButton = "appearance-button"
    static let privacyButton = "privacy-button"
    static let dataManagementButton = "data-management-button"
    static let aboutButton = "about-button"

    // MARK: - Tracked Symptoms
    static let addSymptomButton = "add-symptom-button"
    static let symptomNameField = "symptom-name-field"

    // MARK: - Analysis
    static let trendsTab = "trends-tab"
    static let correlationsTab = "correlations-tab"
    static let patternsTab = "patterns-tab"

    // MARK: - Custom Symptom
    static func symptomCell(_ name: String) -> String {
        "symptom-cell-\(name)"
    }
}
