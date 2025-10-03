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
}
