// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// DateFormatters.swift
// Created by Aidan Cornelius-Bell on 02/10/2025.
// Shared date formatter instances.
//
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
