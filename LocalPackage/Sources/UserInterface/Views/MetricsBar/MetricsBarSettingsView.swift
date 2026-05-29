/*
 MetricsBarSettingsView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/25.
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

struct MetricsBarSettingsView: View {
    @StateObject var store: MetricsBarSettings

    var body: some View {
        Form {
            Toggle(isOn: Binding<Bool>(
                get: { store.metricsBarConfiguration.showsCPU },
                asyncSet: { await store.send(.showsSystemInfoToggleSwitched(.cpu, $0)) }
            )) {
                Text("showCPUUsage", bundle: .module)
            }
            Toggle(isOn: Binding<Bool>(
                get: { store.metricsBarConfiguration.showsMemory },
                asyncSet: { await store.send(.showsSystemInfoToggleSwitched(.memory, $0)) }
            )) {
                Text("showMemoryPressure", bundle: .module)
            }
            Toggle(isOn: Binding<Bool>(
                get: { store.metricsBarConfiguration.showsStorage },
                asyncSet: { await store.send(.showsSystemInfoToggleSwitched(.storage, $0)) }
            )) {
                Text("showStorageCapacity", bundle: .module)
            }
            Toggle(isOn: Binding<Bool>(
                get: { store.metricsBarConfiguration.showsBattery },
                asyncSet: { await store.send(.showsSystemInfoToggleSwitched(.battery, $0)) }
            )) {
                Text("showBatteryStatus", bundle: .module)
            }
            Toggle(isOn: Binding<Bool>(
                get: { store.metricsBarConfiguration.showsNetwork },
                asyncSet: { await store.send(.showsSystemInfoToggleSwitched(.network, $0)) }
            )) {
                Text("showNetworkConnectivity", bundle: .module)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize()
        .task {
            await store.send(.task(String(describing: Self.self)))
        }
    }
}

extension MetricsBarSettings: ObservableObject {}

#Preview {
    MetricsBarSettingsView(store: .init(.testDependencies()))
}
