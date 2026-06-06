/*
 DashboardView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/08.
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

struct DashboardView: View {
    @Environment(\.appDependencies) private var appDependencies
    @StateObject var store: Dashboard

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(store.appName)
                    .padding(.leading, 8)
                Spacer()
                MenuView(appName: store.appName) { action in
                    await store.send(action)
                }
            }
            SystemInfoStackView(
                systemInfoBundle: store.systemInfoBundle,
                cpuRingBuffer: store.cpuRingBuffer,
                memoryRingBuffer: store.memoryRingBuffer,
                isPreview: store.isPreview
            )
            ForEach(store.customMetricsBundles) { customMetricsBundle in
                CustomMetricsCardView(customMetricsBundle: customMetricsBundle)
            }
        }
        .fixedSize()
        .padding(8)
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

extension Dashboard: ObservableObject {}
