/*
 SystemInfoStackView.swift
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

import DataSource
import Model
import SwiftUI
import SystemInfoKit

struct SystemInfoStackView: View {
    var systemInfoBundle: SystemInfoBundle
    var cpuRingBuffer: RingBuffer
    var memoryRingBuffer: RingBuffer
    var isPreview: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cpuInfo = systemInfoBundle.cpuInfo {
                SystemInfoView(systemInfo: cpuInfo) {
                    LineGraphView(values: (isPreview ? RingBuffer.mock : cpuRingBuffer).values)
                }
            }
            if let memoryInfo = systemInfoBundle.memoryInfo {
                Divider()
                SystemInfoView(systemInfo: memoryInfo) {
                    LineGraphView(values: (isPreview ? RingBuffer.mock : memoryRingBuffer).values)
                }
            }
            if let storageInfo = systemInfoBundle.storageInfo {
                Divider()
                SystemInfoView(systemInfo: storageInfo) {
                    BarGraphView(value: storageInfo.percentage.value)
                }
            }
            if let batteryInfo = systemInfoBundle.batteryInfo {
                Divider()
                SystemInfoView(systemInfo: batteryInfo, isVisibleDetails: batteryInfo.isInstalled) {
                    EmptyView()
                }
            }
            if let networkInfo = systemInfoBundle.networkInfo?.masked(isPreview) {
                Divider()
                SystemInfoView(systemInfo: networkInfo) {
                    EmptyView()
                }
            }
        }
        .padding(8)
        .materialCellStyle()
    }
}
