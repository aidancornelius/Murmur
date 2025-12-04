// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// AppearanceSettingsView.swift
// Created by Aidan Cornelius-Bell on 03/10/2025.
// Settings view for appearance and theme options.
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
                    .listRowBackground(Color.clear)
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
