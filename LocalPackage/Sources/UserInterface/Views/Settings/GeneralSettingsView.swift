/*
 GeneralSettingsView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/23.
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

struct GeneralSettingsView: View {
    @StateObject var store: GeneralSettings

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding<Bool>(
                    get: { store.launchesAtLogin },
                    asyncSet: { await store.send(.launchAtLoginToggleSwitched($0)) }
                )) {
                    Text("launchAtLogin", bundle: .module)
                }
            } header: {
                Text("launch", bundle: .module)
            }
            Section {
                Picker(selection: Binding<UpdateInterval>(
                    get: { store.updateInterval },
                    asyncSet: { await store.send(.updateIntervalChanged($0)) }
                )) {
                    ForEach(UpdateInterval.allCases) { interval in
                        Text("\(interval.seconds)seconds", bundle: .module)
                            .tag(interval)
                    }
                } label: {
                    Text("updateInterval", bundle: .module)
                }
            } header: {
                Text("monitoring", bundle: .module)
            }
        }
        .formStyle(.grouped)
        .task {
            await store.send(.task(String(describing: Self.self)))
        }
    }
}

extension GeneralSettings: ObservableObject {}
