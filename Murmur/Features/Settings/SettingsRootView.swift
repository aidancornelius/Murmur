//
//  SettingsRootView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI

enum SettingsRoute: Hashable {
    case symptomTypes
    case reminders
    case loadCapacity
    case healthKit
    case manualCycle
    case dataManagement
    case export
    case appearance
    case accessibility
    case tipJar
}

struct SettingsRootView: View {
    @EnvironmentObject private var healthKit: HealthKitAssistant
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var store = StoreManager()
    @State private var showingOnboarding = false

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        List {
            Section("What you track") {
                NavigationLink("Tracked symptoms", value: SettingsRoute.symptomTypes)
                    .accessibilityHint("Manage which symptoms you track in the app")
                    .accessibilityIdentifier(AccessibilityIdentifiers.trackedSymptomsButton)
                    .accessibilityInputLabels(["Tracked symptoms", "Symptoms", "Manage symptoms", "Edit symptoms"])
                    .listRowBackground(palette.surfaceColor)
                NavigationLink("Reminders", value: SettingsRoute.reminders)
                    .accessibilityHint("Set up reminders to log symptoms regularly")
                    .accessibilityIdentifier(AccessibilityIdentifiers.remindersButton)
                    .accessibilityInputLabels(["Reminders", "Notifications", "Reminder settings", "Set reminders"])
                    .listRowBackground(palette.surfaceColor)
                NavigationLink("Load capacity", value: SettingsRoute.loadCapacity)
                    .accessibilityHint("Adjust thresholds based on your condition and recovery patterns")
                    .accessibilityIdentifier(AccessibilityIdentifiers.loadCapacityButton)
                    .accessibilityInputLabels(["Load capacity", "Capacity", "Thresholds", "Load settings"])
                    .listRowBackground(palette.surfaceColor)
            }
            
            Section("Personalisation") {
                NavigationLink("Appearance", value: SettingsRoute.appearance)
                    .accessibilityHint("Customise colour schemes for light and dark mode")
                    .accessibilityIdentifier(AccessibilityIdentifiers.appearanceButton)
                    .accessibilityInputLabels(["Appearance", "Theme", "Colours", "Color scheme", "Appearance settings"])
                    .listRowBackground(palette.surfaceColor)
            }

            Section("Your health data") {
                NavigationLink("Connect to Health", value: SettingsRoute.healthKit)
                    .accessibilityHint("Manage Apple Health integration for enriched symptom tracking")
                    .accessibilityInputLabels(["Connect to Health", "Health app", "HealthKit", "Health integration"])
                    .listRowBackground(palette.surfaceColor)
                NavigationLink("Manual cycle tracking", value: SettingsRoute.manualCycle)
                    .accessibilityHint("Track menstrual cycle manually if not using HealthKit")
                    .accessibilityInputLabels(["Manual cycle tracking", "Cycle tracking", "Period tracking", "Menstrual tracking"])
                    .listRowBackground(palette.surfaceColor)
            }

            Section("Privacy & data") {
                NavigationLink("Data management", value: SettingsRoute.dataManagement)
                    .accessibilityHint("Backup, restore, or reset your data")
                    .accessibilityIdentifier(AccessibilityIdentifiers.dataManagementButton)
                    .accessibilityInputLabels(["Data management", "Backup", "Restore data", "Manage data"])
                    .listRowBackground(palette.surfaceColor)
                  NavigationLink("Export entries", value: SettingsRoute.export)
                      .accessibilityHint("Generate a PDF export of your symptom history")
                      .listRowBackground(palette.surfaceColor)
            }

            Section("Accessibility") {
                NavigationLink("Accessibility options", value: SettingsRoute.accessibility)
                    .accessibilityHint("Voice logging, audio summaries, and switch control tips")
                    .accessibilityInputLabels(["Accessibility options", "Accessibility", "Voice control", "Audio features"])
                    .listRowBackground(palette.surfaceColor)
            }

            Section {
                // Personal message
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hi, I'm Aidan")
                        .font(.headline)
                        .foregroundStyle(palette.accentColor)

                    Text("I built Murmur because I needed a better way to track my own health patterns. Living with chronic conditions taught me that understanding your body starts with listening to its murmurs before they become shouts.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("This app is personal to me, and I hope it helps you understand your own patterns too. Your data never leaves your device. It’s yours alone, as it should be.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
                .listRowBackground(palette.surfaceColor)

                // Revisit onboarding option
                Button(action: {
                    showingOnboarding = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise.circle")
                            .foregroundStyle(palette.accentColor)
                            .font(.title3)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Revisit tour")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text("See the onboarding screens again")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .listRowBackground(palette.surfaceColor)

                // Support option
                if store.hasTipped {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(palette.accentColor)
                            .font(.title3)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Thank you for supporting Murmur!")
                                .font(.subheadline)
                            Text("Your tip helps keep the app independent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(palette.surfaceColor)
                } else {
                    NavigationLink(value: SettingsRoute.tipJar) {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(palette.accentColor)
                                .font(.title3)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Support Murmur")
                                    .font(.subheadline)
                                Text("Help keep the app independent")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .accessibilityHint("Support the development of Murmur with a tip")
                    .listRowBackground(palette.surfaceColor)
                }

                // Key promises
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(palette.accentColor)
                            .font(.title3)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Private by design")
                                .font(.subheadline)
                            Text("Your data never leaves this device")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "heart.text.square.fill")
                            .foregroundStyle(palette.accentColor)
                            .font(.title3)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Health app integration")
                                .font(.subheadline)
                            Text(healthKit.isHealthDataAvailable ? "Connected and syncing" : "Not available on this device")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "accessibility")
                            .foregroundStyle(palette.accentColor)
                            .font(.title3)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Built for everyone")
                                .font(.subheadline)
                            Text("Voice control, audio summaries, and more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(palette.surfaceColor)

                // Attribution
                HStack(spacing: 8) {
                    Image(systemName: "globe.asia.australia.fill")
                        .foregroundStyle(palette.accentColor.opacity(0.7))
                        .font(.caption)
                    Text("Made with care on Kaurna Country")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .listRowBackground(palette.surfaceColor)
            } header: {
                Text("About Murmur")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .themedScrollBackground()
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(onComplete: {
                showingOnboarding = false
            })
            .environmentObject(healthKit)
        }
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .symptomTypes:
                SymptomTypeListView()
            case .reminders:
                ReminderListView()
            case .loadCapacity:
                LoadCapacitySettingsView()
            case .healthKit:
                HealthKitSettingsView()
            case .manualCycle:
                ManualCycleSettingsView()
            case .dataManagement:
                DataManagementView()
            case .export:
                ExportOptionsView()
            case .appearance:
                AppearanceSettingsView()
            case .accessibility:
                AccessibilityOptionsView()
            case .tipJar:
                TipJarView()
            }
        }
    }
}

struct AccessibilityOptionsView: View {
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        Form {
            Section {
                Text("Murmur includes features to support different accessibility needs, including voice logging, audio summaries, and optimised controls for assistive technologies.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("Voice logging") {
                NavigationLink {
                    VoiceCommandView()
                } label: {
                    Label("Voice commands", systemImage: "mic.circle")
                }
                Text("Log symptoms hands-free. The first time you open this screen you'll be prompted to allow speech recognition.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(palette.surfaceColor)

            Section("Audio summaries") {
                Label("Hear daily summaries", systemImage: "speaker.wave.2")
                Text("Open any day in your timeline to find buttons that read the day aloud or play a tone graph of symptom severity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(palette.surfaceColor)

            Section("Switch Control & AssistiveTouch") {
                Label("Optimised controls", systemImage: "hand.point.up.left")
                Text("Buttons use large touch targets and grouped navigation actions so Switch Control and AssistiveTouch can move through screens with fewer steps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(palette.surfaceColor)
        }
        .navigationTitle("Accessibility options")
        .navigationBarTitleDisplayMode(.large)
        .themedScrollBackground()
    }
}
