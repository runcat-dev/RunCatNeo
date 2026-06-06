/*
 MetricsSettingsView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/23.
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
import Foundation
import Model
import SwiftUI

struct MetricsSettingsView: View {
    @StateObject var store: MetricsSettings

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding<Bool>(
                    get: { store.systemMetricsConfiguration.monitorsMemory },
                    asyncSet: { await store.send(.monitorsSystemInfoToggleSwitched(.memory, $0)) }
                )) {
                    Text("enableMemoryPressureMonitoring", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.systemMetricsConfiguration.monitorsStorage },
                    asyncSet: { await store.send(.monitorsSystemInfoToggleSwitched(.storage, $0)) }
                )) {
                    Text("enableStorageCapacityMonitoring", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.systemMetricsConfiguration.monitorsBattery },
                    asyncSet: { await store.send(.monitorsSystemInfoToggleSwitched(.battery, $0)) }
                )) {
                    Text("enableBatteryStatusMonitoring", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.systemMetricsConfiguration.monitorsNetwork },
                    asyncSet: { await store.send(.monitorsSystemInfoToggleSwitched(.network, $0)) }
                )) {
                    Text("enableNetworkConnectivityMonitoring", bundle: .module)
                }
            } header: {
                Text("systemInfo", bundle: .module)
            }
            Section {
                if store.customMetricsSources.isEmpty {
                    Text("noCustomMetricsSources", bundle: .module)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.customMetricsSources) { source in
                        CustomMetricsSourceRowView(
                            source: source,
                            isErrorDetected: store.failedCustomMetricsSourceIDs.contains(source.id),
                            removeButtonTapped: {
                                await store.send(.removeCustomMetricsSourceButtonTapped(source.id))
                            },
                            sourceLinkTapped: {
                                await store.send(.customMetricsSourceLinkTapped(source))
                            }
                        )
                    }
                }
                HStack {
                    Spacer()
                    Button {
                        Task {
                            await store.send(.addCustomMetricsSourceButtonTapped)
                        }
                    } label: {
                        Label {
                            Text("addCustomMetricsSource", bundle: .module)
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                }
            } header: {
                Text("customMetrics", bundle: .module)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("customMetricsDescription", bundle: .module)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = store.customMetricsSchemaURL {
                        Link(destination: url) {
                            Text("viewJsonSchemaAndSamples", bundle: .module)
                                .font(.caption)
                        }
                    }
                }
                .frame(maxWidth: 360, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .fixedSize()
        .fileImporter(
            isPresented: $store.showingFileImporter,
            allowedContentTypes: [.json],
            onCompletion: { result in
                Task {
                    await store.send(.onCompletionFileImporter(result))
                }
            }
        )
        .fileDialogMessage(Text("addingCustomMetricsSourceMessage", bundle: .module))
        .fileDialogConfirmationLabel(Text("addingCustomMetricsSourcePrompt", bundle: .module))
        .confirmationDialog(
            Text("removingCustomMetricsConfirmationTitle", bundle: .module),
            isPresented: $store.showingConfirmationDialog,
            presenting: store.pendingRemovalSourceID,
            actions: { sourceID in
                Button(role: .destructive) {
                    Task {
                        await store.send(.removingCustomMetricsSourceConfirmed)
                    }
                } label: {
                    Text("remove", bundle: .module)
                }
                Button(role: .cancel) {
                    Task {
                        await store.send(.removingCustomMetricsSourceCancelled)
                    }
                } label: {
                    Text("cancel", bundle: .module)
                }
            },
            message: { _ in
                Text("removingCustomMetricsConfirmationMessage", bundle: .module)
            }
        )
        .task {
            await store.send(.task(String(describing: Self.self)))
        }
        .onDisappear {
            Task {
                await store.send(.onDisappear)
            }
        }
    }
}

extension MetricsSettings: ObservableObject {}
