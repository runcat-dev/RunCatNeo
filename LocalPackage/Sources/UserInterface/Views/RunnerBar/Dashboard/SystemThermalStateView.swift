/*
 SystemThermalStateView.swift
 UserInterface

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
import SwiftUI

struct SystemThermalStateView: View {
    var thermalState: SystemThermalState

    var body: some View {
        Text(label, bundle: .module)
            .font(.caption)
            .help(Text("systemThermalStateHelp", bundle: .module))
    }

    private var label: LocalizedStringKey {
        switch thermalState {
        case .nominal: "systemThermalStateNominal"
        case .fair: "systemThermalStateFair"
        case .serious: "systemThermalStateSerious"
        case .critical: "systemThermalStateCritical"
        case .unknown: "systemThermalStateUnknown"
        }
    }
}
