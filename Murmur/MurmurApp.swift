// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// MurmurApp.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Main application entry point and scene configuration.
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
            AppContentView(appDelegate: appDelegate, stack: stack)
                .environmentObject(appearanceManager)
        }
    }
}

/// Intermediary view that properly observes the app delegate's @Published properties
private struct AppContentView: View {
    @ObservedObject var appDelegate: MurmurAppDelegate
    let stack: CoreDataStack

    var body: some View {
        // Check for CoreData initialization errors first
        if let error = appDelegate.coreDataError {
            CoreDataErrorView(error: error)
        } else if let manualCycleTracker = appDelegate.manualCycleTracker {
            RootContainer()
                .environment(\.managedObjectContext, stack.context)
                .environmentObject(appDelegate.healthKitAssistant)
                .environmentObject(appDelegate.calendarAssistant)
                .environmentObject(appDelegate.sleepImportService)
                .environmentObject(manualCycleTracker)
                .task {
                    // Configure app for UI testing (data seeding etc)
                    // Run async to avoid blocking UI
                    if UITestConfiguration.isUITesting {
                        let context = stack.context
                        await UITestConfiguration.configure(context: context)
                    }
                }
        } else {
            InitializationWaitView()
        }
    }
}

/// View that shows loading state with timeout handling
private struct InitializationWaitView: View {
    @State private var showTimeoutError = false
    private let timeoutSeconds: Double = 10

    var body: some View {
        Group {
            if showTimeoutError {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)

                    Text("Unable to start")
                        .font(.title2.bold())

                    Text("The app is taking longer than expected to initialize. This may indicate a problem with your data store.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try these steps:")
                            .font(.subheadline.bold())
                        Text("1. Force quit and reopen the app")
                        Text("2. Restart your device")
                        Text("3. Check available storage space")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            showTimeoutError = true
        }
    }
}

private struct RootContainer: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var healthKit: HealthKitAssistant
    @EnvironmentObject private var calendar: CalendarAssistant
    @EnvironmentObject private var sleepImportService: SleepImportService
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAddEntry = false
    @State private var showingAddActivity = false
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding)
    @State private var recoveryInfo: DataRecoveryService.RecoveryInfo?
    @State private var showRecoverySheet = false
    @State private var isRestoring = false

    private let openAddEntryPublisher = NotificationCenter.default.publisher(for: .openAddEntry)
    private let openAddActivityPublisher = NotificationCenter.default.publisher(for: .openAddActivity)

    var body: some View {
        ZStack {
            Group {
                if hasCompletedOnboarding {
                    NavigationStack {
                        TimelineView(context: context)
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
                .task {
                    // Check for recovery opportunity (empty database with backup available)
                    if !UITestConfiguration.isUITesting {
                        if let info = await DataRecoveryService.shared.checkForRecoveryOpportunity(context: context) {
                            recoveryInfo = info
                            showRecoverySheet = true
                        }
                    }
                }
                .sheet(isPresented: $showRecoverySheet) {
                    if let info = recoveryInfo {
                        DataRecoverySheet(
                            recoveryInfo: info,
                            isRestoring: $isRestoring,
                            onRestore: {
                                Task {
                                    await performRecovery(info: info)
                                }
                            },
                            onDismiss: {
                                DataRecoveryService.shared.dismissRecoveryPrompt()
                                showRecoverySheet = false
                            }
                        )
                    }
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
                }
            }
        }
        .themedSurface()
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                // Save Core Data changes when entering background
                Task {
                    CoreDataStack.shared.cleanup()
                }
            case .inactive:
                // Prepare for possible termination
                break
            case .active:
                // App returned to foreground - trigger sleep import if enabled
                Task {
                    await sleepImportService.performImportIfNeeded()
                }
            @unknown default:
                break
            }
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

    private func performRecovery(info: DataRecoveryService.RecoveryInfo) async {
        isRestoring = true
        do {
            try await AutoBackupService.shared.restoreBackup(from: info.backup)
            DataRecoveryService.shared.clearDeliberateResetFlag()
            await MainActor.run {
                HapticFeedback.success.trigger()
                isRestoring = false
                showRecoverySheet = false
                recoveryInfo = nil
            }
        } catch {
            await MainActor.run {
                HapticFeedback.error.trigger()
                isRestoring = false
            }
        }
    }
}

/// Sheet for offering data recovery from backup
private struct DataRecoverySheet: View {
    let recoveryInfo: DataRecoveryService.RecoveryInfo
    @Binding var isRestoring: Bool
    let onRestore: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "arrow.counterclockwise.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Restore your data?")
                    .font(.title2.bold())

                Text("Your timeline appears empty, but we found a backup with your data. Would you like to restore it?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Backup from \(recoveryInfo.metadata.formattedCreatedAt)", systemImage: "clock")
                    Label(recoveryInfo.metadata.summary, systemImage: "doc.text")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: onRestore) {
                        if isRestoring {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Restore backup")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRestoring)

                    Button("Not now", action: onDismiss)
                        .foregroundStyle(.secondary)
                        .disabled(isRestoring)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Data recovery")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isRestoring)
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
