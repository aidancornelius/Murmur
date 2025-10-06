//
//  TestDataBuilder.swift
//  MurmurUITests
//
//  Created by Aidan Cornelius-Bell on 06/10/2025.
//

import Foundation

/// Test data builder for managing test scenarios and data seeding
struct TestDataBuilder {

    // MARK: - Test Scenarios

    /// Predefined test scenarios
    enum TestScenario {
        case newUser                // Fresh install, no data
        case activeUser             // Normal user with sample data
        case heavyUser              // User with large data set (1000+ entries)
        case emptyState             // User with no entries (but app configured)
        case errorState             // Data that triggers error conditions
        case minimumData            // Bare minimum data for testing
        case multipleSymptoms       // User tracking many different symptoms
        case longHistory            // User with entries spanning many months
        case recentEntries          // User with entries only from recent days
        case onboarding             // User who hasn't completed onboarding
    }

    // MARK: - Launch Arguments

    /// Get launch arguments for specific test scenario
    static func launchArguments(for scenario: TestScenario) -> [String] {
        var args = ["-UITestMode"]

        switch scenario {
        case .newUser:
            args.append("-FreshInstall")
            args.append("-EmptyState")
        case .activeUser:
            args.append("-SeedSampleData")
        case .heavyUser:
            args.append("-SeedLargeDataSet")
        case .emptyState:
            args.append("-EmptyState")
        case .errorState:
            args.append("-ErrorState")
        case .minimumData:
            args.append("-MinimumData")
        case .multipleSymptoms:
            args.append("-SeedSampleData")
            args.append("-MultipleSymptoms")
        case .longHistory:
            args.append("-SeedSampleData")
            args.append("-LongHistory")
        case .recentEntries:
            args.append("-SeedSampleData")
            args.append("-RecentOnly")
        case .onboarding:
            args.append("-ShowOnboarding")
        }

        return args
    }

    /// Get launch arguments for specific data size
    static func launchArguments(entryCount: Int) -> [String] {
        var args = ["-UITestMode"]

        switch entryCount {
        case 0:
            args.append("-EmptyState")
        case 1...50:
            args.append("-MinimumData")
        case 51...500:
            args.append("-SeedSampleData")
        default:
            args.append("-SeedLargeDataSet")
        }

        return args
    }

    // MARK: - Environment Configuration

    /// Launch arguments for specific feature flags
    static func launchArguments(featureFlags: [FeatureFlag]) -> [String] {
        var args = ["-UITestMode"]

        for flag in featureFlags {
            args.append(flag.rawValue)
        }

        return args
    }

    /// Feature flags for testing
    enum FeatureFlag: String {
        case skipOnboarding = "-SkipOnboarding"
        case disableHealthKit = "-DisableHealthKit"
        case disableLocation = "-DisableLocation"
        case disableCalendar = "-DisableCalendar"
        case disableNotifications = "-DisableNotifications"
        case enableDebugLogging = "-EnableDebugLogging"
        case simulateLowStorage = "-LowStorage"
        case simulateOffline = "-OfflineMode"
        case enableAccessibility = "-EnableAccessibility"
        case forceUpdate = "-SimulateUpdate"
    }

    // MARK: - Accessibility Configuration

    /// Launch arguments for accessibility testing
    static func accessibilityLaunchArguments(
        contentSize: ContentSizeCategory? = nil,
        boldText: Bool = false,
        reduceMotion: Bool = false,
        increaseContrast: Bool = false
    ) -> [String] {
        var args = ["-UITestMode", "-SeedSampleData"]

        if let size = contentSize {
            args.append("-UIPreferredContentSizeCategoryName")
            args.append(size.rawValue)
        }

        if boldText {
            args.append("-UIAccessibilityBoldTextEnabled")
            args.append("1")
        }

        if reduceMotion {
            args.append("-UIAccessibilityReduceMotionEnabled")
            args.append("1")
        }

        if increaseContrast {
            args.append("-UIAccessibilityDarkerSystemColorsEnabled")
            args.append("1")
        }

        return args
    }

    /// Content size categories for dynamic type testing
    enum ContentSizeCategory: String {
        case extraSmall = "UICTContentSizeCategoryXS"
        case small = "UICTContentSizeCategoryS"
        case medium = "UICTContentSizeCategoryM"
        case large = "UICTContentSizeCategoryL"
        case extraLarge = "UICTContentSizeCategoryXL"
        case extraExtraLarge = "UICTContentSizeCategoryXXL"
        case extraExtraExtraLarge = "UICTContentSizeCategoryXXXL"
        case accessibilityMedium = "UICTContentSizeCategoryAccessibilityM"
        case accessibilityLarge = "UICTContentSizeCategoryAccessibilityL"
        case accessibilityExtraLarge = "UICTContentSizeCategoryAccessibilityXL"
        case accessibilityExtraExtraLarge = "UICTContentSizeCategoryAccessibilityXXL"
        case accessibilityExtraExtraExtraLarge = "UICTContentSizeCategoryAccessibilityXXXL"
    }

    // MARK: - Locale Configuration

    /// Launch arguments for locale testing
    static func launchArguments(locale: Locale, language: String? = nil) -> [String] {
        var args = ["-UITestMode", "-SeedSampleData"]

        args.append("-AppleLocale")
        args.append(locale.identifier)

        if let language = language {
            args.append("-AppleLanguages")
            args.append("(\(language))")
        }

        return args
    }

    /// Common test locales
    static let australianLocale = Locale(identifier: "en_AU")
    static let usLocale = Locale(identifier: "en_US")
    static let ukLocale = Locale(identifier: "en_GB")

    // MARK: - Device Configuration

    /// Launch arguments for device simulation
    static func launchArguments(deviceType: DeviceType) -> [String] {
        var args = ["-UITestMode", "-SeedSampleData"]

        switch deviceType {
        case .iPhoneSE:
            args.append("-UIDeviceFamily")
            args.append("iPhone")
            args.append("-UIDeviceSize")
            args.append("SE")
        case .iPhoneStandard:
            args.append("-UIDeviceFamily")
            args.append("iPhone")
        case .iPhoneProMax:
            args.append("-UIDeviceFamily")
            args.append("iPhone")
            args.append("-UIDeviceSize")
            args.append("ProMax")
        case .iPad:
            args.append("-UIDeviceFamily")
            args.append("iPad")
        case .iPadPro:
            args.append("-UIDeviceFamily")
            args.append("iPad")
            args.append("-UIDeviceSize")
            args.append("Pro")
        }

        return args
    }

    /// Device types for testing
    enum DeviceType {
        case iPhoneSE
        case iPhoneStandard
        case iPhoneProMax
        case iPad
        case iPadPro
    }

    // MARK: - Theme Configuration

    /// Launch arguments for appearance testing
    static func launchArguments(appearance: Appearance) -> [String] {
        var args = ["-UITestMode", "-SeedSampleData"]

        switch appearance {
        case .light:
            args.append("-UIUserInterfaceStyle")
            args.append("Light")
        case .dark:
            args.append("-UIUserInterfaceStyle")
            args.append("Dark")
        case .system:
            // Let system decide
            break
        }

        return args
    }

    /// Appearance modes
    enum Appearance {
        case light
        case dark
        case system
    }

    // MARK: - Combined Configurations

    /// Create custom launch configuration
    static func customLaunchArguments(
        scenario: TestScenario = .activeUser,
        appearance: Appearance = .system,
        contentSize: ContentSizeCategory? = nil,
        featureFlags: [FeatureFlag] = [],
        locale: Locale? = nil
    ) -> [String] {
        var args = launchArguments(for: scenario)

        // Add appearance
        if appearance != .system {
            args.append("-UIUserInterfaceStyle")
            args.append(appearance == .light ? "Light" : "Dark")
        }

        // Add content size
        if let size = contentSize {
            args.append("-UIPreferredContentSizeCategoryName")
            args.append(size.rawValue)
        }

        // Add feature flags
        for flag in featureFlags {
            args.append(flag.rawValue)
        }

        // Add locale
        if let locale = locale {
            args.append("-AppleLocale")
            args.append(locale.identifier)
        }

        return args
    }

    // MARK: - Helper Methods

    /// Get launch arguments for snapshot testing
    static func snapshotLaunchArguments(locale: Locale = australianLocale) -> [String] {
        var args = ["-UITestMode", "-SeedSampleData"]
        args.append("-AppleLocale")
        args.append(locale.identifier)
        return args
    }

    /// Get launch arguments for performance testing
    static func performanceLaunchArguments() -> [String] {
        return ["-UITestMode", "-SeedLargeDataSet", "-EnablePerformanceMonitoring"]
    }

    /// Get launch arguments for regression testing
    static func regressionLaunchArguments() -> [String] {
        return ["-UITestMode", "-SeedSampleData", "-EnableDebugLogging"]
    }
}
