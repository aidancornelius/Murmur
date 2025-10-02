import AppIntents
import SwiftUI

@available(iOS 16.0, *)
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
