
import Foundation
import StoreKit
import Combine
import SwiftUI

@MainActor
final class TipJarStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published var isLoading = false
    @Published var message: String?

    private let productIDs = [
        "com.jatin.blueassist.tip.small",
        "com.jatin.blueassist.tip.medium",
        "com.jatin.blueassist.tip.large"
    ]

    func loadProducts() async {
        isLoading = true
        message = nil

        do {
            print("Loading StoreKit products:")
            productIDs.forEach { print("• \($0)") }

            let fetchedProducts = try await Product.products(for: productIDs)

            print("Fetched \(fetchedProducts.count) StoreKit product(s).")

            products = fetchedProducts.sorted { first, second in
                first.price < second.price
            }

            if products.isEmpty {
                message = "Tips are not available right now."
                print("No products loaded. Check StoreKit config, scheme setting, product IDs, and IAP capability.")
            }
        } catch {
            message = "Could not load tips: \(error.localizedDescription)"
            print("StoreKit load error:", error)
        }

        isLoading = false
    }

    func buy(_ product: Product) async {
        message = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try checkVerified(verificationResult)

                await transaction.finish()

                message = "Thank you for supporting BlueAssistMac 🫶"

            case .userCancelled:
                message = "Purchase cancelled."

            case .pending:
                message = "Purchase is pending approval."

            @unknown default:
                message = "Something unexpected happened."
            }
        } catch {
            message = "Purchase failed: \(error.localizedDescription)"
        }
    }

    private func checkVerified<T>(
        _ result: VerificationResult<T>
    ) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification

        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}


struct TipJarView: View {
    @StateObject private var store = TipJarStore()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BlueAssistBackground()

            VStack(alignment: .leading, spacing: 22) {
                header

                if store.isLoading {
                    loadingCard
                } else if store.products.isEmpty {
                    unavailableCard
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(store.products, id: \.id) { product in
                                TipProductRow(product: product) {
                                    Task {
                                        await store.buy(product)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }

                footer

                if let message = store.message {
                    messageCard(message)
                }
            }
            .padding(28)
        }
        .frame(width: 640, height: 560)
        .task {
            await store.loadProducts()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Support BlueAssistMac")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tips are optional and do not unlock features. BlueAssistMac stays free for everyone.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

            Spacer(minLength: 20)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()

            Text("Loading tip options...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueGlassPanel(cornerRadius: 22, padding: 18)
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tips are not available right now", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)

            Text("Check your StoreKit configuration file, product IDs, and scheme settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueGlassPanel(cornerRadius: 22, padding: 18)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No features are locked behind tips", systemImage: "lock.open.fill")
                .font(.subheadline.bold())

            Text("This is just a small support jar for development, debugging, and overall engineering behind this app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueGlassPanel(cornerRadius: 20, padding: 16)
    }

    private func messageCard(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .blueGlassPanel(cornerRadius: 18, padding: 14)
    }
}

struct TipProductRow: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.pink.opacity(0.16))
                    .frame(width: 54, height: 54)

                Image(systemName: "heart.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.pink)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(product.displayName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 20)

            Button {
                action()
            } label: {
                Text(product.displayPrice)
                    .font(.headline)
                    .frame(minWidth: 92)
            }
            .buttonStyle(.plain)
            .blueGlassControl(prominent: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueGlassPanel(cornerRadius: 24, padding: 18)
    }

    private var subtitle: String {
        if !product.description.isEmpty {
            return product.description
        }

        switch product.id {
        case "com.jatin.blueassist.tip.small":
            return "A tiny thank-you for keeping BlueAssistMac alive."
        case "com.jatin.blueassist.tip.medium":
            return "Helps support more fixes and polish."
        case "com.jatin.blueassist.tip.large":
            return "Big support for the project."
        default:
            return "Optional support for BlueAssistMac."
        }
    }
}
