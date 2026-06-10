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

    var body: some View {
        Form {
            Section {
                Label {
                    Text("donationDescription", bundle: .module)
                } icon: {
                    Image(nsImage: NSImage(named: NSImage.applicationIconName)!)
                        .resizable()
                        .scaledToFit()
                }
                .labelReservedIconWidth(32)
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
                if store.didCompleteOneTimeDonation {
                    Text("thankYouDonation", bundle: .module)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ProductView(id: DonationProduct.yearly.id, prefersPromotionalIcon: true) {
                    Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                        .productIconBorder()
                }
                .subscriptionStatusTask(for: store.subscriptionGroupID) { taskState in
                    store.isSubscribed = taskState.value?.map(\.state)
                        .contains { [.subscribed, .inGracePeriod].contains($0) } == true
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
        .task {
            await store.send(.task(String(describing: Self.self)))
        }
        .storeProductsTask(for: DonationProduct.allCases.map(\.id)) { taskState in
            await store.send(.onReceiveProductTaskState(taskState))
        }
    }
}

extension DonationSettings: ObservableObject {}

