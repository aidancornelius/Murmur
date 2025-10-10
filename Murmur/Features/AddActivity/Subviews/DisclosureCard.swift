//
//  DisclosureCard.swift
//  Murmur
//
//  Extracted from UnifiedEventView.swift on 10/10/2025.
//

import SwiftUI

/// A collapsible card component with a title, icon, and custom content
struct DisclosureCard<Content: View>: View {
    let title: String
    let icon: String
    var isExpanded: Binding<Bool>
    @ViewBuilder let content: () -> Content
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    init(title: String, icon: String, isExpanded: Binding<Bool> = .constant(true), @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.isExpanded = isExpanded
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.wrappedValue.toggle()
                    HapticFeedback.light.trigger()
                }
            }

            if isExpanded.wrappedValue {
                content()
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surfaceColor.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(palette.accentColor.opacity(0.1), lineWidth: 1)
        )
    }
}
