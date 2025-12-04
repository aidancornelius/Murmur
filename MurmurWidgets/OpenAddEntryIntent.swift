// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// OpenAddEntryIntent.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// App Intent for opening the add entry view.
//
import AppIntents
import SwiftUI

struct OpenAddEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "How are you feeling?"
    static let description = IntentDescription("Open the symptom logging screen to record how you're feeling")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Post notification to open the add entry view
        NotificationCenter.default.post(name: .openAddEntry, object: nil)
        return .result()
    }
}

extension Notification.Name {
    static let openAddEntry = Notification.Name("openAddEntry")
}
