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
import Model
import SwiftUI

struct MetricsSettingsView: View {
    @StateObject var store: MetricsSettings

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding<Bool>(
                    get: { store.showsMetricsBar },
                    asyncSet: { await store.send(.showsMetricsBarToggleSwitched($0)) }
                )) {
                    Text("showMetricsBar", bundle: .module)
                }
            } header: {
                Text("metricsBar", bundle: .module)
            }
            Section {
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsConfiguration.monitorsMemory },
                    asyncSet: { await store.send(.monitorsSystemInfoToggleSwitched(.memory, $0)) }
                )) {
                    Text("enableMemoryPressureMonitoring", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsConfiguration.monitorsStorage },
                    asyncSet: { await store.send(.monitorsSystemInfoToggleSwitched(.storage, $0)) }
                )) {
                    Text("enableStorageCapacityMonitoring", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsConfiguration.monitorsBattery },
                    asyncSet: { await store.send(.monitorsSystemInfoToggleSwitched(.battery, $0)) }
                )) {
                    Text("enableBatteryStatusMonitoring", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsConfiguration.monitorsNetwork },
                    asyncSet: { await store.send(.monitorsSystemInfoToggleSwitched(.network, $0)) }
                )) {
                    Text("enableNetworkConnectivityMonitoring", bundle: .module)
                }
            } header: {
                Text("systemInfo", bundle: .module)
            }
        }
        .formStyle(.grouped)
        .fixedSize()
        .task {
            await store.send(.task(String(describing: Self.self)))
        }
    }
}

extension MetricsSettings: ObservableObject {}

#Preview {
    MetricsSettingsView(store: .init(.testDependencies()))
}
