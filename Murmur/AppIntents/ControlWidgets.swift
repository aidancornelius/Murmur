import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct LogSymptomControl: ControlWidget {
    static let kind: String = "com.murmur.LogSymptomControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: ControlWidgetProvider()
        ) { value in
            ControlWidgetButton(action: OpenAddEntryIntent()) {
                Label("How are you feeling?", systemImage: "heart.text.square")
                Text(value)
            }
        }
        .displayName("Log symptom")
        .description("Quick access to log how you're feeling")
    }
}

@available(iOS 18.0, *)
struct LogActivityControl: ControlWidget {
    static let kind: String = "com.murmur.LogActivityControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: ControlWidgetProvider()
        ) { value in
            ControlWidgetButton(action: OpenAddActivityIntent()) {
                Label("Log activity", systemImage: "calendar.badge.clock")
                Text(value)
            }
        }
        .displayName("Log activity")
        .description("Quick access to log an activity or event")
    }
}

@available(iOS 18.0, *)
struct ControlWidgetProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ()) async throws -> String {
        ""
    }

    func previewValue(configuration: ()) -> String {
        ""
    }
}

@available(iOS 18.0, *)
struct MurmurControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        LogSymptomControl()
        LogActivityControl()
    }
}
