/*
 RunnerRotationSettingsSectionView.swift
 UserInterface

 Created by Jimmy on 2026/11/12.
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

struct RunnerRotationSettingsSectionView: View {
    @State var store: RunnerRotationSettings

    var body: some View {
        Section {
            Toggle(isOn: Binding<Bool>(
                get: { store.isEnabled },
                asyncSet: { await store.send(.rotationToggleSwitched($0)) }
            )) {
                Text("rotateRunnersAutomatically", bundle: .module)
            }
            Picker(selection: Binding<RunnerRotationOrder>(
                get: { store.order },
                asyncSet: { await store.send(.orderPickerSelected($0)) }
            )) {
                ForEach(RunnerRotationOrder.allCases) { order in
                    Text(order.localizedName)
                        .tag(order)
                }
            } label: {
                Text("rotationOrder", bundle: .module)
            }
            .disabled(!store.isEnabled)
            Picker(selection: Binding<RunnerRotationInterval>(
                get: { store.interval },
                asyncSet: { await store.send(.intervalPickerSelected($0)) }
            )) {
                ForEach(RunnerRotationInterval.allCases) { interval in
                    Text(interval.duration, format: .units(allowed: [.hours, .minutes], width: .wide))
                        .tag(interval)
                }
            } label: {
                Text("rotationInterval", bundle: .module)
            }
            .disabled(!store.isEnabled)
            ForEach(store.runnerBundleList) { runnerBundle in
                Toggle(isOn: Binding<Bool>(
                    get: { store.runnerIDs.contains(runnerBundle.runner.id) },
                    asyncSet: { await store.send(.runnerToggleSwitched(runnerBundle.runner, $0)) }
                )) {
                    Label {
                        Text(runnerBundle.runner.formatted)
                    } icon: {
                        runnerBundle.thumbnail
                    }
                }
            }
            .disabled(!store.isEnabled)
        } header: {
            Text("runnerRotation", bundle: .module)
        } footer: {
            if store.needsMoreRunners {
                Text("selectAtLeastTwoRunners", bundle: .module)
            }
        }
        .task {
            await store.send(.viewAppeared)
        }
        .onDisappear {
            Task {
                await store.send(.viewDisappeared)
            }
        }
    }
}
