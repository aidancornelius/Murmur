//
//  OpenAddActivityIntent.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import AppIntents
import SwiftUI

struct OpenAddActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an activity"
    static var description = IntentDescription("Open the activity logging screen to record an event or activity")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Post notification to open the add activity view
        NotificationCenter.default.post(name: .openAddActivity, object: nil)
        return .result()
    }
}

extension Notification.Name {
    static let openAddActivity = Notification.Name("openAddActivity")
}
