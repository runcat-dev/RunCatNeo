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
                    get: { store.activationBundle.isActiveMemory },
                    asyncSet: { await store.send(.isActiveToggleSwitched(.memory, $0)) }
                )) {
                    Text("memoryPerformance", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.activationBundle.isActiveStorage },
                    asyncSet: { await store.send(.isActiveToggleSwitched(.storage, $0)) }
                )) {
                    Text("storageCapacity", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.activationBundle.isActiveBattery },
                    asyncSet: { await store.send(.isActiveToggleSwitched(.battery, $0)) }
                )) {
                    Text("batteryState", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.activationBundle.isActiveNetwork },
                    asyncSet: { await store.send(.isActiveToggleSwitched(.network, $0)) }
                )) {
                    Text("networkConnection", bundle: .module)
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
