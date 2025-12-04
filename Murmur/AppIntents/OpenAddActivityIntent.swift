// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// OpenAddActivityIntent.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// App Intent for opening the add activity view.
//
import AppIntents
import SwiftUI

@available(iOS 16.0, *)
struct OpenAddActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Log an activity"
    static let description = IntentDescription("Open the activity logging screen to record an event or activity")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Post notification to open the add activity view
        NotificationCenter.default.post(name: .openAddActivity, object: nil)
        return .result()
    }
}
