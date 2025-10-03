//
//  OnboardingView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var healthKit: HealthKitAssistant
    @State private var currentPage = 0
    let onComplete: () -> Void

    private let pages = [
        OnboardingPage(
            usesLaunchIcon: true,
            icon: nil,
            imageName: nil,
            iconColor: .green,
            title: "Welcome to Murmur",
            description: "Your personal symptom tracker that understands chronic conditions. I'll help you track patterns, manage energy, and remember the details when brain fog makes things fuzzy.",
            benefits: []
        ),
        OnboardingPage(
            usesLaunchIcon: false,
            icon: nil,
            imageName: "hand1",
            iconColor: .green,
            title: "Track what matters",
            description: "Log symptoms with a tap, track activities with energy ratings, and monitor your cycle. Murmur learns your patterns to help you pace yourself.",
            benefits: [
                ("leaf.circle.fill", "Quick symptom logging (customise your own types)"),
                ("figure.walk.motion", "Activity tracking with physical, cognitive & emotional load"),
                ("moon.circle.fill", "Optional cycle tracking & reminders"),
                ("gauge.with.dots.needle.bottom.50percent", "Load score to prevent crashes")
            ]
        ),
        OnboardingPage(
            usesLaunchIcon: false,
            icon: nil,
            imageName: "hand2",
            iconColor: .purple,
            title: "Find your patterns",
            description: "Murmur analyses your data to spot triggers and trends you might miss. Voice commands mean you can log symptoms even on tough days.",
            benefits: [
                ("calendar.day.timeline.left", "Timeline view shows your day at a glance"),
                ("wand.and.stars", "Pattern analysis reveals hidden triggers"),
                ("mic.circle.fill", "Voice logging when typing is too much"),
                ("accessibility", "Full accessibility support")
            ]
        ),
        OnboardingPage(
            usesLaunchIcon: false,
            icon: nil,
            imageName: "hand3",
            iconColor: .indigo,
            title: "Your data stays private",
            description: "Everything stays on your device. Connect to Apple Health for heart rate and sleep data if you'd like – it's totally optional.",
            benefits: [
                ("lock.circle.fill", "No cloud, no accounts, just you"),
                ("heart.circle.fill", "Optional HealthKit for richer insights"),
                ("square.and.arrow.up.circle.fill", "Export your data anytime"),
                ("faceid", "Biometric app lock available")
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
                            Text("Connect to HealthKit")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.65, green: 0.725, blue: 0.549))  // #A6B98C
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .accessibilityHint("Requests permission to connect to Apple Health for enriched symptom tracking")

                    Button(action: onComplete) {
                        Text("Start without HealthKit")
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
                            Text(currentPage == 0 ? "Get started" : "Continue")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.65, green: 0.725, blue: 0.549))  // #A6B98C
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .accessibilityHint("Shows the next onboarding page")

                    if currentPage > 0 {
                        Button(action: onComplete) {
                            Text("Skip tour")
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

                if page.usesLaunchIcon {
                    // Display the launch icon image
                    Image("LaunchScreenIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .cornerRadius(20)
                } else if let imageName = page.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                } else if let icon = page.icon {
                    Image(systemName: icon)
                        .font(.system(size: 72))
                        .foregroundStyle(page.iconColor)
                        .frame(height: 120)
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
                        .padding(.horizontal, 24)

                    if !page.benefits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(page.benefits, id: \.1) { benefit in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: benefit.0)
                                        .foregroundStyle(page.iconColor)
                                        .font(.body)
                                        .frame(width: 24)
                                    Text(benefit.1)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 32)
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
    let usesLaunchIcon: Bool
    let icon: String?
    let imageName: String?
    let iconColor: Color
    let title: String
    let description: String
    let benefits: [(String, String)]  // (SF Symbol name, description)
}