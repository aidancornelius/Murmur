//
//  AppearanceSettingsView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 03/10/2025.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        List {
            Section {
                Text("Colour schemes follow your device's light/dark mode setting.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(palette.surfaceColor)

            Section("Light mode palette") {
                ForEach(ColorPalette.lightPalettes) { palette in
                    PaletteRow(
                        palette: palette,
                        isSelected: appearanceManager.lightPaletteId == palette.id
                    ) {
                        appearanceManager.lightPaletteId = palette.id
                    }
                    .listRowBackground(self.palette.surfaceColor)
                    .listRowSeparator(.hidden)
                }
            }

            Section("Dark mode palette") {
                ForEach(ColorPalette.darkPalettes) { palette in
                    PaletteRow(
                        palette: palette,
                        isSelected: appearanceManager.darkPaletteId == palette.id
                    ) {
                        appearanceManager.darkPaletteId = palette.id
                    }
                    .listRowBackground(self.palette.surfaceColor)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.large)
        .themedScrollBackground()
    }
}

struct PaletteRow: View {
    let palette: ColorPalette
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Color preview
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(palette.color(for: "severity1"))
                        .frame(width: 8, height: 32)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(palette.color(for: "severity2"))
                        .frame(width: 8, height: 32)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(palette.color(for: "severity3"))
                        .frame(width: 8, height: 32)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(palette.color(for: "severity4"))
                        .frame(width: 8, height: 32)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(palette.color(for: "severity5"))
                        .frame(width: 8, height: 32)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )

                Text(palette.name)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(palette.color(for: "accent"))
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
