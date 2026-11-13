/*
 InAppPurchaseDonationView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/11/13.
 Copyright 2026 Kyome22 (Takuto Nakamura)

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

struct InAppPurchaseDonationView: View {
    @Bindable var store: DonationSettings

    var body: some View {
        Form {
            Section {
                DonationDescriptionView()
            }
            Section {
                ProductView(id: DonationProduct.oneTime.id, prefersPromotionalIcon: true) {
                    Image(systemName: "mug.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                        .productIconBorder()
                }
                .tint(.accentColor)
            } header: {
                Text("oneTimeDonation", bundle: .module)
            } footer: {
                if store.isPurchased {
                    Text("thankYouDonation", bundle: .module)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ProductView(id: DonationProduct.yearly.id, prefersPromotionalIcon: true) {
                    Image(.cocoaPowder)
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                        .productIconBorder()
                }
                .tint(.accentColor)
            } header: {
                Text("continuousSupport", bundle: .module)
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    if store.isSubscribed {
                        Text("thankYouSupporting", bundle: .module)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if store.isSubscribed {
                            Link(destination: URL.manageSubscriptions) {
                                Text("manageSubscription", bundle: .module)
                            }
                        } else {
                            Button {
                                Task { await store.send(.restoreSubscriptionButtonTapped) }
                            } label: {
                                Text("restoreSubscription", bundle: .module)
                            }
                            .buttonStyle(.link)
                        }
                        Link(destination: URL.termsOfService) {
                            Text("termsOfService", bundle: .module)
                        }
                        Link(destination: URL.privacyPolicy) {
                            Text("privacyPolicy", bundle: .module)
                        }
                    }
                    .textScale(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .alert(
            isPresented: $store.showingAlert,
            error: store.error,
            actions: { _ in },
            message: { _ in }
        )
        .storeProductsTask(for: DonationProduct.allCases.map(\.id)) { taskState in
            await store.send(.productTaskStateChanged(taskState))
        }
        .onInAppPurchaseCompletion { product, result in
            await store.send(.purchaseResponse(product, result))
        }
        .subscriptionStatusTask(for: store.subscriptionGroupID) { taskState in
            await store.send(.subscriptionTaskStateChanged(taskState))
        }
    }
}

