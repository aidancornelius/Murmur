import Foundation

/// Centralised date formatters for consistent formatting throughout the application.
enum DateFormatters {
    /// Short time formatter (e.g., "2:30 PM").
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// Short date formatter (e.g., "1 Oct 2025").
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
