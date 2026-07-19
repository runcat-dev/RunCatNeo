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
                Picker(selection: Binding<MetricsBarValueStyle>(
                    get: { store.metricsBarConfiguration.resolvedValueStyle },
                    asyncSet: { await store.send(.valueStyleChanged($0)) }
                )) {
                    ForEach(MetricsBarValueStyle.allCases) { style in
                        let text = switch style {
                        case .percentage: Text("metricsBarValueStylePercentage", bundle: .module)
                        case .pie: Text("metricsBarValueStylePie", bundle: .module)
                        case .bar: Text("metricsBarValueStyleBar", bundle: .module)
                        }
                        text.tag(style)
                    }
                } label: {
                    Text("metricsBarValueStyle", bundle: .module)
                }
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
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsBarConfiguration.showsStorage },
                    asyncSet: { await store.send(.showsSystemMetricsToggleSwitched(.storage, $0)) }
                )) {
                    Text("showStorageCapacity", bundle: .module)
                }
                Toggle(isOn: Binding<Bool>(
                    get: { store.metricsBarConfiguration.showsBattery },
                    asyncSet: { await store.send(.showsSystemMetricsToggleSwitched(.battery, $0)) }
                )) {
                    Text("showBatteryStatus", bundle: .module)
                }
                if store.metricsBarConfiguration.showsBattery {
                    Picker(selection: Binding<MetricsBarBatteryStyle>(
                        get: { store.metricsBarConfiguration.resolvedBatteryStyle },
                        asyncSet: { await store.send(.batteryStyleChanged($0)) }
                    )) {
                        ForEach(MetricsBarBatteryStyle.allCases) { style in
                            let text = switch style {
                            case .compact: Text("metricsBarBatteryStyleCompact", bundle: .module)
                            case .percentage: Text("metricsBarBatteryStylePercentage", bundle: .module)
                            }
                            text.tag(style)
                        }
                    } label: {
                        Text("metricsBarBatteryStyle", bundle: .module)
                    }
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
