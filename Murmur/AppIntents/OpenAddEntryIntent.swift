import AppIntents
import SwiftUI

@available(iOS 16.0, *)
struct OpenAddEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "How are you feeling?"
    static var description = IntentDescription("Open the symptom logging screen to record how you're feeling")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Post notification to open the add entry view
        NotificationCenter.default.post(name: .openAddEntry, object: nil)
        return .result()
    }
}
