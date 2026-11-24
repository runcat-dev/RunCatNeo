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
                Picker(selection: Binding<MetricsBarUsageStyle?>(
                    get: { store.metricsBarConfiguration.showsCPU ? store.metricsBarConfiguration.cpuStyle : nil },
                    asyncSet: { await store.send(.cpuStylePickerSelected($0)) }
                )) {
                    Text("hidden", bundle: .module).tag(MetricsBarUsageStyle?.none)
                    Divider()
                    ForEach(MetricsBarUsageStyle.allCases) { style in
                        Text(style.label).tag(MetricsBarUsageStyle?.some(style))
                    }
                } label: {
                    Text("cpuUsage", bundle: .module)
                }
                Picker(selection: Binding<MetricsBarUsageStyle?>(
                    get: { store.metricsBarConfiguration.showsMemory ? store.metricsBarConfiguration.memoryStyle : nil },
                    asyncSet: { await store.send(.memoryStylePickerSelected($0)) }
                )) {
                    Text("hidden", bundle: .module).tag(MetricsBarUsageStyle?.none)
                    Divider()
                    ForEach(MetricsBarUsageStyle.allCases) { style in
                        Text(style.label).tag(MetricsBarUsageStyle?.some(style))
                    }
                } label: {
                    Text("memoryUsage", bundle: .module)
                }
                Picker(selection: Binding<MetricsBarStorageStyle?>(
                    get: { store.metricsBarConfiguration.showsStorage ? store.metricsBarConfiguration.storageStyle : nil },
                    asyncSet: { await store.send(.storageStylePickerSelected($0)) }
                )) {
                    Text("hidden", bundle: .module).tag(MetricsBarStorageStyle?.none)
                    Divider()
                    ForEach(MetricsBarStorageStyle.allCases) { style in
                        Text(style.label).tag(MetricsBarStorageStyle?.some(style))
                    }
                } label: {
                    Text("storageCapacity", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsBarConfiguration.showsBattery },
                    asyncSet: { await store.send(.showBatteryToggleSwitched($0)) }
                )) {
                    Text("showBatteryStatus", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsBarConfiguration.showsNetwork },
                    asyncSet: { await store.send(.showNetworkToggleSwitched($0)) }
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
                            asyncSet: { await store.send(.showCustomMetricsToggleSwitched(source.id, $0)) }
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
            await store.send(.viewAppeared(String(describing: Self.self)))
        }
        .onDisappear {
            Task {
                await store.send(.viewDisappeared)
            }
        }
    }
}

extension MetricsBarSettings: ObservableObject {}
