import SwiftUI

enum SettingsRoute: Hashable {
    case symptomTypes
    case reminders
    case healthKit
    case manualCycle
    case dataManagement
    case tipJar
}

struct SettingsRootView: View {
    @EnvironmentObject private var healthKit: HealthKitAssistant

    var body: some View {
        List {
            Section("What you track") {
                NavigationLink("Tracked symptoms", value: SettingsRoute.symptomTypes)
                    .accessibilityHint("Manage which symptoms you track in the app")
                NavigationLink("Reminders", value: SettingsRoute.reminders)
                    .accessibilityHint("Set up reminders to log symptoms regularly")
            }

            Section("Your health data") {
                NavigationLink("Connect to Health", value: SettingsRoute.healthKit)
                    .accessibilityHint("Manage Apple Health integration for enriched symptom tracking")
                NavigationLink("Manual cycle tracking", value: SettingsRoute.manualCycle)
                    .accessibilityHint("Track menstrual cycle manually if not using HealthKit")
                NavigationLink("Data management", value: SettingsRoute.dataManagement)
                    .accessibilityHint("Backup, restore, or reset your data")
            }

            Section("About") {
                NavigationLink(value: SettingsRoute.tipJar) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                        Text("Send a tip")
                    }
                }
                .accessibilityHint("Support the development of Murmur with a tip")

                HStack {
                    Image(systemName: "heart.text.square")
                        .foregroundStyle(.blue)
                    Text("Health app")
                    Spacer()
                    Text(healthKit.isHealthDataAvailable ? "Connected" : "Not available")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.green)
                    Text("All data stays on your device, where it belongs.")
                        .font(.subheadline)
                }

                HStack {
                    Image(systemName: "globe.asia.australia")
                        .foregroundStyle(.purple)
                    Text("Made by Aidan Cornelius-Bell on Kaurna Country.")
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .symptomTypes:
                SymptomTypeListView()
            case .reminders:
                ReminderListView()
            case .healthKit:
                HealthKitSettingsView()
            case .manualCycle:
                ManualCycleSettingsView()
            case .dataManagement:
                DataManagementView()
            case .tipJar:
                TipJarView()
            }
        }
    }
}
