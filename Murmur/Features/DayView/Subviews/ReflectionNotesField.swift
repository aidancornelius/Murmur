//
//  ReflectionNotesField.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 04/12/2025.
//

import SwiftUI

/// A minimal, expandable text field for reflection notes
/// Designed to feel optional and low-pressure
struct ReflectionNotesField: View {
    @Binding var text: String
    let tint: Color
    let onCommit: () -> Void

    @FocusState private var isFocused: Bool

    init(text: Binding<String>, tint: Color, onCommit: @escaping () -> Void = {}) {
        self._text = text
        self.tint = tint
        self.onCommit = onCommit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "pencil.line")
                    .font(.caption)
                    .foregroundStyle(tint.opacity(0.7))

                Text("Anything else on your mind?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(12)
                .background(tint.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? tint.opacity(0.4) : tint.opacity(0.12), lineWidth: 1)
                )
                .focused($isFocused)
                .onChange(of: isFocused) { _, newValue in
                    if !newValue {
                        // Save when focus is lost
                        onCommit()
                    }
                }
                .submitLabel(.done)
                .onSubmit {
                    isFocused = false
                    onCommit()
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reflection notes")
        .accessibilityValue(text.isEmpty ? "Empty" : text)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text1 = ""
        @State private var text2 = "Difficult phone call with mum this afternoon. Felt it in my shoulders for hours afterwards."

        var body: some View {
            VStack(spacing: 32) {
                ReflectionNotesField(
                    text: $text1,
                    tint: Color(hex: "#7BA38E")
                )

                ReflectionNotesField(
                    text: $text2,
                    tint: Color(hex: "#5B9A8B")
                )
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
