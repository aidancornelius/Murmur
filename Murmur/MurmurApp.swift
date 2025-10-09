//
//  MurmurApp.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI
import CoreData

extension Notification.Name {
    static let openAddEntry = Notification.Name("openAddEntry")
    static let openAddActivity = Notification.Name("openAddActivity")
}

@main
struct MurmurApp: App {
    @UIApplicationDelegateAdaptor(MurmurAppDelegate.self) private var appDelegate
    @StateObject private var appearanceManager = AppearanceManager.shared
    @StateObject private var appLock = AppLockController()

    private let stack = CoreDataStack.shared

    init() {
        // Configure onboarding state for UI testing BEFORE any views are created
        // Do this synchronously but defer data seeding to avoid deadlock
        if UITestConfiguration.isUITesting && !UITestConfiguration.shouldShowOnboarding {
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        }
    }

    var body: some Scene {
        WindowGroup {
            // Check for CoreData initialization errors first
            if let error = stack.initializationError {
                CoreDataErrorView(error: error)
            } else if let manualCycleTracker = appDelegate.manualCycleTracker {
                RootContainer()
                    .environment(\.managedObjectContext, stack.context)
                    .environmentObject(appDelegate.healthKitAssistant)
                    .environmentObject(appDelegate.calendarAssistant)
                    .environmentObject(manualCycleTracker)
                    .environmentObject(appearanceManager)
                    .environmentObject(appLock)
                    .task {
                        // Configure app for UI testing (data seeding etc)
                        // Run in background to avoid blocking UI
                        if UITestConfiguration.isUITesting {
                            let context = stack.context
                            Task.detached(priority: .userInitiated) {
                                UITestConfiguration.configure(context: context)
                            }
                        }
                    }
            } else {
                ProgressView()
            }
        }
    }
}

private struct RootContainer: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var healthKit: HealthKitAssistant
    @EnvironmentObject private var calendar: CalendarAssistant
    @EnvironmentObject private var appLock: AppLockController
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAddEntry = false
    @State private var showingAddActivity = false
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding)

    private let openAddEntryPublisher = NotificationCenter.default.publisher(for: .openAddEntry)
    private let openAddActivityPublisher = NotificationCenter.default.publisher(for: .openAddActivity)

    var body: some View {
        ZStack {
            Group {
                if hasCompletedOnboarding {
                    NavigationStack {
                        TimelineView()
                        .navigationDestination(for: Route.self) { route in
                            switch route {
                            case .settings:
                                SettingsRootView()
                            case .analysis:
                                AnalysisView()
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                NavigationLink(value: Route.settings) {
                                    Image(systemName: "gearshape")
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.settingsButton)
                                .accessibilityLabel("Settings")
                                .accessibilityHint("Manage app preferences, symptoms, and integrations")
                                .accessibilityInputLabels(["Settings", "Preferences", "Options", "Configure"])
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                NavigationLink(value: Route.analysis) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.analysisButton)
                                .accessibilityLabel("Analysis")
                                .accessibilityHint("View trends and correlations")
                                .accessibilityInputLabels(["Analysis", "Charts", "Trends", "View analysis", "Show charts"])
                            }
                        }
                }
                .task {
                    // Skip HealthKit authorization in UI test mode (unless explicitly enabled)
                    let shouldSkipHealthKit = UITestConfiguration.isUITesting || UITestConfiguration.shouldDisableHealthKit
                    if !shouldSkipHealthKit {
                        await healthKit.bootstrapAuthorizations()
                    }
                }
                .onAppear {
                    // Only seed/generate if not in UI test mode (handled by UITestConfiguration)
                    if !UITestConfiguration.isUITesting {
                        SampleDataSeeder.seedIfNeeded(in: context)
                        cleanOrphanedEntries(in: context)
                        #if targetEnvironment(simulator)
                        // Check if we should generate sample data
                        let hasGeneratedSampleData = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasGeneratedSampleData)
                        if !hasGeneratedSampleData {
                            SampleDataSeeder.generateSampleEntries(in: context)
                            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasGeneratedSampleData)
                        }
                        #endif
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    FloatingActionButtons(
                        onSymptom: { showingAddEntry = true },
                        onActivity: { showingAddActivity = true }
                    )
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .sheet(isPresented: $showingAddEntry) {
                    NavigationStack {
                        AddEntryView()
                            .environment(\.managedObjectContext, context)
                    }
                    .themedSurface()
                }
                .sheet(isPresented: $showingAddActivity) {
                    NavigationStack {
                        UnifiedEventView()
                            .environment(\.managedObjectContext, context)
                            .environmentObject(healthKit)
                            .environmentObject(calendar)
                    }
                    .themedSurface()
                }
                .onReceive(openAddEntryPublisher) { _ in
                    showingAddEntry = true
                }
                .onReceive(openAddActivityPublisher) { _ in
                    showingAddActivity = true
                }
                } else {
                    OnboardingView {
                        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
                        hasCompletedOnboarding = true
                        // Only seed default symptom types if not in UI test mode
                        if !UITestConfiguration.isUITesting {
                            SampleDataSeeder.seedIfNeeded(in: context)
                        }
                    }
                    .environmentObject(healthKit)
                    .environmentObject(appLock)
                }
            }

            if appLock.isLockActive {
                LockOverlayView()
            }
        }
        .themedSurface()
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                appLock.appDidEnterBackground()
            case .active:
                Task { await appLock.requestUnlockIfNeeded() }
            default:
                break
            }
        }
        .task {
            await appLock.requestUnlockIfNeeded()
        }
    }

    private func cleanOrphanedEntries(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<SymptomEntry> = SymptomEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "symptomType == nil")

        if let orphanedEntries = try? context.fetch(fetchRequest), !orphanedEntries.isEmpty {
            orphanedEntries.forEach(context.delete)
            try? context.save()
        }
    }
}

private enum Route: Hashable {
    case settings
    case analysis
}

private struct FloatingActionButtons: View {
    let onSymptom: () -> Void
    let onActivity: () -> Void

    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        // GlassEffectContainer and .glassEffect() APIs are now working.
        // The liquid glass implementation below is correct and functional.
        HStack {
            if #available(iOS 26.0, *) {
                Spacer()
                GlassEffectContainer(spacing: 40.0) {
                    HStack(spacing: 8.0) {
                        Button(action: onSymptom) {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 28, weight: .medium))
                                .frame(width: 72, height: 72)
                                .foregroundStyle(palette.accentColor)
                        }
                        .glassEffect(.regular.interactive())
                        .accessibilityLabel("Log symptom")
                        .accessibilityIdentifier(AccessibilityIdentifiers.logSymptomButton)
                        .accessibilityHint("Opens form to record a symptom")
                        .accessibilityInputLabels(["Log symptom", "Add symptom", "Record symptom", "New symptom", "Log entry"])

                        Button(action: onActivity) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 28, weight: .medium))
                                .frame(width: 72, height: 72)
                                .foregroundStyle(palette.accentColor)
                        }
                        .glassEffect(.regular.interactive())
                        .accessibilityLabel("Log activity")
                        .accessibilityIdentifier(AccessibilityIdentifiers.logEventButton)
                        .accessibilityHint("Opens form to record an activity or event")
                        .accessibilityInputLabels(["Log activity", "Add activity", "Record activity", "New activity", "Log event"])
                    }
                }
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            } else {
                Spacer()
                HStack(spacing: 12) {
                    Button(action: onActivity) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3.weight(.semibold))
                            .padding(16)
                            .foregroundStyle(palette.accentColor.opacity(0.85))
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .accessibilityLabel("Log activity")
                    .accessibilityIdentifier(AccessibilityIdentifiers.logEventButton)
                    .accessibilityHint("Opens form to record an activity or event")
                    .accessibilityInputLabels(["Log activity", "Add activity", "Record activity", "New activity", "Log event"])

                    Button(action: onSymptom) {
                        Image(systemName: "heart.text.square")
                            .font(.title3.weight(.semibold))
                            .padding(16)
                            .foregroundStyle(palette.accentColor)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .accessibilityLabel("Log symptom")
                    .accessibilityIdentifier(AccessibilityIdentifiers.logSymptomButton)
                    .accessibilityHint("Opens form to record a symptom")
                    .accessibilityInputLabels(["Log symptom", "Add symptom", "Record symptom", "New symptom", "Log entry"])
                }
            }
        }
    }
}
