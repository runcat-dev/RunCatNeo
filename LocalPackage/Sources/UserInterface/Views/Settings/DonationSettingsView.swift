/*
 DonationSettingsView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/08.
 Copyright 2026 Koyme22 (Takuto Nakamura)

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import DataSource
import Model
import StoreKit
import SwiftUI

struct DonationSettingsView: View {
    @StateObject var store: DonationSettings
    @State private var storeKitError: StoreKitError?
    @State private var hasDonated = false
    @State private var didDonate = false

    private let termsOfServiceURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyPolicyURL = URL(string: "https://runcat-dev.github.io/RunCatNeo/privacy_policy.html")!
    private let manageSubscriptionsURL = URL(string: "itms-apps://apps.apple.com/account/subscriptions")!

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("donationIntro", bundle: .module)
            HStack(alignment: .top, spacing: 18) {
                continuousSupportColumn
                Divider()
                oneTimeDonationColumn
            }
            .disabled(storeKitError != nil)
            .opacity(storeKitError == nil ? 1 : 0.5)
            .overlay(alignment: .top) {
                donationUnavailableOverlay
            }
            .storeProductsTask(for: Donation.Product.allCases.map(\.id)) { taskState in
                if case let .failure(error) = taskState {
                    presentError(error)
                }
            }
            legalLinks
        }
        .padding()
        .task {
            await store.send(.task(String(describing: Self.self)))
        }
    }

    private var continuousSupportColumn: some View {
        VStack(alignment: .leading) {
            Text("continuousSupport", bundle: .module)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ProductView(id: Donation.Product.yearly.id, prefersPromotionalIcon: true) {
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .productIconBorder()
            }
            .tint(.accentColor)
            .subscriptionStatusTask(for: Donation.groupID) { taskState in
                hasDonated = taskState.value?.map(\.state)
                    .contains { [.subscribed, .inGracePeriod].contains($0) } == true
            }
            if hasDonated {
                Text("thankYouSupporting", bundle: .module)
                    .foregroundStyle(.secondary)
                Link(destination: manageSubscriptionsURL) {
                    Text("manageSubscription", bundle: .module)
                }
                .textScale(.secondary)
            } else {
                Button {
                    Task {
                        await restorePurchases()
                    }
                } label: {
                    Text("restoreSubscription", bundle: .module)
                }
                .buttonStyle(.link)
                .textScale(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var oneTimeDonationColumn: some View {
        VStack(alignment: .leading) {
            Text("oneTimeDonation", bundle: .module)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ProductView(id: Donation.Product.onetime.id, prefersPromotionalIcon: true) {
                Image(systemName: "mug.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                    .productIconBorder()
            }
            .productViewStyle(OnetimeProductViewStyle(
                purchaseCompleted: { didDonate = true },
                purchaseFailed: { presentError($0, disablesDonation: false) }
            ))
            .tint(.accentColor)
            if didDonate {
                Text("thankYouDonation", bundle: .module)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var donationUnavailableOverlay: some View {
        if let storeKitError {
            VStack {
                Text("donationUnavailable", bundle: .module)
                Group {
                    switch storeKitError {
                    case .networkError:
                        Text("donationNetworkError", bundle: .module)
                    default:
                        Text(storeKitError.localizedDescription)
                    }
                }
                .foregroundStyle(.secondary)
                .textScale(.secondary)
            }
            .accessibilityElement(children: .contain)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                .background.shadow(.drop(radius: 3, y: 1.5)),
                in: .rect(cornerRadius: 8)
            )
            .offset(y: 40)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 8) {
            Link(destination: termsOfServiceURL) {
                Text("termsOfService", bundle: .module)
            }
            Link(destination: privacyPolicyURL) {
                Text("privacyPolicy", bundle: .module)
            }
        }
        .font(.footnote)
        .tint(.accentColor)
        .foregroundStyle(.secondary)
    }

    private func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            presentError(error, disablesDonation: false)
        }
    }

    private func presentError(_ error: any Error, disablesDonation: Bool = true) {
        switch error {
        case StoreKitError.userCancelled:
            break
        case let error as StoreKitError where disablesDonation:
            storeKitError = error
        default:
            Task {
                await store.send(.donationFailed(error))
            }
        }
    }
}

private struct OnetimeProductViewStyle: ProductViewStyle {
    var purchaseCompleted: () -> Void
    var purchaseFailed: (any Error) -> Void

    @State private var quantity = 1

    func makeBody(configuration: Configuration) -> some View {
        switch configuration.state {
        case let .success(product):
            successView(product: product, icon: configuration.icon)
        default:
            ProductView(configuration)
        }
    }

    private func successView(product: Product, icon: ProductViewStyleConfiguration.Icon) -> some View {
        HStack(alignment: .top, spacing: 10) {
            icon
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: .zero) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(product.displayName)
                        .fixedSize()
                    Text("multiply\(quantity)", bundle: .module)
                        .monospacedDigit()
                        .frame(minWidth: 28, alignment: .trailing)
                    Stepper(value: $quantity, in: 1...99, label: EmptyView.init)
                        .accessibilityLabel(Text("quantity", bundle: .module))
                        .accessibilityValue("\(quantity)")
                }
                Text(product.description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task {
                        await purchase(product)
                    }
                } label: {
                    Text(product.price * Decimal(quantity), format: product.priceFormatStyle)
                        .font(.system(size: 11))
                }
                .monospacedDigit()
                .padding(.top, 6)
                .contentTransition(.numericText())
                .animation(.default, value: quantity)
            }
            .accessibilityElement(children: .contain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase(options: [.quantity(quantity)])
            switch result {
            case let .success(verificationResult):
                switch verificationResult {
                case let .verified(transaction):
                    await transaction.finish()
                    purchaseCompleted()
                case let .unverified(transaction, verificationError):
                    await transaction.finish()
                    throw verificationError
                }
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseFailed(error)
        }
    }
}

extension DonationSettings: ObservableObject {}
