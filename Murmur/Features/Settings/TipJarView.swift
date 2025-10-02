import SwiftUI
import StoreKit

struct TipJarView: View {
    @StateObject private var store = StoreManager()
    @Environment(\.dismiss) private var dismiss

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
                .foregroundStyle(.pink)
                .padding(.top, 40)

            VStack(spacing: 12) {
                Text("Found Murmur useful?")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Support Murmur's development with a small tip. Your support helps keep this app free and privacy-focused.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let product = store.products.first {
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            await store.purchase(product)
                        }
                    }) {
                        HStack {
                            Text("Send a tip")
                            Spacer()
                            Text(product.displayPrice)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(store.purchaseState == .purchasing)

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

    private var thankYouView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                store.resetPurchaseState()
            }
        }
    }
}

#Preview {
    NavigationStack {
        TipJarView()
    }
}
