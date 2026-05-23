/*
 SettingsView.swift
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

struct SettingsView: View {
    @Environment(\.appDependencies) private var appDependencies
    @State private var settingsTab = SettingsTab.general

    var body: some View {
        TabView(selection: $settingsTab) {
            GeneralSettingsView(store: .init(appDependencies))
                .tabItem {
                    Label {
                        Text("generalTab", bundle: .module)
                    } icon: {
                        Image(systemName: "gear")
                    }
                }
                .tag(SettingsTab.general)
            MetricsSettingsView(store: .init(appDependencies))
                .tabItem {
                    Label {
                        Text("metricsTab", bundle: .module)
                    } icon: {
                        Image(systemName: "chart.xyaxis.line")
                    }
                }
                .tag(SettingsTab.metrics)
        }
        .accessibilityIdentifier("settings")
    }
}

#Preview {
    SettingsView()
        .environment(\.appDependencies, .testDependencies())
}
