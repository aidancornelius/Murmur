//
//  TipJarView.swift
//  Murmur
//
//  Created by Aidan Cornelius-Bell on 02/10/2025.
//

import SwiftUI
import StoreKit

struct TipJarView: View {
    @StateObject private var store = StoreManager()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appearanceManager: AppearanceManager
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ColorPalette {
        appearanceManager.currentPalette(for: colorScheme)
    }

    var body: some View {
        VStack(spacing: 24) {
            if case .purchased = store.purchaseState {
                thankYouView
            } else {
                tipJarContent
            }
        }
        .padding()
        .navigationTitle("Support Murmur")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tipJarContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(palette.accentColor)
                .padding(.top, 40)

            VStack(spacing: 12) {
                Text("Found Murmur useful?")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Support Murmur’s development with a tip. Your support helps me pay the bills while I develop the app, and enables me to keep it free and privacy-focused.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if !store.products.isEmpty {
                VStack(spacing: 16) {
                    ForEach(store.products.sorted(by: { $0.price < $1.price }), id: \.id) { product in
                        tipButton(for: product)
                    }

                    if store.purchaseState == .purchasing {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }

                    if case .failed(let error) = store.purchaseState {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)
            } else {
                ProgressView()
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func tipButton(for product: Product) -> some View {
        Button(action: {
            Task {
                await store.purchase(product)
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(product.displayName)
                        .font(.headline)
                    Spacer()
                    Text(product.displayPrice)
                        .font(.headline)
                }
                // Products in StoreKit Configuration have descriptions in localizations
                if product.id == "com.murmur.tip.small" {
                    Text("Support Murmur's development with a small tip")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                } else if product.id == "com.murmur.tip.generous" {
                    Text("Generous support for Murmur's development")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundForProduct(product))
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
        .disabled(store.purchaseState == .purchasing)
    }

    @ViewBuilder
    private func backgroundForProduct(_ product: Product) -> some View {
        if product.id == "com.murmur.tip.generous" {
            LinearGradient(colors: [palette.accentColor, palette.accentColor.opacity(0.8)],
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing)
        } else {
            palette.accentColor
        }
    }

    private var thankYouView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(palette.accentColor)
                .padding(.top, 60)

            VStack(spacing: 12) {
                Text("Thank you so much!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Your kind support means the world and helps keep Murmur free and privacy-focused for everyone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                dismiss()
            }) {
                Text("Done")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top, 20)

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                store.resetPurchaseState()
            }
        }
    }
}

#Preview {
    NavigationStack {
        TipJarView()
    }
    .environmentObject(AppearanceManager.shared)
}
