import SwiftUI

struct SeverityBadge: View {
    enum Precision {
        case integer
        case oneDecimal
    }

    let value: Double
    var precision: Precision

    init(value: Double, precision: Precision = .oneDecimal) {
        self.value = value
        self.precision = precision
    }

    var body: some View {
        Text(formattedValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.severityColor(for: value).opacity(0.2), in: Capsule())
            .foregroundStyle(Color.severityColor(for: value).opacity(0.9))
            .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let level = Int(round(value))
        return SeverityScale.descriptor(for: level)
    }

    private var formattedValue: String {
        switch precision {
        case .integer:
            return "\(Int(round(value)))"
        case .oneDecimal:
            return String(format: "%.1f", value)
        }
    }
}
