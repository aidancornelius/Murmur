// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ColorPalette.swift
// Created by Aidan Cornelius-Bell on 03/10/2025.
// Custom colour palette definitions for the app theme.
//
import SwiftUI

struct ColorPalette: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let background: String
    let surface: String
    let accent: String
    let severity1: String
    let severity2: String
    let severity3: String
    let severity4: String
    let severity5: String
    let reflection: String
    // Legible text colours for load indicators (good contrast on surface)
    let loadSafe: String
    let loadCaution: String
    let loadHigh: String
    let loadCritical: String

    static let lightPalettes: [ColorPalette] = [
        ColorPalette(
            id: "warm",
            name: "Warm sunset",
            background: "#FFF8F0",
            surface: "#FFFFFF",
            accent: "#FF6B35",
            severity1: "#FFE5D9",
            severity2: "#FFB4A2",
            severity3: "#E5989B",
            severity4: "#B5838D",
            severity5: "#6D6875",
            reflection: "#7BA38E",  // Soft sage green - calming contrast to warm tones
            loadSafe: "#3D8B5F",     // Warm forest green
            loadCaution: "#C67D3A", // Burnt orange
            loadHigh: "#B54D4D",    // Muted coral red
            loadCritical: "#8B3A3A" // Deep brick
        ),
        ColorPalette(
            id: "cool",
            name: "Cool blue",
            background: "#F2F2F7",
            surface: "#FFFFFF",
            accent: "#007AFF",
            severity1: "#CCE5FF",
            severity2: "#99D1E7",
            severity3: "#E68FB7",
            severity4: "#BD5780",
            severity5: "#8B3B50",
            reflection: "#5B9A8B",  // Soft teal - harmonious with blue
            loadSafe: "#2E8B6E",     // Teal green
            loadCaution: "#C4842D", // Amber
            loadHigh: "#C44D4D",    // Clear red
            loadCritical: "#9B2D2D" // Deep red
        ),
        ColorPalette(
            id: "forest",
            name: "Forest gremlin",
            background: "#F5F9F5",
            surface: "#FFFFFF",
            accent: "#2D6A4F",
            severity1: "#D8F3DC",
            severity2: "#B7E4C7",
            severity3: "#74C69D",
            severity4: "#40916C",
            severity5: "#2D6A4F",
            reflection: "#6B8E9B",  // Dusty blue-grey - gentle contrast to greens
            loadSafe: "#2D6A4F",     // Forest green (matches accent)
            loadCaution: "#A67C3D", // Earthy ochre
            loadHigh: "#9B5A5A",    // Muted wine
            loadCritical: "#7A3D3D" // Dark burgundy
        ),
        ColorPalette(
            id: "lavender",
            name: "Emu flower",
            background: "#F9F7FF",
            surface: "#FFFFFF",
            accent: "#9D4EDD",
            severity1: "#E0AAFF",
            severity2: "#C77DFF",
            severity3: "#9D4EDD",
            severity4: "#7B2CBF",
            severity5: "#5A189A",
            reflection: "#7BA38E",  // Soft sage - complementary to purple
            loadSafe: "#4A8B6E",     // Sage green
            loadCaution: "#B8862D", // Golden amber
            loadHigh: "#A84D6A",    // Berry
            loadCritical: "#8B2E50" // Deep magenta
        ),
        ColorPalette(
            id: "peach",
            name: "Peach",
            background: "#FFF5F0",
            surface: "#FFFFFF",
            accent: "#FF9B85",
            severity1: "#FFD6CC",
            severity2: "#FFBAA8",
            severity3: "#FF9B85",
            severity4: "#E67E68",
            severity5: "#C96850",
            reflection: "#88A99B",  // Soft seafoam - cooling balance to warm peach
            loadSafe: "#4A9B7A",     // Seafoam green
            loadCaution: "#D4853A", // Warm amber
            loadHigh: "#C45A4A",    // Terracotta
            loadCritical: "#A33D3D" // Deep rust
        )
    ]

    static let darkPalettes: [ColorPalette] = [
        ColorPalette(
            id: "oled",
            name: "Pure black",
            background: "#000000",
            surface: "#111111",
            accent: "#0A84FF",
            severity1: "#1A3A52",
            severity2: "#2E5C7A",
            severity3: "#8B4E6F",
            severity4: "#A23B5E",
            severity5: "#B8304F",
            reflection: "#4A8B7C",  // Muted teal - visible but calm on dark
            loadSafe: "#4ADE80",     // Bright mint green
            loadCaution: "#FBBF24", // Bright amber
            loadHigh: "#F87171",    // Coral red
            loadCritical: "#EF4444" // Bright red
        ),
        ColorPalette(
            id: "royal",
            name: "Royal purple",
            background: "#1A0B2E",
            surface: "#2E1A4F",
            accent: "#9D4EDD",
            severity1: "#3A1F5D",
            severity2: "#4F2D7F",
            severity3: "#7B3FA3",
            severity4: "#9D4EDD",
            severity5: "#C77DFF",
            reflection: "#5B9A8B",  // Soft teal - elegant contrast to purple
            loadSafe: "#6EE7B7",     // Soft mint
            loadCaution: "#FCD34D", // Soft gold
            loadHigh: "#FDA4AF",    // Soft rose
            loadCritical: "#FB7185" // Bright rose
        )
    ]

    func color(for key: String) -> Color {
        switch key {
        case "background": return Color(hex: background)
        case "surface": return Color(hex: surface)
        case "accent": return Color(hex: accent)
        case "severity1": return Color(hex: severity1)
        case "severity2": return Color(hex: severity2)
        case "severity3": return Color(hex: severity3)
        case "severity4": return Color(hex: severity4)
        case "severity5": return Color(hex: severity5)
        case "reflection": return Color(hex: reflection)
        case "loadSafe": return Color(hex: loadSafe)
        case "loadCaution": return Color(hex: loadCaution)
        case "loadHigh": return Color(hex: loadHigh)
        case "loadCritical": return Color(hex: loadCritical)
        default: return .clear
        }
    }

    var backgroundColor: Color { color(for: "background") }
    var surfaceColor: Color { color(for: "surface") }
    var accentColor: Color { color(for: "accent") }
    var reflectionColor: Color { color(for: "reflection") }
}

@MainActor
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    @Published var lightPaletteId: String {
        didSet {
            UserDefaults.standard.set(lightPaletteId, forKey: UserDefaultsKeys.lightPaletteId)
        }
    }

    @Published var darkPaletteId: String {
        didSet {
            UserDefaults.standard.set(darkPaletteId, forKey: UserDefaultsKeys.darkPaletteId)
        }
    }

    private init() {
        self.lightPaletteId = UserDefaults.standard.string(forKey: UserDefaultsKeys.lightPaletteId) ?? "warm"
        self.darkPaletteId = UserDefaults.standard.string(forKey: UserDefaultsKeys.darkPaletteId) ?? "oled"
    }

    var currentLightPalette: ColorPalette {
        ColorPalette.lightPalettes.first { $0.id == lightPaletteId } ?? ColorPalette.lightPalettes[0]
    }

    var currentDarkPalette: ColorPalette {
        ColorPalette.darkPalettes.first { $0.id == darkPaletteId } ?? ColorPalette.darkPalettes[0]
    }

    func currentPalette(for colorScheme: ColorScheme) -> ColorPalette {
        colorScheme == .dark ? currentDarkPalette : currentLightPalette
    }

    // Static helper that doesn't require MainActor
    nonisolated static func palette(for colorScheme: ColorScheme) -> ColorPalette {
        let lightId = UserDefaults.standard.string(forKey: UserDefaultsKeys.lightPaletteId) ?? "warm"
        let darkId = UserDefaults.standard.string(forKey: UserDefaultsKeys.darkPaletteId) ?? "oled"

        if colorScheme == .dark {
            return ColorPalette.darkPalettes.first { $0.id == darkId } ?? ColorPalette.darkPalettes[0]
        } else {
            return ColorPalette.lightPalettes.first { $0.id == lightId } ?? ColorPalette.lightPalettes[0]
        }
    }
}
