import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Returns theme colors that represent a severity bucket.
    static func severityColor(for value: Double) -> Color {
        let level = max(1, min(5, Int(round(value))))
#if canImport(UIKit)
        if let uiColor = UIColor(named: "Severity\(level)") {
            return Color(uiColor)
        }
#endif
        switch level {
        case 1: return Color(hex: "#CCE5FF")
        case 2: return Color(hex: "#99D1E7")
        case 3: return Color(hex: "#E68FB7")
        case 4: return Color(hex: "#BD5780")
        case 5: return Color(hex: "#8B3B50")
        default: return Color.accentColor
        }
    }
}
