import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var healthKit: HealthKitAssistant
    @State private var currentPage = 0
    let onComplete: () -> Void

    private let pages = [
        OnboardingPage(
            icon: "heart.text.square",
            iconColor: .pink,
            title: "Welcome to Murmur",
            description: "A symptom tracking app designed for people living with chronic conditions like ME/CFS, fibromyalgia, PTSD, and other conditions that require careful energy management.",
            benefits: []
        ),
        OnboardingPage(
            icon: "calendar.badge.clock",
            iconColor: .purple,
            title: "Track activities & energy",
            description: "Log activities with physical, cognitive, and emotional exertion levels to understand how different tasks affect you.",
            benefits: [
                "Plan your day around your energy levels",
                "Identify activities that trigger crashes",
                "Learn your personal limits"
            ]
        ),
        OnboardingPage(
            icon: "gauge.with.dots.needle.bottom.50percent",
            iconColor: .orange,
            title: "Monitor your load score",
            description: "Your load score tracks accumulated exertion and adjusts based on your symptoms, helping you pace activities to prevent crashes.",
            benefits: [
                "Visual warnings when you're approaching limits",
                "Symptom-aware recovery tracking",
                "Plan rest days proactively"
            ]
        ),
        OnboardingPage(
            icon: "heart.text.square.fill",
            iconColor: .red,
            title: "Log symptoms",
            description: "Track symptom severity throughout the day with optional notes. Star your most common symptoms for quick logging.",
            benefits: [
                "Identify symptom patterns over time",
                "Correlate symptoms with activities",
                "Provide detailed records for medical appointments"
            ]
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .blue,
            title: "Discover patterns",
            description: "View daily summaries, timelines, and correlations between activities and symptoms to understand your condition better.",
            benefits: [
                "Spot triggers you might have missed",
                "Track your progress over weeks and months",
                "Make informed decisions about your activities"
            ]
        ),
        OnboardingPage(
            icon: "mic.fill",
            iconColor: .green,
            title: "Voice commands & accessibility",
            description: "Log symptoms hands-free with voice commands. Full VoiceOver support, audio graphs, and switch control for accessibility.",
            benefits: [
                "Track symptoms when typing is difficult",
                "Navigate the app with assistive technologies",
                "Reduce cognitive load during flare-ups"
            ]
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            iconColor: .indigo,
            title: "Your data stays private",
            description: "All your health data stays on your device. Optionally connect to Apple Health to enrich entries with HRV, heart rate, and sleep data.",
            benefits: [
                "No cloud storage or syncing",
                "Optional biometric app lock",
                "Export your data anytime (CSV or PDF)"
            ]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    Button(action: requestHealthKitAndComplete) {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                            Text("Enable HealthKit")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .accessibilityHint("Requests permission to connect to Apple Health for enriched symptom tracking")

                    Button(action: onComplete) {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityHint("Starts using Murmur without HealthKit integration")
                } else {
                    Button(action: {
                        HapticFeedback.light.trigger()
                        withAnimation { currentPage += 1 }
                    }) {
                        HStack {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .accessibilityHint("Shows the next onboarding page")

                    if currentPage > 0 {
                        Button(action: onComplete) {
                            Text("Skip onboarding")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityHint("Skips remaining onboarding pages and starts using Murmur")
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func requestHealthKitAndComplete() {
        HapticFeedback.light.trigger()
        Task {
            await healthKit.bootstrapAuthorizations()
            await MainActor.run {
                HapticFeedback.success.trigger()
                onComplete()
            }
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 40)

                ZStack {
                    Circle()
                        .fill(page.iconColor.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: page.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(page.iconColor)
                }

                VStack(spacing: 16) {
                    Text(page.title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(page.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)

                    if !page.benefits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(page.benefits, id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(page.iconColor)
                                        .font(.body)
                                    Text(benefit)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                    }
                }

                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let benefits: [String]
}