//
//  SwitchControlSupport.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI

// MARK: - Switch Control Support
/// Provides optimised navigation and focus management for Switch Control users

extension View {
    /// Enhances views with clear focus indicators for Switch Control
    func switchControlOptimised() -> some View {
        self
            .accessibilityElement(children: .combine)
            .modifier(FocusIndicatorModifier())
    }

    /// Adds enhanced focus highlighting for Switch Control
    func enhancedFocusIndicator(isImportant: Bool = false) -> some View {
        self.modifier(FocusIndicatorModifier(isImportant: isImportant))
    }

    /// Provides simplified navigation path for Switch Control users
    func simplifiedSwitchControlPath() -> some View {
        self
            .accessibilityElement(children: .contain)
            .accessibilitySortPriority(1)
    }

    /// Groups related elements for easier Switch Control navigation
    func switchControlGroup(label: String) -> some View {
        self
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
    }
}

struct FocusIndicatorModifier: ViewModifier {
    @AccessibilityFocusState private var isFocused: Bool
    var isImportant: Bool = false

    func body(content: Content) -> some View {
        content
            .accessibilityFocused($isFocused)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(focusColor, lineWidth: isFocused ? 3 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            )
            .scaleEffect(isFocused && isImportant ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isFocused)
    }

    private var focusColor: Color {
        isImportant ? .blue : .accentColor
    }
}

// MARK: - Navigation Shortcuts for Switch Control
struct AccessibilityActionModifier: ViewModifier {
    let actions: [(String, () -> Void)]

    func body(content: Content) -> some View {
        var modifiedContent = AnyView(content)

        for (label, action) in actions {
            modifiedContent = AnyView(
                modifiedContent
                    .accessibilityAction(named: Text(label)) {
                        action()
                    }
            )
        }

        return modifiedContent
    }
}

extension View {
    /// Adds multiple custom accessibility actions for Switch Control users
    func withAccessibilityActions(_ actions: [(String, () -> Void)]) -> some View {
        modifier(AccessibilityActionModifier(actions: actions))
    }
}

// MARK: - Simplified Forms for Switch Control
struct SimplifiedFormButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var isDestructive: Bool = false
    var isImportant: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 40)
                    .foregroundStyle(isDestructive ? .red : .primary)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(isDestructive ? .red : .primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .enhancedFocusIndicator(isImportant: isImportant)
        .accessibilityLabel(title)
        .accessibilityHint(isDestructive ? "Warning: This is a destructive action" : "")
    }
}

// MARK: - AssistiveTouch Gesture Support
/// Provides simplified gestures that work well with AssistiveTouch

struct AssistiveTouchGesture<Content: View>: View {
    let content: Content
    let onTap: (() -> Void)?
    let onLongPress: (() -> Void)?
    let onDoubleTap: (() -> Void)?

    init(
        @ViewBuilder content: () -> Content,
        onTap: (() -> Void)? = nil,
        onLongPress: (() -> Void)? = nil,
        onDoubleTap: (() -> Void)? = nil
    ) {
        self.content = content()
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.onDoubleTap = onDoubleTap
    }

    var body: some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                onDoubleTap?()
            }
            .onTapGesture {
                onTap?()
            }
            .onLongPressGesture {
                onLongPress?()
            }
            .accessibilityElement(children: .combine)
            .withAccessibilityActions(buildActions())
    }

    private func buildActions() -> [(String, () -> Void)] {
        var actions: [(String, () -> Void)] = []

        if let onTap = onTap {
            actions.append(("Tap", onTap))
        }

        if let onLongPress = onLongPress {
            actions.append(("Long press", onLongPress))
        }

        if let onDoubleTap = onDoubleTap {
            actions.append(("Double tap", onDoubleTap))
        }

        return actions
    }
}

// MARK: - Large Touch Targets
struct LargeTouchTarget<Content: View>: View {
    let minimumSize: CGFloat
    let content: Content

    init(minimumSize: CGFloat = 44, @ViewBuilder content: () -> Content) {
        self.minimumSize = minimumSize
        self.content = content()
    }

    var body: some View {
        content
            .frame(minWidth: minimumSize, minHeight: minimumSize)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Ensures the view has a minimum touch target size for accessibility
    func largeTouchTarget(minimumSize: CGFloat = 44) -> some View {
        LargeTouchTarget(minimumSize: minimumSize) {
            self
        }
    }
}

// MARK: - Accessibility-Optimised Navigation
struct AccessibleNavigationLink<Destination: View>: View {
    let title: String
    let icon: String
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 40)
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .enhancedFocusIndicator()
        .accessibilityLabel(title)
        .accessibilityHint("Opens \(title.lowercased())")
    }
}

// MARK: - Accessibility Preferences
struct AccessibilityPreferences {
    @MainActor
    static var isSwitchControlEnabled: Bool {
        UIAccessibility.isSwitchControlRunning
    }

    @MainActor
    static var isVoiceOverEnabled: Bool {
        UIAccessibility.isVoiceOverRunning
    }

    @MainActor
    static var isAssistiveTouchEnabled: Bool {
        UIAccessibility.isAssistiveTouchRunning
    }

    @MainActor
    static var shouldUseSimplifiedUI: Bool {
        isSwitchControlEnabled || isAssistiveTouchEnabled
    }

    @MainActor
    static var shouldUseLargeTouchTargets: Bool {
        isAssistiveTouchEnabled || UIAccessibility.isShakeToUndoEnabled
    }
}

// MARK: - Adaptive UI Based on Accessibility Settings
struct AdaptiveAccessibilityContainer<Content: View>: View {
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .dynamicTypeSize(AccessibilityPreferences.shouldUseSimplifiedUI ? .large...(.accessibility5) : .medium...(.xxxLarge))
    }
}

extension View {
    func adaptiveAccessibility() -> some View {
        AdaptiveAccessibilityContainer {
            self
        }
    }
}
