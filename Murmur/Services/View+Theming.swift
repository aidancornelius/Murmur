import SwiftUI

struct ThemedSurfaceModifier: ViewModifier {
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(palette.backgroundColor.ignoresSafeArea())
            .toolbarBackground(palette.backgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(colorScheme == .dark ? .light : .dark, for: .navigationBar)
            .tint(palette.accentColor)
    }

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }
}

struct ThemedScrollBackgroundModifier: ViewModifier {
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(palette.backgroundColor.ignoresSafeArea())
            .listRowBackground(palette.surfaceColor)
            .toolbarBackground(.automatic, for: .navigationBar)
            .tint(palette.accentColor)
    }

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }
}

struct ThemedFormModifier: ViewModifier {
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        ZStack {
            // Background layer with theme color
            palette.backgroundColor
                .ignoresSafeArea()

            // Form content with hidden background
            content
                .scrollContentBackground(.hidden)
                .tint(palette.accentColor)
                .formStyle(.grouped)
                .toolbarBackground(.automatic, for: .navigationBar)
                .environment(\.defaultMinListRowHeight, 44)
        }
    }

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }
}

struct ThemedFormSectionModifier: ViewModifier {
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .listRowBackground(palette.surfaceColor)
            .foregroundColor(.primary)
    }

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }
}

extension View {
    func themedSurface() -> some View {
        modifier(ThemedSurfaceModifier())
    }

    func themedScrollBackground() -> some View {
        modifier(ThemedScrollBackgroundModifier())
    }

    func themedForm() -> some View {
        modifier(ThemedFormModifier())
    }

    func themedFormSection() -> some View {
        modifier(ThemedFormSectionModifier())
    }
}
