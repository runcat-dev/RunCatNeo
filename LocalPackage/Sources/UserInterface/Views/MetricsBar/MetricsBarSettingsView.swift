/*
 MetricsBarSettingsView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/25.
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
import SwiftUI

struct MetricsBarSettingsView: View {
    @StateObject var store: MetricsBarSettings

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsBarConfiguration.showsCPU },
                    asyncSet: { await store.send(.showsSystemMetricsToggleSwitched(.cpu, $0)) }
                )) {
                    Text("showCPUUsage", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsBarConfiguration.showsMemory },
                    asyncSet: { await store.send(.showsSystemMetricsToggleSwitched(.memory, $0)) }
                )) {
                    Text("showMemoryPressure", bundle: .module)
                }
                HStack {
                    Text("showStorageCapacity", bundle: .module)
                    Spacer()
                    Picker(selection: Binding<StorageDisplayFormat>(
                        get: { store.metricsBarConfiguration.storageDisplayFormat },
                        asyncSet: { await store.send(.storageDisplayFormatChanged($0)) }
                    )) {
                        ForEach(StorageDisplayFormat.allCases) { format in
                            switch format {
                            case .percentage:
                                Text(verbatim: "%").tag(format)
                            case .used:
                                Text("storageDisplayFormatUsed", bundle: .module).tag(format)
                            case .available:
                                Text("storageDisplayFormatAvailable", bundle: .module).tag(format)
                            }
                        }
                    } label: {
                        EmptyView()
                    }
                    .labelsHidden()
                    .fixedSize()
                    Toggle(isOn: Binding<Bool>(
                        get: { store.metricsBarConfiguration.showsStorage },
                        asyncSet: { await store.send(.showsSystemMetricsToggleSwitched(.storage, $0)) }
                    )) {
                        EmptyView()
                    }
                    .labelsHidden()
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsBarConfiguration.showsBattery },
                    asyncSet: { await store.send(.showsSystemMetricsToggleSwitched(.battery, $0)) }
                )) {
                    Text("showBatteryStatus", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsBarConfiguration.showsNetwork },
                    asyncSet: { await store.send(.showsSystemMetricsToggleSwitched(.network, $0)) }
                )) {
                    Text("showNetworkConnectivity", bundle: .module)
                }
            } header: {
                Text("metricsBarSettings", bundle: .module)
            }
            if !store.customMetricsSources.isEmpty {
                Section {
                    ForEach(store.customMetricsSources) { source in
                        Toggle(isOn: Binding<Bool>(
                            get: { store.metricsBarConfiguration.showsCustomMetrics(of: source.id) },
                            asyncSet: { await store.send(.showsCustomMetricsToggleSwitched(source.id, $0)) }
                        )) {
                            Text("show\(source.displayName)Metrics", bundle: .module)
                        }
                    }
                } header: {
                    Text("customMetrics", bundle: .module)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize()
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

extension MetricsBarSettings: ObservableObject {}
