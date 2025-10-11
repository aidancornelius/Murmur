//
//  ColorPalette.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 03/10/2025.
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
            severity5: "#6D6875"
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
            severity5: "#8B3B50"
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
            severity5: "#2D6A4F"
        ),
        ColorPalette(
            id: "lavender",
            name: "Lavender fields",
            background: "#F9F7FF",
            surface: "#FFFFFF",
            accent: "#9D4EDD",
            severity1: "#E0AAFF",
            severity2: "#C77DFF",
            severity3: "#9D4EDD",
            severity4: "#7B2CBF",
            severity5: "#5A189A"
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
            severity5: "#C96850"
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
            severity5: "#B8304F"
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
            severity5: "#C77DFF"
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
        default: return .clear
        }
    }

    var backgroundColor: Color { color(for: "background") }
    var surfaceColor: Color { color(for: "surface") }
    var accentColor: Color { color(for: "accent") }
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
