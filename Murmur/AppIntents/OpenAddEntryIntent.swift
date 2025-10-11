//
//  OpenAddEntryIntent.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import AppIntents
import SwiftUI

@available(iOS 16.0, *)
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
