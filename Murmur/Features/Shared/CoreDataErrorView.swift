// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// CoreDataErrorView.swift
// Created by Aidan Cornelius-Bell on 03/10/2025.
// Error view displayed when Core Data fails to load.
//
import SwiftUI

struct CoreDataErrorView: View {
    let error: Error

    private var errorDescription: String {
        if let coreDataError = error as? CoreDataStack.CoreDataError {
            return coreDataError.localizedDescription
        }
        return error.localizedDescription
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Data storage error")
                .font(.title)
                .fontWeight(.semibold)

            Text(errorDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Text("Please try:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Force quit and restart the app", systemImage: "arrow.clockwise")
                    Label("Free up storage space", systemImage: "internaldrive")
                    Label("Update to the latest version", systemImage: "arrow.down.circle")
                }
                .font(.callout)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)

            Button(action: {
                // Attempt to restart the app
                exit(0)
            }) {
                Text("Restart app")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}