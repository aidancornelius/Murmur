import SwiftUI

@main
struct MurmurApp: App {
    @UIApplicationDelegateAdaptor(MurmurAppDelegate.self) private var appDelegate

    private let stack = CoreDataStack.shared

    var body: some Scene {
        WindowGroup {
            if let manualCycleTracker = appDelegate.manualCycleTracker {
                RootContainer()
                    .environment(\.managedObjectContext, stack.context)
                    .environmentObject(appDelegate.healthKitAssistant)
                    .environmentObject(appDelegate.calendarAssistant)
                    .environmentObject(manualCycleTracker)
                    .onAppear {
                        // Handle UI test mode
                        if CommandLine.arguments.contains("-UITestMode") {
                            // Skip onboarding for UI tests
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

                            // Seed sample data if requested
                            if CommandLine.arguments.contains("-SeedSampleData") {
                                UserDefaults.standard.set(false, forKey: "hasGeneratedSampleData")
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
    @State private var showingAddEntry = false
    @State private var showingAddActivity = false
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some View {
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
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(value: Route.analysis) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                            }
                            .accessibilityLabel("Analysis")
                            .accessibilityHint("View trends and correlations")
                        }
                    }
            }
            .task {
                // Skip HealthKit authorization dialog in UI test mode
                if !CommandLine.arguments.contains("-UITestMode") {
                    await healthKit.bootstrapAuthorizations()
                }
            }
            .onAppear {
                SampleDataSeeder.seedIfNeeded(in: context)
                #if targetEnvironment(simulator)
                // Check if we should generate sample data
                let hasGeneratedSampleData = UserDefaults.standard.bool(forKey: "hasGeneratedSampleData")
                if !hasGeneratedSampleData {
                    SampleDataSeeder.generateSampleEntries(in: context)
                    UserDefaults.standard.set(true, forKey: "hasGeneratedSampleData")
                }
                #endif
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
            }
            .sheet(isPresented: $showingAddActivity) {
                NavigationStack {
                    AddActivityView()
                        .environment(\.managedObjectContext, context)
                }
            }
        } else {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                hasCompletedOnboarding = true
                SampleDataSeeder.seedIfNeeded(in: context)
            }
            .environmentObject(healthKit)
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

    var body: some View {
        HStack {
            Spacer()
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 20.0) {
                    HStack(spacing: 20.0) {
                        Button(action: onSymptom) {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 24))
                                .frame(width: 60, height: 60)
                        }
                        .glassEffect(in: Circle())
                        .tint(.pink)
                        .accessibilityLabel("Log symptom")
                        .accessibilityHint("Opens form to record a symptom")

                        Button(action: onActivity) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 24))
                                .frame(width: 60, height: 60)
                        }
                        .glassEffect(in: Circle())
                        .tint(.purple)
                        .accessibilityLabel("Log activity")
                        .accessibilityHint("Opens form to record an activity or event")
                    }
                }
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            } else {
                HStack(spacing: 12) {
                    Button(action: onSymptom) {
                        Image(systemName: "heart.text.square")
                            .font(.title3.weight(.semibold))
                            .padding(16)
                            .foregroundStyle(.pink)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .accessibilityLabel("Log symptom")
                    .accessibilityHint("Opens form to record a symptom")

                    Button(action: onActivity) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3.weight(.semibold))
                            .padding(16)
                            .foregroundStyle(.purple)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .accessibilityLabel("Log activity")
                    .accessibilityHint("Opens form to record an activity or event")
                }
            }
        }
    }
}
