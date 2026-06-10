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

import Model
import SwiftUI

struct MetricsSettingsView: View {
    @StateObject var store: MetricsSettings

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding<Bool>(
                    get: { store.showsMetricsBar },
                    asyncSet: { await store.send(.showMetricsBarToggleSwitched($0)) }
                )) {
                    Text("showMetricsBar", bundle: .module)
                }
                .sheet(isPresented: $store.showingMetricsBarNotesSheet) {
                    MetricsBarNotesView(store: store)
                }
            } header: {
                Text("metricsBar", bundle: .module)
            }
            Section {
                Toggle(isOn: Binding<Bool>(
                    get: { store.systemMetricsConfiguration.monitorsMemory },
                    asyncSet: { await store.send(.monitorsSystemMetricsToggleSwitched(.memory, $0)) }
                )) {
                    Text("enableMemoryPressureMonitoring", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.systemMetricsConfiguration.monitorsStorage },
                    asyncSet: { await store.send(.monitorsSystemMetricsToggleSwitched(.storage, $0)) }
                )) {
                    Text("enableStorageCapacityMonitoring", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.systemMetricsConfiguration.monitorsBattery },
                    asyncSet: { await store.send(.monitorsSystemMetricsToggleSwitched(.battery, $0)) }
                )) {
                    Text("enableBatteryStatusMonitoring", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.systemMetricsConfiguration.monitorsNetwork },
                    asyncSet: { await store.send(.monitorsSystemMetricsToggleSwitched(.network, $0)) }
                )) {
                    Text("enableNetworkConnectivityMonitoring", bundle: .module)
                }
            } header: {
                Text("systemMetrics", bundle: .module)
            }
            CustomMetricsSettingsSectionView(store: store.customMetricsSettings)
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
        .onDisappear {
            Task {
                await store.send(.onDisappear)
            }
        }
    }
}

extension MetricsSettings: ObservableObject {}
